import QtQuick
import QtQuick.Controls
import ".."
BarPopup {
    id: root
    required property var service
    Text { color: Theme.foreground; text: service.ready ? "Audio" : "PipeWire non disponibile" }
    ScrollView {
        width: parent.width
        implicitHeight: Math.min(460, Math.max(120, root.panel.screen.height - 160), audioBody.implicitHeight)
        clip: true
        contentWidth: availableWidth
        Column {
            id: audioBody; width: parent.width; spacing: 8
            Text { color: Theme.secondary; text: "OUTPUT" }
            Repeater {
                model: root.service.outputs
                DeviceButton {
                    required property var modelData
                    text: root.service.name(modelData)
                    selected: modelData === root.service.sink
                    onClicked: root.service.select(modelData, true)
                }
            }
            Text { visible: !root.service.outputs.length; color: Theme.secondary; text: "Nessuna uscita audio" }
            Text { color: Theme.foreground; text: root.service.label }
            Slider {
                width: parent.width; from: 0; to: 1; stepSize: 0.01
                enabled: root.service.available
                value: root.service.audio ? root.service.audio.volume : 0
                onMoved: root.service.setVolume(value)
                palette.highlight: Theme.accent
            }
            ActionButton { text: root.service.audio && root.service.audio.muted ? "Riattiva audio" : "Mute output"; enabled: root.service.available; onClicked: root.service.mute() }
            Text { color: Theme.secondary; text: "INPUT" }
            Repeater {
                model: root.service.inputs
                DeviceButton {
                    required property var modelData
                    text: root.service.name(modelData)
                    selected: modelData === root.service.source
                    onClicked: root.service.select(modelData, false)
                }
            }
            Text { visible: !root.service.inputs.length; color: Theme.secondary; text: "Nessun ingresso audio" }
            Text { color: Theme.foreground; text: root.service.inputAudio ? "Input volume " + Math.round(root.service.inputAudio.volume * 100) + "%" : "Input non disponibile" }
            Slider {
                width: parent.width; from: 0; to: 1; stepSize: 0.01
                enabled: root.service.inputAudio !== null
                value: root.service.inputAudio ? root.service.inputAudio.volume : 0
                onMoved: root.service.setInputVolume(value)
                palette.highlight: Theme.accent
            }
            ActionButton { text: root.service.inputAudio && root.service.inputAudio.muted ? "Riattiva microfono" : "Mute microfono"; enabled: root.service.inputAudio !== null; onClicked: root.service.muteInput() }
        }
    }
    Text { width: parent.width; wrapMode: Text.Wrap; color: Theme.critical; text: root.service.error; visible: text !== "" }
    ActionButton { text: "Chiudi"; onClicked: root.closeRequested() }
}
