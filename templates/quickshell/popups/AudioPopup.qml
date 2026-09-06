import QtQuick
import QtQuick.Controls
import ".."
BarPopup {
    id: root
    required property var service
    Text { width: parent.width; wrapMode: Text.Wrap; color: Theme.foreground; text: service.sink ? service.sink.description : "Nessuna uscita audio" }
    Text { color: Theme.foreground; text: service.label }
    Slider {
        width: parent.width; from: 0; to: 1; stepSize: 0.01
        enabled: service.available
        value: service.audio ? service.audio.volume : 0
        onMoved: service.setVolume(value)
        palette.highlight: Theme.accent
    }
    ActionButton { text: service.audio && service.audio.muted ? "Riattiva audio" : "Mute"; enabled: service.available; onClicked: service.mute() }
    ActionButton { text: "Chiudi"; onClicked: root.closeRequested() }
}
