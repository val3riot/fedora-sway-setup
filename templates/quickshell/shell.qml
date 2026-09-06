import Quickshell
import "bar"
import "services" as Services
import "notifications"
ShellRoot {
    Services.SystemData { id: telemetry }
    Services.AudioService { id: audio }
    Services.BluetoothService { id: bluetooth }
    Services.Notifications { id: notifications }
    NotificationToastStack { service: notifications }
    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
            systemData: telemetry
            audioService: audio
            bluetoothService: bluetooth
            notificationService: notifications
        }
    }
}
