import Quickshell
import "bar"
import "services" as Services
import "notifications"
import "desktop"
import "popups"
import QtQuick
ShellRoot {
    id: desktopRoot
    property var controlPanel: null
    signal closePanels()
    Loader {
        active: desktopRoot.controlPanel !== null
        sourceComponent: QuickSettings {
            panel: desktopRoot.controlPanel
            systemData: telemetry; audioService: audio; bluetoothService: bluetooth
            onCloseRequested: desktopRoot.controlPanel = null
            onNavigate: destination => {
                const target = desktopRoot.controlPanel;
                desktopRoot.controlPanel = null;
                if (target) target.opened = destination;
            }
        }
    }
    Services.SystemData { id: telemetry }
    Services.AudioService { id: audio }
    Services.BluetoothService { id: bluetooth }
    Services.Notifications { id: notifications }
    DesktopTools { audioService: audio; onOpenedChanged: if (opened !== "") { desktopRoot.controlPanel = null; desktopRoot.closePanels(); } }
    NotificationToastStack { service: notifications }
    Variants {
        model: Quickshell.screens
        Bar {
            id: outputBar
            Connections { target: desktopRoot; function onClosePanels() { outputBar.opened = ""; } }
            required property var modelData
            screen: modelData
            onQuickSettingsRequested: {
                const previous = desktopRoot.controlPanel;
                desktopRoot.closePanels();
                desktopRoot.controlPanel = previous === outputBar ? null : outputBar;
            }
            onDismissControls: desktopRoot.controlPanel = null
            systemData: telemetry
            audioService: audio
            bluetoothService: bluetooth
            notificationService: notifications
        }
    }
}
