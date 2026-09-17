import QtQuick
import ".."
Rectangle {
    id: root
    property alias text: label.text
    property alias textColor: label.color
    signal clicked()
    signal middleClicked()
    signal scrolled(real delta)
    implicitWidth: label.implicitWidth + 16
    implicitHeight: Theme.barHeight
    color: mouse.containsMouse ? Theme.surface : "transparent"
    Text { id: label; anchors.centerIn: parent; color: Theme.foreground; font.family: "sans-serif"; font.pixelSize: 13 }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: event => { if (event.button === Qt.MiddleButton) root.middleClicked(); else root.clicked(); }
        onWheel: event => { root.scrolled(event.angleDelta.y); }
    }
}
