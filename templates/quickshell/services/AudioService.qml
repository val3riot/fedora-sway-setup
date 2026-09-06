import Quickshell
import Quickshell.Services.Pipewire
Scope {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property bool available: audio !== null
    readonly property string label: !available ? "VOL —" : audio.muted ? "VOL mute" : "VOL " + Math.round(audio.volume * 100) + "%"
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    function setVolume(value) { if (audio) audio.volume = Math.max(0, Math.min(1, value)); }
    function step(amount) { if (audio) setVolume(audio.volume + amount); }
    function mute() { if (audio) audio.muted = !audio.muted; }
}
