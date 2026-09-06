import Quickshell
import "bar"
import "services"
ShellRoot {
    SystemData { id: telemetry }
    AudioService { id: audio }
    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
            systemData: telemetry
            audioService: audio
        }
    }
}
