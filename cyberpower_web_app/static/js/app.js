let alarmEnabled = null;

async function apiRequest(url, method = 'GET', body = null) {
    const options = { method: method };

    if (body !== null) {
        options.headers = {'Content-Type': 'application/json'};
        options.body = JSON.stringify(body);
    }

    const response = await fetch(url, options);
    const result = await response.json();

    if (!response.ok) {
        throw new Error(result.error || 'Request failed');
    }

    return result;
}


async function loadData(type) {
    const output = document.getElementById(type);

    try {
        const result = await apiRequest('/api/ups/' + type);

        if (result.success) {
            output.textContent = result.output || 'No output returned.';
        } else {
            output.textContent = 'ERROR: ' + result.error;
        }

        if (type === 'config' && result.success) {
            updateAlarmState(result.alarm_on);
        }

    } catch (error) {
        output.textContent = 'Request failed: ' + error.message;
    }
}


function updateAlarmState(enabled) {
    alarmEnabled = enabled;

    const state = document.getElementById('alarmState');
    const button = document.getElementById('alarmToggle');

    if (enabled === null || enabled === undefined) {
        state.textContent = 'Unknown';
        state.className = 'alarm-state';
        button.textContent = 'Unavailable';
        button.disabled = true;
        return;
    }

    state.textContent = enabled ? 'ON' : 'OFF';
    state.className = 'alarm-state ' +
        (enabled ? 'on-text' : 'off-text');

    button.textContent = enabled ? 'Turn Alarm OFF' : 'Turn Alarm ON';
    button.className = enabled ? 'off' : '';
    button.disabled = false;
}


async function toggleAlarm() {
    if (alarmEnabled === null) return;

    const desiredState = !alarmEnabled;
    const button = document.getElementById('alarmToggle');
    const output = document.getElementById('alarmOutput');

    if (!confirm(
        'Are you sure you want to turn the UPS alarm ' +
        (desiredState ? 'ON' : 'OFF') + '?'
    )) return;

    button.disabled = true;
    output.textContent = 'Executing command...';

    try {
        const result = await apiRequest(
            '/api/ups/alarm',
            'POST',
            {enabled: desiredState}
        );

        output.textContent = result.message || 'Command completed.';

        if (result.success) {
            updateAlarmState(result.alarm_on);
            loadData('config');
        } else {
            output.textContent = 'ERROR: ' + result.error;
            loadData('config');
        }

    } catch (error) {
        output.textContent = 'ERROR: ' + error.message;
        loadData('config');
    } finally {
        button.disabled = false;
    }
}


async function muteAlarm() {
    if (!confirm('Temporarily mute the UPS alarm?')) return;

    const button = document.getElementById('muteButton');
    const output = document.getElementById('muteOutput');

    button.disabled = true;
    output.textContent = 'Executing command...';

    try {
        const result = await apiRequest('/api/ups/mute', 'POST');

        output.textContent = result.success
            ? (result.output || 'Mute command executed successfully.')
            : 'ERROR: ' + result.error;

    } catch (error) {
        output.textContent = 'ERROR: ' + error.message;
    } finally {
        button.disabled = false;
    }
}


async function selfTest() {
    if (!confirm(
        'Start UPS self-test?\\n\\n' +
        'The UPS will briefly operate on battery power. ' +
        'Make sure connected equipment is protected and ' +
        'the battery is sufficiently charged.'
    )) return;

    const button = document.getElementById('testButton');
    const output = document.getElementById('testOutput');

    button.disabled = true;
    output.textContent = 'Starting UPS self-test...';

    try {
        const result = await apiRequest('/api/ups/test', 'POST');

        output.textContent = result.success
            ? (result.output || 'Self-test command completed.')
            : 'ERROR: ' + result.error;

        if (result.success) {
            output.textContent +=
                '\\nCheck UPS Status for test results.';
        }

    } catch (error) {
        output.textContent = 'ERROR: ' + error.message;
    } finally {
        button.disabled = false;
        loadData('status');
    }
}


// Initial dashboard load
loadData('status');
loadData('config');

// Refresh monitoring information every 15 seconds
setInterval(() => {
    loadData('status');
    loadData('config');
}, 15000);
