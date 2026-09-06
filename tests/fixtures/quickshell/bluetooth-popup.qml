import QtQuick
import Quickshell
import Quickshell.Io
import "popups"
import "notifications"
ShellRoot {
    id: root
    QtObject {
        id: mock
        property bool available: true
        property bool enabled: true
        property bool blocked: false
        property bool transitioning: false
        property bool powerPending: false
        property bool discovering: false
        property string state: enabled ? "ON" : "OFF"
        property string message: ""
        property string forgetPath: ""
        property string pairingFallbackPath: ""
        property string operation: ""
        property var scanOwner: null
        property var adapters: []
        property var connected: []
        property var paired: []
        property var discovered: []
        function manage() {}
        function stopScan(owner) { discovering = false; scanOwner = null; }
        function startScan(owner) { discovering = true; scanOwner = owner; }
        function toggle() { enabled = !enabled; }
        function resolvedName(d) { return d.name; }
        function displayName(d) { return d.name; }
        function batteryText(d) { return ""; }
        function deviceState(d) { return "Disconnected"; }
        function classify(d) { return "Bluetooth"; }
    }
    QtObject {
        id: device
        property string name: "Dispositivo di prova con nome lungo"
        property string address: "00:11:22:33:44:55"
        property string dbusPath: "/test/device"
        property string icon: ""
        property bool paired: false
        property bool bonded: false
        property bool connected: false
        property bool blocked: false
        property bool trusted: false
        property bool pairing: false
    }
    PanelWindow {
        id: panel
        anchors { top: true; left: true; right: true }
        implicitHeight: 32
        color: "#101010"
    }
    BluetoothPopup { id: popup; panel: panel; service: mock; visible: true }
    QtObject {
        id: noticeService
        property bool shown: false
        property var toasts: shown ? [entry] : []
        function imageSource(value) { return ""; }
        function dismiss(value) { shown = false; }
        function invoke(value, action) { shown = false; }
    }
    QtObject {
        id: entry
        property bool hovered: false
        property double receivedAt: Date.now()
        property var notification: ({appName: "Overlay test", summary: "Conferma pairing", body: "<h1>Bluetooth</h1>Premi <b>123456</b> · <i>italic</i> &amp; testo", urgency: 2, appIcon: "", image: "", actions: []})
    }
    NotificationToastStack { service: noticeService }
    IpcHandler {
        target: "popupTest"
        function toast(shown: bool): void { noticeService.shown = shown; }
        function change(mode: int): void {
            mock.enabled = mode !== 3;
            mock.message = mode === 4 ? "Operazione non riuscita. Messaggio su più righe per verificare il layout." : "";
            mock.discovered = mode === 1 ? [device, device, device, device] : [];
            mock.discovering = mode === 1;
            mock.scanOwner = mode === 1 ? popup : null;
        }
        function geometry(): string { return JSON.stringify({width: popup.width, height: popup.height, implicitHeight: popup.implicitHeight}); }
    }
}
