import QtQuick
import QtQuick.Controls
import ".."
BarPopup {
    id: root
    required property var network
    required property var service
    Text { text: "Rete · " + root.network.state; color: Theme.foreground }
    ScrollView {
        width: parent.width
        implicitHeight: Math.min(420, Math.max(120, root.panel.screen.height - 180), networkBody.implicitHeight)
        contentWidth: availableWidth; clip: true
        Column {
            id: networkBody; width: parent.width; spacing: 8
            Repeater {
                model: root.network.interfaces
                Text {
                    required property var modelData
                    width: parent.width; wrapMode: Text.Wrap; color: Theme.foreground
                    textFormat: Text.PlainText
                    text: modelData.type + " · " + modelData.interface + "\n" + modelData.state
                          + "\nIPv4: " + (modelData.ipv4.join(", ") || "—")
                          + (modelData.ssid ? "\nSSID: " + modelData.ssid : "")
                }
            }
            Column {
                width: parent.width; spacing: 6
                visible: root.network.wifiAvailable === true
                ActionButton {
                    text: !root.network.wifiHardwareEnabled ? "Wi-Fi · Blocked" : root.network.wifiEnabled ? "Wi-Fi ON · Spegni" : "Wi-Fi OFF · Accendi"
                    enabled: root.network.wifiHardwareEnabled === true && !root.network.busy
                    onClicked: root.service.networkCommand({action: "toggle", enabled: !root.network.wifiEnabled})
                }
                Repeater {
                    model: root.network.wifiEnabled ? root.network.accessPoints || [] : []
                    DeviceButton {
                        required property var modelData
                        selected: modelData.current
                        text: modelData.ssid + " · " + modelData.strength + "% · " + modelData.security
                              + (modelData.saved ? " · salvata" : "")
                        enabled: !root.network.busy && !modelData.current
                        onClicked: root.service.networkCommand({action: "connect", path: modelData.path})
                    }
                }
                ActionButton {
                    text: root.network.scanning ? "Scansione…" : "Aggiorna reti"
                    enabled: root.network.wifiEnabled === true && !root.network.scanning
                    onClicked: root.service.networkCommand({action: "scan"})
                }
                ActionButton { text: "Configurazione avanzata · nmtui"; onClicked: root.service.networkCommand({action: "configure"}) }
            }
        }
    }
    Text { width: parent.width; wrapMode: Text.Wrap; color: /fallit|non riusc|non più/.test(root.network.message || "") ? Theme.critical : Theme.secondary; text: root.network.message || ""; visible: text !== ""; textFormat: Text.PlainText }
    ActionButton { text: "Chiudi"; onClicked: root.closeRequested() }
}
