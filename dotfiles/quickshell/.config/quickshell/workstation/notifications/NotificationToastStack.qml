import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
PanelWindow {
    id: root
    required property var service
    // Exactly one window, following focused output with a stable first-output fallback.
    screen: Quickshell.screens.find(s => I3.focusedWorkspace && I3.focusedWorkspace.monitor && s.name === I3.focusedWorkspace.monitor.name) || Quickshell.screens[0] || null
    anchors { top: true; right: true }
    margins { top: 40; right: 12 }
    implicitWidth: 360
    implicitHeight: Math.min(stack.implicitHeight, screen ? Math.max(100, screen.height - 60) : 600)
    exclusionMode: ExclusionMode.Ignore
    visible: service.toasts.length > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "workstation-notifications"
    ScrollView {
        anchors.fill: parent; contentWidth: availableWidth; clip: true
        Column {
            id: stack; width: parent.width; spacing: 8
            Repeater {
                model: root.service.toasts
                NotificationItem { required property var modelData; entry: modelData; service: root.service; compact: true }
            }
        }
    }
}
