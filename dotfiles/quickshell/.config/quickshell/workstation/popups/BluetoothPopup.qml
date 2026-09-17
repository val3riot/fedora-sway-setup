import QtQuick
import QtQuick.Controls
import ".."
BarPopup {
    id: root
    required property var service
    // Stable compact viewport while devices appear/disappear.
    implicitHeight: Math.min(420, Math.max(200, panel.screen.height - panel.height - 24))
    onVisibleChanged: if (!visible) { service.stopScan(root); service.forgetPath = ""; }
    Text { id: header; height: 18; text: "Bluetooth · " + root.service.state; color: Theme.foreground }
    ActionButton {
        id: scanButton
        text: root.service.scanOwner === root ? "Ricerca… · Ferma" : root.service.discovering ? "Ricerca in corso altrove" : "Cerca dispositivi"
        enabled: root.service.enabled && (!root.service.discovering || root.service.scanOwner === root)
        onClicked: root.service.scanOwner === root ? root.service.stopScan(root) : root.service.startScan(root)
    }
    ActionButton {
        id: powerButton
        text: root.service.enabled ? "Spegni Bluetooth" : "Accendi Bluetooth"
        enabled: root.service.available && !root.service.blocked && !root.service.transitioning && !root.service.powerPending
        onClicked: root.service.toggle()
    }
    ActionButton { id: manageButton; text: "Associa / Gestisci · BlueTUI"; enabled: root.service.available; onClicked: root.service.manage() }
    ScrollView {
        id: deviceScroll
        width: parent.width; contentWidth: availableWidth; clip: true
        implicitHeight: root.implicitHeight - 24 - header.height - scanButton.height
                        - powerButton.height - manageButton.height - closeButton.height - 5 * 10
        contentHeight: devicesBody.implicitHeight
        Column {
            id: devicesBody; width: deviceScroll.availableWidth; spacing: 8
            Text { width: parent.width; wrapMode: Text.Wrap; text: root.service.message; visible: text !== ""; color: Theme.warning; textFormat: Text.PlainText }
            Repeater {
                model: root.service.adapters.length > 1 ? root.service.adapters : []
                DeviceButton {
                    required property var modelData
                    text: modelData.name; selected: modelData === root.service.adapter
                    onClicked: root.service.selectedAdapter = modelData.dbusPath
                }
            }
            Text { text: "CONNESSI"; color: Theme.secondary; visible: root.service.connected.length > 0 }
            Repeater { model: root.service.connected; BluetoothDeviceRow { required property var modelData; device: modelData; service: root.service } }
            Text { text: "ASSOCIATI"; color: Theme.secondary; visible: root.service.paired.length > 0 }
            Repeater { model: root.service.paired; BluetoothDeviceRow { required property var modelData; device: modelData; service: root.service } }
            Text { text: "DISPONIBILI"; color: Theme.secondary; visible: root.service.discovered.length > 0 }
            Repeater { model: root.service.discovered; BluetoothDeviceRow { required property var modelData; device: modelData; service: root.service } }
        }
    }
    ActionButton { id: closeButton; text: "Chiudi"; onClicked: root.closeRequested() }
}
