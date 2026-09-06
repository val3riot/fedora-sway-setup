import QtQuick
import Quickshell
import ".."
PopupWindow {
    id: root
    signal closeRequested()
    required property var panel
    anchor.window: panel
    anchor.rect.x: Math.max(0, panel.width - implicitWidth - 8)
    anchor.rect.y: panel.height
    implicitWidth: 320
    implicitHeight: body.implicitHeight + 24
    color: Theme.surface
    default property alias content: body.data
    Column {
        id: body
        x: 12; y: 12
        width: parent.width - 24
        spacing: 10
    }
}
