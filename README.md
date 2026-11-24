# CyberPower UPS Monitoring & Email Notifications

Installation and configuration instructions for setting up CyberPower UPS monitoring on Ubuntu/Debian Linux using the PowerPanel Linux (PPL) software and a custom web application.

## Table of Contents

- [1. System Updates](#1-system-updates)
- [2. Install CyberPower PowerPanel](#2-install-cyberpower-powerpanel)
- [3. Configure PWRSTAT Permissions](#3-configure-pwrstat-permissions)
- [4. Configure Email Notifications](#4-configure-email-notifications)
- [5. Install Python](#5-install-python)
- [6. Install CyberPower Web Application](#6-install-cyberpower-web-application)
- [7. Configure Automated Email Notifications](#7-configure-automated-email-notifications)
- [8. Auto Power Off](#8-auto-power-off)

## 1. System Updates

Update and upgrade the system packages.

```bash
sudo apt update
sudo apt upgrade -y
```

## 2. Install CyberPower PowerPanel

Install the CyberPower PowerPanel Linux (PPL) package.

Download `PPL_64bit_v1.4.2.deb` and place it in your working directory.

```bash
sudo dpkg -i PPL_64bit_v1.4.2.deb
```

Enable and start the PowerPanel service.

```bash
sudo systemctl enable pwrstatd
sudo systemctl start pwrstatd
```

Verify that the UPS is detected.

```bash
sudo pwrstat -status
```

## 3. Configure PWRSTAT Permissions

Allow the current user to execute the `pwrstat` command without entering a sudo password.

```bash
echo "$USER ALL=(ALL) NOPASSWD: $(sudo which pwrstat)" | sudo tee /etc/sudoers.d/pwrstat
```

Set the correct permissions on the sudoers file.

```bash
sudo chmod 440 /etc/sudoers.d/pwrstat
```

Verify the configuration.

```bash
sudo pwrstat -status
```

**Note:** The application should invoke `pwrstat` through sudo for this permission configuration to apply.

## 4. Configure Email Notifications

Install the required email packages.

```bash
sudo apt install mailutils msmtp msmtp-mta ca-certificates -y
```

If prompted by AppArmor during installation, select **Yes**.

### 4.1 Configure MSMTP

Create the MSMTP configuration file for the root user.

```bash
sudo nano /root/.msmtprc
```

Add the following configuration:

```ini
defaults
auth on
tls on
tls_starttls off
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /root/.msmtp.log

account default
host smtp.gmail.com
port 465
user sender_email@gmail.com
from sender_email@gmail.com
password gmail_app_password
```

Replace the following values:

| Setting | Description |
|---|---|
| `sender_email@gmail.com` | Your Gmail address |
| `gmail_app_password` | Your Google App Password |

**Important:** Use a Google App Password rather than your normal Gmail password. App Passwords require two-step verification to be enabled on your Google account.

Set secure permissions on the configuration file.

```bash
sudo chmod 600 /root/.msmtprc
```

### 4.2 Test Email Configuration

Run the email test as root.

```bash
sudo -i
echo "This is a test email" | mail -r sender_email@gmail.com -s "Test" to_email@example.com
exit
```

Replace `sender_email@gmail.com` and `to_email@example.com` with your sender and recipient email addresses.

Check your inbox to verify that the email was delivered.

## 5. Install Python

Install Python 3 and the virtual environment package.

```bash
sudo apt install python3 python3-venv -y
```

## 6. Install CyberPower Web Application

Copy the `cyberpower_web_app` directory into the user's home directory.

Expected directory structure:

```text
/home/username/
└── cyberpower_web_app/
    └── install.sh
```

Make the installation script executable.

```bash
chmod +x ~/cyberpower_web_app/install.sh
```

Run the installation script.

```bash
sudo ~/cyberpower_web_app/install.sh
```

Follow any prompts provided by the installer.

## 7. Configure Automated Email Notifications

CyberPower PowerPanel provides scripts that execute during UPS power events.

The following scripts can be modified to integrate automated email notifications with the custom web application.

### Power Failure Notification

Edit the power failure script:

```bash
sudo nano /etc/pwrstatd-powerfail.sh
```

### Low Battery Notification

Edit the low battery script:

```bash
sudo nano /etc/pwrstatd-lowbatt.sh
```

Add the appropriate commands to trigger email notifications through your configured email system.

**Note:** Be careful when modifying the original PowerPanel scripts. Preserve the existing functionality and ensure the scripts have executable permissions.

---

## 8. Auto Power Off
Run the commands to turn off the auto power off
```bash
sudo pwrstat -pwrfail -shutdown off
sudo pwrstat -lowbatt -shutdown off
```

## Troubleshooting

### Check PowerPanel Service

```bash
sudo systemctl status pwrstatd
```

### Check UPS Status

```bash
sudo pwrstat -status
```

### Check MSMTP Logs

```bash
sudo cat /root/.msmtp.log
```

### Check Email Delivery

Send another test email:

```bash
sudo -i
echo "Email test" | mail -r sender_email@gmail.com -s "UPS Email Test" to_email@example.com
exit
```

## Requirements

- Ubuntu/Debian Linux
- CyberPower UPS
- CyberPower PowerPanel Linux (PPL) v1.4.2
- Python 3
- Gmail account with two-step verification and an App Password
- `cyberpower_web_app` installation files


