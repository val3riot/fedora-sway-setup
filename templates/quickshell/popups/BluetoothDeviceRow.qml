import QtQuick
import Quickshell
import ".."
Column {
    id: root
    required property var device
    required property var service
    property bool showDetails: false
    width: parent.width; spacing: 4
    DeviceButton {
        text: root.service.displayName(root.device) + " " + root.service.batteryText(root.device)
              + "\n" + root.service.deviceState(root.device)
              + (root.device && root.device.trusted ? " · trusted" : "")
        selected: root.device && root.device.connected
        enabled: root.service.enabled && !root.service.operation && root.device && !root.device.blocked
        onClicked: {
            if (root.device.paired || root.device.bonded) root.service.act(root.device, root.device.connected ? "disconnect" : "connect");
            else root.service.manage();
        }
    }
    ActionButton {
        visible: root.device && !root.service.resolvedName(root.device)
        text: root.showDetails ? "Nascondi dettagli" : "Dettagli dispositivo"
        onClicked: root.showDetails = !root.showDetails
    }
    Text {
        width: parent.width; wrapMode: Text.Wrap; textFormat: Text.PlainText
        visible: root.showDetails && root.device && !root.service.resolvedName(root.device)
        text: root.device ? "BlueZ non ha ancora un nome.\nIndirizzo: " + root.device.address : ""
        color: Theme.secondary
    }
    Image {
        readonly property bool hasIcon: root.device !== null && root.device.icon !== "" && Quickshell.hasThemeIcon(root.device.icon)
        visible: hasIcon
        source: hasIcon ? Quickshell.iconPath(root.device.icon) : ""
        width: 16; height: 16; sourceSize.width: 16; sourceSize.height: 16
    }
    Row {
        spacing: 6
        visible: root.device && !root.device.paired && !root.device.bonded
        ActionButton { text: "Associa in BlueTUI"; enabled: root.service.enabled; onClicked: root.service.manage() }
    }
    Text { text: root.service.classify(root.device); color: Theme.secondary; font.pixelSize: 11 }
    ActionButton {
        visible: root.device && (root.device.paired || root.device.bonded)
        text: root.device && root.device.connected ? "Disconnetti" : "Connetti"
        enabled: root.service.enabled && !root.service.operation && root.device && !root.device.blocked
        onClicked: root.service.act(root.device, root.device.connected ? "disconnect" : "connect")
    }
    ActionButton { visible: root.device && (root.device.paired || root.device.bonded); text: "Dimentica…"; onClicked: root.service.requestForget(root.device) }
    Column {
        width: parent.width; spacing: 4
        visible: root.device && root.service.forgetPath === root.device.dbusPath
        Text { width: parent.width; wrapMode: Text.Wrap; text: "Dimenticare questo dispositivo? Sarà necessario associarlo di nuovo."; color: Theme.warning }
        Row {
            spacing: 8
            ActionButton { text: "Conferma"; onClicked: root.service.confirmForget(root.device) }
            ActionButton { text: "Annulla"; onClicked: root.service.forgetPath = "" }
        }
    }
}
