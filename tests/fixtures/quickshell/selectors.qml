import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "services"
ShellRoot {
    id: root
    property int managementRequests: 0
    property bool graphical: Quickshell.env("WORKSTATION_QUICKSHELL_UI_TEST") === "1"
    property string opened: "audio"
    property int phase: 0
    QtObject {
        id: telemetry
        property var stats: ({cpu: 25, ram: 40, temperature: 50})
        property var occupied: ({})
        property var fullscreen: ({})
        property var network: ({connected: true, state: "Connessa", label: "WIFI", interfaces: [],
            wifiAvailable: true, wifiEnabled: true, wifiHardwareEnabled: true, busy: false, scanning: false,
            accessPoints: Array.from({length: 30}, (_, i) => ({ssid: "Test network " + i, current: i === 0,
                strength: 90 - i, secure: true, security: "WPA/RSN", saved: i === 0, path: "/ap/" + i}))})
        function networkCommand(command) { }
    }
    Loader {
        active: root.graphical
        source: root.graphical ? "SelectorTestBars.qml" : ""
        onLoaded: { item.systemData = telemetry; item.audioService = audio; item.bluetoothService = bt; item.rootState = root; }
    }
    property int checks: 0
    function check(value, name) { checks++; if (!value) { console.error("TEST FAILED " + name); Qt.exit(1); } }
    QtObject { id: audioModel; property var values: [] }
    QtObject {
        id: pw
        property bool ready: true
        property var nodes: audioModel
        property var defaultAudioSink: null
        property var defaultAudioSource: null
        property var preferredDefaultAudioSink: null
        property var preferredDefaultAudioSource: null
    }
    Component {
        id: nodeComponent
        QtObject {
            property int id: 0
            property string name: ""
            property string description: ""
            property string nickname: ""
            property bool ready: true
            property bool isStream: false
            property bool isSink: true
            property var properties: ({"media.class": "Audio/Sink"})
            property var audio: QtObject { property real volume: 0.5; property bool muted: false }
        }
    }
    AudioService { id: audio; backend: pw }
    QtObject { id: adapterModel; property var values: [] }
    QtObject { id: deviceModel; property var values: [] }
    QtObject {
        id: adapter
        property string name: "Test adapter"
        property string dbusPath: "/adapter/1"
        property bool enabled: false
        property int state: BluetoothAdapterState.Disabled
        property bool discovering: false
        property var devices: deviceModel
    }
    QtObject { id: bluez; property var adapters: adapterModel; property var defaultAdapter: null }
    Component {
        id: deviceComponent
        QtObject {
            property string dbusPath: "/device/1"
            property string name: "Headset"
            property string address: "00:11:22:33:44:55"
            property string deviceName: "Headset"
            property string icon: "audio-headset"
            property bool connected: false
            property bool paired: false
            property bool bonded: false
            property bool pairing: false
            property bool blocked: false
            property bool trusted: false
            property bool batteryAvailable: false
            property real battery: 0
            property int state: BluetoothDeviceState.Disconnected
            property int forgetCalls: 0
            function pair() { pairing = true; }
            function cancelPair() { pairing = false; }
            function forget() { forgetCalls++; }
        }
    }
    BluetoothService { id: bt; backend: bluez; onManagementRequested: root.managementRequests++ }
    property var speaker: null
    property var mic: null
    property var headset: null
    property var device: null
    Timer {
        interval: root.graphical ? 400 : 100; running: true; repeat: true
        onTriggered: {
            root.phase++;
            switch (root.phase) {
            case 1:
                root.check(!bt.available && bt.devices.length === 0, "Bluetooth optional absent");
                root.check(!audio.available && audio.source === null, "audio null defaults");
                root.speaker = nodeComponent.createObject(root, {name: "speakers"});
                root.mic = nodeComponent.createObject(root, {name: "microphone", isSink: false, properties: {"media.class": "Audio/Source"}});
                root.headset = nodeComponent.createObject(root, {name: "bluez_output.headset", description: "Bluetooth headset"});
                audioModel.values = [root.speaker, root.mic, root.headset,
                    nodeComponent.createObject(root, {name: "Firefox", isStream: true}),
                    nodeComponent.createObject(root, {name: "speakers.monitor", isSink: false, properties: {"media.class": "Audio/Source"}}),
                    nodeComponent.createObject(root, {name: "internal", properties: {"media.class": "Audio/Sink", "node.virtual": "true"}})];
                adapterModel.values = [adapter]; bluez.defaultAdapter = adapter;
                break;
            case 2:
                root.check(audio.outputs.length === 2 && audio.inputs.length === 1, "hardware filter incl Bluetooth audio");
                audio.select(root.headset, true); audio.select(root.mic, false);
                root.check(pw.preferredDefaultAudioSink === root.headset, "sink selection");
                root.check(pw.preferredDefaultAudioSource === root.mic, "source selection");
                pw.defaultAudioSink = root.headset; pw.defaultAudioSource = root.mic;
                audio.select(root.mic, true);
                root.check(pw.preferredDefaultAudioSink === root.headset, "reject input as output");
                root.check(bt.available && !bt.enabled && bt.state === "OFF", "adapter disabled present");
                adapter.state = BluetoothAdapterState.Blocked;
                break;
            case 3:
                root.check(bt.blocked && bt.state === "Blocked", "rfkill");
                bt.toggle(); root.check(!adapter.enabled, "blocked toggle inert");
                adapter.state = BluetoothAdapterState.Disabled;
                break;
            case 4:
                root.opened = "network";
                bt.toggle(); root.check(adapter.enabled, "native adapter toggle");
                adapter.state = BluetoothAdapterState.Enabling;
                root.check(bt.transitioning, "enabling");
                adapter.state = BluetoothAdapterState.Disabling;
                root.check(bt.transitioning, "disabling");
                adapter.state = BluetoothAdapterState.Enabled;
                root.device = deviceComponent.createObject(root);
                root.device.name = "00-11-22-33-44-55"; root.device.deviceName = "Cuffie reali";
                root.check(bt.displayName(root.device) === "Cuffie reali", "address alias does not hide device name");
                root.device.deviceName = "";
                root.check(bt.displayName(root.device) === "Nome non disponibile", "missing BlueZ name is explicit");
                root.device.deviceName = "Nome arrivato via evento";
                root.check(bt.displayName(root.device) === "Nome arrivato via evento", "late device name update");
                root.device.name = "Alias personale";
                root.check(bt.displayName(root.device) === "Alias personale", "meaningful alias preserved");

                deviceModel.values = [root.device];
                audio.setVolume(0.42); audio.setInputVolume(0.65); audio.mute(); audio.muteInput();
                root.check(root.headset.audio.volume === 0.42 && root.mic.audio.volume === 0.65, "volumes follow defaults");
                root.check(root.headset.audio.muted && root.mic.audio.muted, "sink and source mute");
                break;
            case 5:
                root.opened = "bluetooth";
                root.check(bt.enabled && bt.discovered.length === 1, "discovered device");
                root.check(bt.batteryText(root.device) === "", "unavailable battery hidden");
                root.device.batteryAvailable = true; root.device.battery = 0.83;
                root.check(bt.batteryText(root.device) === "83%", "battery percent");
                bt.startScan(root); root.check(adapter.discovering, "start discovery");
                bt.stopScan(null); root.check(adapter.discovering, "other popup cannot stop owned scan");
                bt.stopScan(root); root.check(!adapter.discovering, "stop own discovery");
                adapter.discovering = true; bt.startScan(root); bt.stopScan(root);
                root.check(adapter.discovering, "external discovery preserved"); adapter.discovering = false;
                bt.act(root.device, "pair"); root.check(!root.device.pairing, "new pairing delegated to TUI");
                root.check(root.managementRequests === 1, "TUI management requested once");
                root.device.pairing = false;
                break;
            case 6:
                root.check(bt.operation === "", "no half-started pairing");
                root.check(root.managementRequests === 1, "no automatic GUI fallback");
                root.device.paired = true; root.device.bonded = true;
                break;
            case 7:
                root.check(bt.paired.length === 1 && bt.discovered.length === 0, "paired grouping");
                bt.act(root.device, "connect"); root.check(root.device.connected, "connect setter");
                root.check(root.managementRequests === 1, "normal connect stays native");
                root.device.state = BluetoothDeviceState.Connecting;
                root.check(bt.deviceState(root.device) === "Connecting", "connecting state");
                root.device.state = BluetoothDeviceState.Connected;
                break;
            case 8:
                root.opened = "audio";
                root.check(bt.connected.length === 1 && bt.operation === "", "connected transition");
                bt.act(root.device, "disconnect"); root.check(!root.device.connected, "disconnect setter");
                root.device.state = BluetoothDeviceState.Disconnecting;
                root.check(bt.deviceState(root.device) === "Disconnecting", "disconnecting state");
                root.device.state = BluetoothDeviceState.Disconnected;
                bt.confirmForget(root.device); root.check(root.device.forgetCalls === 0, "forget needs confirmation");
                bt.requestForget(root.device); bt.confirmForget(root.device);
                root.check(root.device.forgetCalls === 1, "confirmed forget");
                root.check(!root.device.trusted, "trusted unchanged");
                bt.act(root.device, "connect"); deviceModel.values = [];
                audioModel.values = [root.speaker]; pw.defaultAudioSink = null; pw.defaultAudioSource = null;
                break;
            case 9:
                root.check(bt.devices.length === 0 && bt.operation === "", "device removal during operation");
                root.check(audio.outputs.length === 1 && !audio.inputs.length && !audio.available, "audio hot unplug");
                bt.startScan(root);
                bluez.defaultAdapter = null; adapterModel.values = []; pw.ready = false;
                break;
            case 10:
                root.check(!bt.available && !bt.devices.length, "adapter hot unplug");
                root.check(bt.scanOwner === null && bt.scanPath === "", "adapter removal clears scan ownership");
                root.check(!audio.ready && audio.sink === null, "PipeWire unavailable");
                console.warn("TEST selectors OK " + root.checks + " checks"); Qt.quit();
            }
        }
    }
}
