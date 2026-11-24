#!/usr/bin/env bash
set -Eeuo pipefail

# CyberPower UPS Dashboard installer for Debian/Ubuntu.
# Run as the normal account that should own/run the application:
#   chmod +x install.sh
#   ./install.sh

APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SERVICE_NAME="ups-dashboard"
SUDOERS_FILE="/etc/sudoers.d/pwrstat"
PWRSTAT="/usr/sbin/pwrstat"
PORT="${UPS_DASHBOARD_PORT:-5000}"
BIND="${UPS_DASHBOARD_BIND:-0.0.0.0}"

log() { printf '\n[UPS Dashboard] %s\n' "$*"; }
fail() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

# Resolve the account that should run the app. Do not accidentally install
# the application as root when the script is invoked with sudo.
if [[ "${EUID}" -eq 0 ]]; then
    [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] || \
        fail "Run this script as your normal application user, without sudo: ./install.sh"
    APP_USER="${SUDO_USER}"
else
    APP_USER="$(id -un)"
fi

APP_GROUP="$(id -gn "$APP_USER")"
APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"
[[ -n "$APP_HOME" && -d "$APP_HOME" ]] || fail "Could not determine home directory for ${APP_USER}."
[[ -f "$APP_DIR/app.py" ]] || fail "app.py not found in ${APP_DIR}."
[[ -f "$APP_DIR/ups.py" ]] || fail "ups.py not found in ${APP_DIR}."
[[ -d "$APP_DIR/templates" ]] || fail "templates/ directory not found."
[[ -d "$APP_DIR/static" ]] || fail "static/ directory not found."
[[ "$APP_DIR" != *" "* ]] || fail "Application path contains spaces; move the project to a path without spaces."

command -v sudo >/dev/null 2>&1 || fail "sudo is required. Install it first."
command -v systemctl >/dev/null 2>&1 || fail "systemd/systemctl is required."
command -v python3 >/dev/null 2>&1 || fail "python3 is required."
command -v visudo >/dev/null 2>&1 || fail "visudo is required (install the sudo package)."
[[ -x "$PWRSTAT" ]] || fail "$PWRSTAT not found. Install CyberPower PowerPanel and confirm pwrstat works on the host."

log "Installing for user: ${APP_USER}"
log "Application directory: ${APP_DIR}"
log "Dashboard bind: ${BIND}:${PORT}"

# Obtain sudo credentials before doing any work requiring root.
sudo -v

# Ensure the Python venv module is available. Debian may package it separately.
if ! python3 -m venv --help >/dev/null 2>&1; then
    log "Installing python3-venv..."
    sudo apt-get update
    sudo apt-get install -y python3-venv
fi

# Create/update the virtual environment and install only the app dependencies.
log "Creating/updating Python virtual environment..."
python3 -m venv "${APP_DIR}/venv"

log "Installing Python dependencies..."
"${APP_DIR}/venv/bin/python" -m pip install --upgrade pip
"${APP_DIR}/venv/bin/python" -m pip install -r "${APP_DIR}/requirements.txt"

# Ensure the service account owns its application and virtualenv files.
sudo chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}"

# Install a narrowly scoped sudoers rule. Validate it before installing.
log "Configuring restricted pwrstat sudo permissions..."
TMP_SUDOERS="$(mktemp)"
trap 'rm -f "$TMP_SUDOERS"' EXIT

cat > "$TMP_SUDOERS" <<EOF
Cmnd_Alias PWRSTAT_CMDS = \\
    ${PWRSTAT} -status, \\
    ${PWRSTAT} -config, \\
    ${PWRSTAT} -alarm on, \\
    ${PWRSTAT} -alarm off, \\
    ${PWRSTAT} -mute, \\
    ${PWRSTAT} -test

${APP_USER} ALL=(root) NOPASSWD: PWRSTAT_CMDS
EOF

sudo visudo -cf "$TMP_SUDOERS" >/dev/null || fail "Generated sudoers configuration failed validation."
sudo install -o root -g root -m 0440 "$TMP_SUDOERS" "$SUDOERS_FILE"
sudo visudo -c >/dev/null || fail "System sudoers validation failed."

# Verify the service user can run the approved status command without a password.
sudo -u "$APP_USER" sudo -n "$PWRSTAT" -status >/dev/null || \
    fail "The ${APP_USER} account could not execute pwrstat -status through sudo."

# Include the CyberPower daemon dependency only if the unit exists.
PWRSTAT_DEPENDENCY=""
if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx 'pwrstatd.service'; then
    PWRSTAT_DEPENDENCY="After=network.target pwrstatd.service
Wants=pwrstatd.service"
else
    PWRSTAT_DEPENDENCY="After=network.target"
    log "Note: pwrstatd.service was not found; dashboard will start after network.target."
fi

# Write the systemd unit. Gunicorn is used instead of Flask's development server.
log "Creating systemd service..."
TMP_UNIT="$(mktemp)"
cat > "$TMP_UNIT" <<EOF
[Unit]
Description=CyberPower UPS Dashboard
${PWRSTAT_DEPENDENCY}

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_DIR}
Environment=PYTHONUNBUFFERED=1
ExecStart=${APP_DIR}/venv/bin/gunicorn --workers 2 --threads 4 --bind ${BIND}:${PORT} --timeout 90 --access-logfile - --error-logfile - app:app
Restart=on-failure
RestartSec=5
UMask=0077

[Install]
WantedBy=multi-user.target
EOF

sudo install -o root -g root -m 0644 "$TMP_UNIT" "/etc/systemd/system/${SERVICE_NAME}.service"
rm -f "$TMP_UNIT"

# Check that the Flask application imports before starting the service.
log "Checking application imports..."
(
    cd "$APP_DIR"
    "${APP_DIR}/venv/bin/python" -c "import app; assert hasattr(app, 'app')"
) || fail "Could not import app:app. Check app.py and its dependencies."

log "Enabling and starting dashboard..."
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}.service"
sudo systemctl restart "${SERVICE_NAME}.service"

sleep 2
if ! sudo systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    sudo systemctl --no-pager --full status "${SERVICE_NAME}.service" || true
    sudo journalctl -u "${SERVICE_NAME}.service" -n 60 --no-pager || true
    fail "Dashboard service did not start. Review the logs above."
fi

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
log "Installation complete."
printf '\nService:  sudo systemctl status %s\n' "$SERVICE_NAME"
printf 'Logs:     sudo journalctl -u %s -f\n' "$SERVICE_NAME"
printf 'Restart:  sudo systemctl restart %s\n' "$SERVICE_NAME"
printf 'URL:      http://%s:%s\n' "${HOST_IP:-SERVER-IP}" "$PORT"
printf '\nThe service runs as %s (not root). The dashboard should now start at boot.\n' "$APP_USER"
