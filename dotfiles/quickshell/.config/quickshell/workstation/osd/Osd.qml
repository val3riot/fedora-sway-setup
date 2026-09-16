import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import ".."
PanelWindow {
    id: root
    required property var service
    screen: Quickshell.screens.find(s => I3.focusedWorkspace && I3.focusedWorkspace.monitor && s.name === I3.focusedWorkspace.monitor.name) || Quickshell.screens[0] || null
    anchors.bottom: true
    margins.bottom: screen ? Math.round(screen.height * .12) : 80
    implicitWidth: 280; implicitHeight: 72
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "workstation-osd"
    visible: service.shown
    color: "transparent"
    Rectangle {
        anchors.fill: parent; color: Theme.surface; border.color: Theme.accent; border.width: 1
        Text { x: 16; y: 13; width: parent.width - 32; textFormat: Text.PlainText; color: Theme.foreground; elide: Text.ElideRight; font.pixelSize: 13
            text: root.service.title + (root.service.valueKnown ? " · " + (root.service.muted ? "MUTE · " : "") + Math.round(root.service.value * 100) + "%" : "") }
        Rectangle {
            x: 16; y: 47; width: parent.width - 32; height: 4; color: Theme.secondary
            Rectangle { height: parent.height; width: parent.width * root.service.value; color: root.service.muted ? Theme.secondary : Theme.accent }
        }
    }
}
