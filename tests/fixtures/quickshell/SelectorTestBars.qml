import Quickshell
import "bar"
Scope {
    id: fixture
    property var systemData: null
    property var audioService: null
    property var bluetoothService: null
    property var rootState: null
    Variants {
        model: fixture.rootState ? Quickshell.screens : []
        Bar {
            required property var modelData
            screen: modelData
            systemData: fixture.systemData
            audioService: fixture.audioService
            bluetoothService: fixture.bluetoothService
            opened: fixture.rootState.opened
        }
    }
}
