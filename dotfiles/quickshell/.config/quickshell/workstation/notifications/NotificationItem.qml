import QtQuick
import ".."
import "../popups"
import "Markup.js" as Markup
Rectangle {
    id: root
    required property var entry
    required property var service
    property bool compact: false
    readonly property var notification: entry ? entry.notification : null
    width: parent.width
    implicitHeight: body.implicitHeight + 20
    color: Theme.surface
    border.width: 1
    border.color: notification && notification.urgency === 2 ? Theme.critical : notification && notification.urgency === 0 ? Theme.secondary : Theme.accent
    Component.onDestruction: if (root.compact && root.entry) root.entry.hovered = false
    HoverHandler { onHoveredChanged: if (root.compact && root.entry) root.entry.hovered = hovered }
    Column {
        id: body; x: 10; y: 10; width: parent.width - 20; spacing: 6
        Row {
            width: parent.width; spacing: 6
            Image {
                source: root.notification ? root.service.imageSource(root.notification.appIcon) : ""
                visible: source.toString() !== "" && status === Image.Ready
                width: visible ? 20 : 0; height: width; sourceSize.width: 20; sourceSize.height: 20
            }
            Text {
                width: parent.width - 70; elide: Text.ElideRight; textFormat: Text.PlainText
                text: root.notification ? root.notification.appName : ""; color: Theme.secondary; font.pixelSize: 12
            }
            ActionButton { text: "×"; implicitHeight: 22; onClicked: root.service.dismiss(root.entry) }
        }
        Text { visible: !root.compact; color: Theme.secondary; font.pixelSize: 11; text: root.entry ? new Date(root.entry.receivedAt).toLocaleTimeString(Qt.locale("it_IT"), "HH:mm") : "" }
        Text {
            width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            textFormat: Text.PlainText; font.bold: true; color: Theme.foreground
            text: root.notification ? root.notification.summary : ""
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap; maximumLineCount: root.compact ? 3 : 20; elide: Text.ElideRight
            textFormat: Text.StyledText; color: Theme.foreground
            text: Markup.normalize(root.notification ? root.notification.body : ""); visible: text !== ""
        }
        Image {
            source: root.notification ? root.service.imageSource(root.notification.image) : ""
            visible: source.toString() !== "" && status === Image.Ready
            width: parent.width; height: visible ? (root.compact ? 64 : 120) : 0
            fillMode: Image.PreserveAspectFit; sourceSize.width: 120; sourceSize.height: 120
        }
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: root.notification ? (root.compact ? root.notification.actions.slice(0, 4) : root.notification.actions) : []
                ActionButton {
                    required property var modelData
                    text: modelData.identifier === "default" ? "Apri" : modelData.text
                    implicitWidth: Math.min(280, contentItem.implicitWidth + 20)
                    onClicked: root.service.invoke(root.entry, modelData)
                }
            }
        }
    }
}
