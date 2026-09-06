import QtQuick
import QtQuick.Controls
import ".."
BarPopup {
    id: root
    required property var network
    Text { text: "Rete · " + network.state; color: Theme.foreground }
    Repeater {
        model: network.interfaces
        Text {
            required property var modelData
            width: parent.width; wrapMode: Text.Wrap; color: Theme.foreground
            text: modelData.type + " · " + modelData.interface + "\n" + modelData.state
                  + "\nIPv4: " + (modelData.ipv4.join(", ") || "—")
                  + (modelData.ssid ? "\nSSID: " + modelData.ssid : "")
        }
    }
    ActionButton { text: "Chiudi"; onClicked: root.closeRequested() }
}
