import subprocess
import re

PWRSTAT = "/usr/sbin/pwrstat"
SUDO = "/usr/bin/sudo"


def run_pwrstat(arguments):
    """
    Execute an approved pwrstat command through sudo.
    Returns a dictionary containing success, output, and/or error.
    """

    try:
        result = subprocess.run(
            [SUDO, "-n", PWRSTAT] + arguments,
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.returncode != 0:
            return {
                "success": False,
                "output": result.stdout.strip(),
                "error": result.stderr.strip() or result.stdout.strip()
            }

        return {
            "success": True,
            "output": result.stdout.strip()
        }

    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "error": "UPS command timed out."
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


def get_status():
    """Get current UPS status."""
    return run_pwrstat(["-status"])


def get_config():
    """Get UPS configuration."""
    return run_pwrstat(["-config"])


def get_alarm_state(config_output=None):
    """
    Determine whether the UPS alarm is enabled.

    Returns:
        (True, None)  - Alarm is on.
        (False, None) - Alarm is off.
        (None, error) - Alarm state could not be determined.

    If config_output is supplied, parse it without running pwrstat again.
    """

    if config_output is None:
        result = get_config()

        if not result["success"]:
            return None, result.get("error", "Unable to read UPS configuration.")

        config_output = result.get("output", "")

    match = re.search(
        r"^\s*Alarm\s*\.{2,}\s*(On|Off)\s*$",
        config_output,
        re.IGNORECASE | re.MULTILINE
    )

    if not match:
        return None, "Could not determine UPS alarm state from configuration."

    return match.group(1).lower() == "on", None


def set_alarm(enabled):
    """Turn the UPS alarm on or off and verify the result."""

    if not isinstance(enabled, bool):
        return {
            "success": False,
            "error": "A boolean enabled value is required."
        }

    command = ["-alarm", "on" if enabled else "off"]
    result = run_pwrstat(command)

    if not result["success"]:
        return result

    alarm_on, error = get_alarm_state()

    if error or alarm_on != enabled:
        return {
            "success": False,
            "error": error or "Alarm setting could not be verified.",
            "alarm_on": alarm_on
        }

    return {
        "success": True,
        "alarm_on": alarm_on,
        "message": "UPS alarm turned " + ("ON" if alarm_on else "OFF") + ".",
        "output": result.get("output", "")
    }


def mute_alarm():
    """Mute the UPS audible alarm."""
    return run_pwrstat(["-mute"])


def run_self_test():
    """Run the UPS self-test."""
    return run_pwrstat(["-test"])
