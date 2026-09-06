import QtQuick
import QtQuick.Controls
import ".."
import "../notifications"
BarPopup {
    id: root
    required property var service
    implicitWidth: 380
    Text { text: "Notifiche"; color: Theme.foreground }
    Text { width: parent.width; wrapMode: Text.Wrap; text: root.service.error; visible: text !== ""; color: Theme.critical; textFormat: Text.PlainText }
    ActionButton { text: "Pulisci normali"; enabled: root.service.canClear; onClicked: root.service.clear() }
    Text { visible: root.service.count === 0; text: "Nessuna notifica"; color: Theme.secondary }
    ScrollView {
        width: parent.width; contentWidth: availableWidth; clip: true
        implicitHeight: Math.min(520, Math.max(100, root.panel.screen.height - 180), items.implicitHeight)
        Column {
            id: items; width: parent.width; spacing: 8
            Repeater { model: root.service.centerEntries; NotificationItem { required property var modelData; entry: modelData; service: root.service } }
        }
    }
    ActionButton { text: "Chiudi"; onClicked: root.closeRequested() }
}
