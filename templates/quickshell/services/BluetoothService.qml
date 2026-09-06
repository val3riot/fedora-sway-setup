import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
Scope {
    id: root
    property var backend: Bluetooth
    readonly property var adapters: backend.adapters.values
    property string selectedAdapter: ""
    readonly property var adapter: adapters.find(a => a.dbusPath === selectedAdapter) || backend.defaultAdapter || null
    readonly property bool available: adapters.length > 0 && adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool blocked: available && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool transitioning: available && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)
    readonly property string state: !available ? "Non disponibile" : blocked ? "Blocked" : transitioning ? BluetoothAdapterState.toString(adapter.state) : enabled ? "ON" : "OFF"
    readonly property var devices: available ? adapter.devices.values : []
    readonly property var connected: devices.filter(d => d.connected)
    readonly property var paired: devices.filter(d => !d.connected && (d.paired || d.bonded))
    readonly property var discovered: devices.filter(d => !d.connected && !d.paired && !d.bonded)
    property string message: ""
    signal managementRequested()
    property string failedPath: ""
    property var pendingDevice: null
    property string operation: ""
    property string forgetPath: ""
    property string scanPath: ""
    property var scanOwner: null
    property bool powerPending: false
    property bool expectedPower: false
    readonly property bool discovering: available && adapter.discovering
    function writable() { return backend !== Bluetooth || Quickshell.env("WORKSTATION_QUICKSHELL_TEST") !== "1"; }
    function contains(device) { return device && devices.indexOf(device) >= 0; }
    function resolvedName(device) {
        if (!device) return "";
        // BlueZ Alias may be an address even when Name is already available.
        for (const value of [device.name, device.deviceName]) {
            const name = (value || "").trim();
            if (name && !/^(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(name)) return name;
        }
        return "";
    }
    function displayName(device) { return resolvedName(device) || "Nome non disponibile"; }
    function batteryText(device) { return device && device.batteryAvailable ? Math.round(device.battery * 100) + "%" : ""; }
    function deviceState(device) {
        if (!device) return "Non disponibile";
        if (device.blocked) return "Blocked";
        if (device.dbusPath === failedPath) return "Failed";
        if (device.pairing) return "Pairing…";
        return BluetoothDeviceState.toString(device.state);
    }
    function toggle() {
        if (!available || blocked || transitioning || powerPending || !writable()) return;
        stopScan(scanOwner);
        expectedPower = !adapter.enabled; powerPending = true; message = "";
        adapter.enabled = expectedPower; powerTimeout.restart();
    }
    Timer {
        id: powerTimeout; interval: 6000
        onTriggered: {
            if (!root.adapter || root.adapter.enabled !== root.expectedPower)
                root.message = root.blocked ? "Blocked · verificare rfkill" : "Cambio stato Bluetooth non riuscito.";
            root.powerPending = false;
        }
    }
    Connections {
        target: root.adapter
        function onEnabledChanged() {
            if (root.powerPending && root.adapter.enabled === root.expectedPower) {
                root.powerPending = false; powerTimeout.stop();
            }
        }
    }
    function startScan(owner) {
        if (!enabled || discovering || !writable()) return;
        scanOwner = owner; scanPath = adapter.dbusPath; message = "";
        adapter.discovering = true;
        scanTimeout.restart(); scanStartTimeout.restart();
    }
    function stopScan(owner) {
        if (owner !== scanOwner || !scanPath) return;
        const a = adapters.find(a => a.dbusPath === scanPath);
        if (a && writable()) a.discovering = false;
        scanPath = ""; scanOwner = null; scanTimeout.stop(); scanStartTimeout.stop();
    }
    Timer { id: scanTimeout; interval: 30000; onTriggered: root.stopScan(root.scanOwner) }
    Timer {
        id: scanStartTimeout; interval: 4000
        onTriggered: {
            const a = root.adapters.find(a => a.dbusPath === root.scanPath);
            if (!a || !a.discovering) { root.message = "Ricerca Bluetooth non riuscita."; root.stopScan(root.scanOwner); }
        }
    }
    onAdaptersChanged: {
        if (scanPath && !adapters.some(a => a.dbusPath === scanPath)) {
            // A USB reset/removal invalidates ownership; never retry a vanished adapter.
            scanPath = ""; scanOwner = null; scanTimeout.stop(); scanStartTimeout.stop();
            message = "Adapter disconnesso durante la ricerca.";
        }
    }
    onSelectedAdapterChanged: { stopScan(scanOwner); forgetPath = ""; }
    onDevicesChanged: {
        if (pendingDevice && !contains(pendingDevice)) complete(operation === "forget" ? "Dispositivo dimenticato." : "Dispositivo non più disponibile.");
        if (forgetPath && !devices.some(d => d.dbusPath === forgetPath)) forgetPath = "";
    }
    function classify(device) {
        const icon = device ? device.icon : "";
        if (/headset|headphones|audio/.test(icon)) return "Audio";
        if (/mouse/.test(icon)) return "Mouse";
        if (/keyboard/.test(icon)) return "Tastiera";
        if (/gaming|gamepad|joystick/.test(icon)) return "Controller";
        if (/phone/.test(icon)) return "Telefono";
        return "Bluetooth";
    }
    function complete(text) { message = text; pendingDevice = null; operation = ""; operationTimeout.stop(); }
    function checkOperation() {
        const d = pendingDevice;
        if (!d) return;
        if (!contains(d)) { complete("Dispositivo non più disponibile."); return; }
        if (operation === "connect" && d.connected) complete("");
        else if (operation === "disconnect" && d.state === BluetoothDeviceState.Disconnected) complete("");
        else if (operation === "forget" && !d.paired && !d.bonded) complete("Dispositivo dimenticato.");
    }
    Connections {
        target: root.pendingDevice
        function onStateChanged() { root.checkOperation(); }
        function onPairedChanged() { root.checkOperation(); }
        function onBondedChanged() { root.checkOperation(); }
    }
    Timer {
        id: operationTimeout; interval: 25000
        onTriggered: {
            root.checkOperation();
            if (root.operation) {
                if (root.pendingDevice) root.failedPath = root.pendingDevice.dbusPath;
                root.complete("Operazione non riuscita o scaduta.");
            }
        }
    }
    function act(device, action) {
        if (!contains(device) || !enabled || !writable() || operation || device.blocked) return;
        if (action === "pair") { manage(); return; }
        if (!(device.paired || device.bonded) || ["connect", "disconnect"].indexOf(action) < 0) return;
        pendingDevice = device; operation = action; message = ""; failedPath = ""; operationTimeout.restart();
        device.connected = action === "connect";
    }
    function requestForget(device) { if (contains(device) && (device.paired || device.bonded)) forgetPath = device.dbusPath; }
    function confirmForget(device) {
        if (!contains(device) || forgetPath !== device.dbusPath || !writable() || operation) return;
        forgetPath = ""; pendingDevice = device; operation = "forget";
        message = "Rimozione in corso…"; operationTimeout.restart(); device.forget();
    }
    function manage() {
        if (!available || !writable() || settings.running) return;
        stopScan(scanOwner);
        message = "";
        managementRequested();
        // Mock backends exercise routing without opening real windows.
        if (backend === Bluetooth) settings.running = true;
    }
    Process {
        id: settings
        command: [Quickshell.env("HOME") + "/.local/bin/workstation-system-tool", "bluetooth"]
        onExited: (code, status) => {
            if (code !== 0) root.message = "BlueTUI non avviabile. Verificare il launcher con il doctor.";
        }
    }
    Component.onDestruction: stopScan(scanOwner)
}
