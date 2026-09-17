import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import ".."
BarPopup {
    id: root
    required property var systemData
    required property var audioService
    required property var bluetoothService
    signal navigate(string destination)
    readonly property var network: systemData.network
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "workstation-quick-settings"
    implicitWidth: 340
    function session(action) {
        closeRequested();
        if (Quickshell.env("WORKSTATION_QUICKSHELL_TEST") !== "1")
            Quickshell.execDetached(["bash", Quickshell.shellPath("services/power.sh"), action]);
    }
    Shortcut { sequence: "Escape"; enabled: root.visible; onActivated: root.closeRequested() }
    Text { text: "Quick Settings"; color: Theme.foreground }
    ScrollView {
        width: parent.width; contentWidth: availableWidth; clip: true
        implicitHeight: Math.min(body.implicitHeight, Math.max(120, root.screen.height - 150), 520)
        Column {
            id: body; width: parent.width; spacing: 10
            DeviceButton {
                text: "Rete · " + ((root.network.interfaces || []).filter(i => i.ssid).map(i => i.ssid).join(", ") || root.network.label || root.network.state)
                onClicked: root.navigate("network")
            }
            ActionButton {
                visible: root.network.wifiAvailable === true
                text: !root.network.wifiHardwareEnabled ? "Wi-Fi · Blocked" : root.network.wifiEnabled ? "Wi-Fi ON" : "Wi-Fi OFF"
                enabled: root.network.wifiHardwareEnabled === true && !root.network.busy
                onClicked: root.systemData.networkCommand({action: "toggle", enabled: !root.network.wifiEnabled})
            }
            Row {
                visible: root.bluetoothService.available; spacing: 8
                ActionButton {
                    text: "Bluetooth " + root.bluetoothService.state
                    enabled: !root.bluetoothService.blocked && !root.bluetoothService.transitioning && !root.bluetoothService.powerPending
                    onClicked: root.bluetoothService.toggle()
                }
                ActionButton { text: "Dispositivi · " + root.bluetoothService.connected.length; onClicked: root.navigate("bluetooth") }
            }
            Text { text: "OUTPUT"; color: Theme.secondary }
            DeviceButton { text: root.audioService.sink ? root.audioService.name(root.audioService.sink) : "Uscita non disponibile"; onClicked: root.navigate("audio") }
            Slider {
                objectName: "quickOutput"; width: parent.width; from: 0; to: 1; stepSize: .01
                enabled: root.audioService.available; value: root.audioService.audio ? root.audioService.audio.volume : 0
                palette.highlight: Theme.accent; onMoved: root.audioService.setVolume(value)
            }
            ActionButton { text: root.audioService.label + " · " + (root.audioService.audio && root.audioService.audio.muted ? "Riattiva" : "Mute"); enabled: root.audioService.available; onClicked: root.audioService.mute() }
            Text { text: "INPUT"; color: Theme.secondary }
            DeviceButton { text: root.audioService.source ? root.audioService.name(root.audioService.source) : "Ingresso non disponibile"; onClicked: root.navigate("audio") }
            Slider {
                objectName: "quickInput"; width: parent.width; from: 0; to: 1; stepSize: .01
                enabled: root.audioService.inputAudio !== null; value: root.audioService.inputAudio ? root.audioService.inputAudio.volume : 0
                palette.highlight: Theme.accent; onMoved: root.audioService.setInputVolume(value)
            }
            ActionButton {
                text: "Microfono " + (root.audioService.inputAudio ? Math.round(root.audioService.inputAudio.volume * 100) + "% · " + (root.audioService.inputAudio.muted ? "Riattiva" : "Mute") : "non disponibile")
                enabled: root.audioService.inputAudio !== null; onClicked: root.audioService.muteInput()
            }
            Text {
                color: Theme.secondary
                text: "CPU " + (root.systemData.stats.cpu ?? "—") + "%   RAM " + (root.systemData.stats.ram ?? "—") + "%"
                    + (root.systemData.stats.temperature !== null ? "   " + root.systemData.stats.temperature + "°C" : "")
            }
            Row {
                spacing: 8
                ActionButton { text: "Lock"; onClicked: root.session("Lock") }
                ActionButton { text: "Suspend"; onClicked: root.session("Suspend") }
                ActionButton { text: "Power"; onClicked: root.navigate("power") }
            }
        }
    }
    ActionButton { text: "Chiudi"; onClicked: root.closeRequested() }
}
