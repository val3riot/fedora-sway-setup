import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
PanelWindow {
    id: root
    signal closeRequested()
    required property var panel
    // Layer surfaces, not xdg popups: compositor popups can cover Overlay toasts.
    screen: panel.screen
    anchors { top: true; right: true }
    margins { top: panel.height; right: 8 }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "workstation-popup"
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
