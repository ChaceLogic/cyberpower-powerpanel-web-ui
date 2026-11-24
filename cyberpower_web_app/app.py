
from flask import Flask, render_template, jsonify, request

from ups import (
    run_pwrstat,
    get_status,
    get_config,
    get_alarm_state,
    set_alarm,
    mute_alarm,
    run_self_test
)

app = Flask(__name__)


# --------------------------------------------------
# Dashboard
# --------------------------------------------------

@app.route("/")
def index():
    return render_template("index.html")


# --------------------------------------------------
# UPS Status
# --------------------------------------------------

@app.route("/api/ups/status")
def ups_status():
    result = get_status()

    if not result["success"]:
        return jsonify(result), 500

    return jsonify(result)


# --------------------------------------------------
# UPS Configuration
# --------------------------------------------------

@app.route("/api/ups/config")
def ups_config():
    result = get_config()

    if not result["success"]:
        return jsonify(result), 500

    # Parse alarm state from the configuration output.
    alarm_on, error = get_alarm_state(result.get("output", ""))

    result["alarm_on"] = alarm_on

    if error:
        result["error"] = error

    return jsonify(result)


# --------------------------------------------------
# UPS Alarm Control
# --------------------------------------------------

@app.route("/api/ups/alarm", methods=["POST"])
def ups_alarm():
    data = request.get_json(silent=True) or {}
    enabled = data.get("enabled")

    if not isinstance(enabled, bool):
        return jsonify({
            "success": False,
            "error": "A boolean enabled value is required."
        }), 400

    result = set_alarm(enabled)

    if not result["success"]:
        return jsonify(result), 500

    return jsonify(result)


# --------------------------------------------------
# Mute UPS Alarm
# --------------------------------------------------

@app.route("/api/ups/mute", methods=["POST"])
def ups_mute():
    result = mute_alarm()

    if not result["success"]:
        return jsonify(result), 500

    return jsonify(result)


# --------------------------------------------------
# UPS Self-Test
# --------------------------------------------------

@app.route("/api/ups/test", methods=["POST"])
def ups_test():
    result = run_self_test()

    if not result["success"]:
        return jsonify(result), 500

    return jsonify(result)


# --------------------------------------------------
# Start Flask
# --------------------------------------------------

if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False
    )
