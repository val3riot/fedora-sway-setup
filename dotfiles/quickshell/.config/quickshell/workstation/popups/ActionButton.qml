import QtQuick
import QtQuick.Controls
import ".."
Button {
    id: control
    implicitHeight: 30
    implicitWidth: Math.max(32, contentItem.implicitWidth + 20)
    contentItem: Text {
        text: control.text
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: control.down ? Theme.background : Theme.foreground
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 13
    }
    background: Rectangle {
        color: control.down ? Theme.accent : control.hovered ? "#303030" : "#222222"
    }
}
