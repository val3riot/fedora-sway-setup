import QtQuick
import QtQuick.Controls
import ".."
Button {
    id: root
    property bool selected: false
    width: parent.width
    implicitHeight: Math.max(32, label.implicitHeight + 10)
    contentItem: Text {
        id: label
        text: (root.selected ? "✓ " : "") + root.text
        textFormat: Text.PlainText
        color: root.selected ? Theme.accent : !root.enabled ? Theme.secondary : Theme.foreground
        wrapMode: Text.Wrap
        font.pixelSize: 13
    }
    background: Rectangle { color: root.hovered ? "#303030" : "transparent" }
}
