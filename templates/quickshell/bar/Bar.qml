import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../popups"
PanelWindow {
    id: root
    required property var systemData
    property var notificationService: null
    required property var bluetoothService
    required property var audioService
    property string opened: ""
    signal quickSettingsRequested()
    signal dismissControls()
    onOpenedChanged: if (opened !== "") dismissControls()
    readonly property bool fullscreen: systemData.fullscreen[screen.name] || false
    onFullscreenChanged: if (fullscreen) { opened = ""; dismissControls(); }
    function toggle(name) { opened = opened === name ? "" : name; }
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: Theme.background
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "workstation-quickshell"
    Connections { target: root.bluetoothService; ignoreUnknownSignals: true; function onManagementRequested() { root.opened = ""; } }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Workspaces { anchors.left: parent.left; output: root.screen; occupied: root.systemData.occupied }
    Row {
        id: right
        anchors.right: parent.right
        SystemStats { stats: root.systemData.stats }
        BarButton { text: root.systemData.network.connected ? root.systemData.network.label || "NET" : "NET off"; textColor: root.systemData.network.connected ? Theme.foreground : Theme.secondary; onClicked: root.toggle("network") }
        BarButton { visible: root.bluetoothService.available; text: "BT"; textColor: root.bluetoothService.connected.length ? Theme.accent : root.bluetoothService.enabled ? Theme.foreground : Theme.secondary; onClicked: root.toggle("bluetooth") }
        BarButton { text: root.audioService.label; onClicked: root.toggle("audio"); onMiddleClicked: root.audioService.mute(); onScrolled: delta => { if (delta !== 0) root.audioService.step(delta > 0 ? 0.05 : -0.05); } }
        BarButton { text: clock.date.toLocaleDateString(Qt.locale("it_IT"), "ddd dd") + " " + clock.date.toLocaleTimeString(Qt.locale("it_IT"), "HH:mm"); onClicked: root.toggle("calendar") }
        Loader { active: root.notificationService !== null; sourceComponent: Notifications { service: root.notificationService; onClicked: root.toggle("notifications") } }
        BarButton { text: "QS"; onClicked: root.quickSettingsRequested() }
        BarButton { text: "⏻"; onClicked: root.toggle("power") }
    }
    AudioPopup { panel: root; service: root.audioService; visible: !root.fullscreen && root.opened === "audio"; onCloseRequested: root.opened = "" }
    NetworkPopup { panel: root; service: root.systemData; network: root.systemData.network; visible: !root.fullscreen && root.opened === "network"; onCloseRequested: root.opened = "" }
    BluetoothPopup { panel: root; service: root.bluetoothService; visible: root.bluetoothService.available && !root.fullscreen && root.opened === "bluetooth"; onCloseRequested: root.opened = "" }
    CalendarPopup { panel: root; today: clock.date; visible: !root.fullscreen && root.opened === "calendar"; onCloseRequested: root.opened = "" }
    Loader { active: root.notificationService !== null; sourceComponent: NotificationCenter { panel: root; service: root.notificationService; visible: !root.fullscreen && root.opened === "notifications"; onCloseRequested: root.opened = "" } }
    PowerMenu { panel: root; visible: !root.fullscreen && root.opened === "power"; onCloseRequested: root.opened = "" }
}
