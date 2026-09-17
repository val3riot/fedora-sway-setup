import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
Scope {
    id: root
    property var backend: Pipewire
    readonly property bool ready: backend.ready
    readonly property var candidates: backend.nodes.values.filter(n => n && !n.isStream && n.audio)
    // Track before inspecting properties/volume. Bind all hardware candidates once.
    PwObjectTracker { objects: root.backend === Pipewire ? root.candidates : [] }
    readonly property var outputs: candidates.filter(n => useful(n, true))
    readonly property var inputs: candidates.filter(n => useful(n, false))
    readonly property var sink: ready ? backend.defaultAudioSink : null
    readonly property var source: ready ? backend.defaultAudioSource : null
    readonly property var audio: sink && sink.ready ? sink.audio : null
    readonly property var inputAudio: source && source.ready ? source.audio : null
    readonly property bool available: audio !== null
    readonly property string label: !available ? "VOL —" : audio.muted ? "VOL mute" : "VOL " + Math.round(audio.volume * 100) + "%"
    property string error: ""
    property var requested: null
    property bool requestedSink: true
    function useful(node, output) {
        if (!node || !node.ready || node.isStream || !node.audio || node.isSink !== output) return false;
        const p = node.properties;
        return p && p["media.class"] === (output ? "Audio/Sink" : "Audio/Source")
            && p["stream.monitor"] !== "true" && p["stream.monitor"] !== true
            && p["node.virtual"] !== "true" && p["node.virtual"] !== true
            && !node.name.endsWith(".monitor");
    }
    function name(node) { return node ? node.description || node.nickname || node.name : "Non disponibile"; }
    function writable() { return backend !== Pipewire || Quickshell.env("WORKSTATION_QUICKSHELL_TEST") !== "1"; }
    function select(node, output) {
        if (!ready || !writable() || (output ? outputs : inputs).indexOf(node) < 0) return;
        error = ""; requested = node; requestedSink = output;
        if (output) backend.preferredDefaultAudioSink = node;
        else backend.preferredDefaultAudioSource = node;
        selectionTimeout.restart();
    }
    function checkSelection() {
        if (requested && (requestedSink ? sink : source) === requested) {
            requested = null; selectionTimeout.stop();
        }
    }
    onSinkChanged: checkSelection()
    onSourceChanged: checkSelection()
    Timer {
        id: selectionTimeout; interval: 4000
        onTriggered: {
            if (!root.requested || (root.requestedSink ? root.sink : root.source) !== root.requested)
                root.error = "Selezione non applicata o dispositivo rimosso.";
            root.requested = null;
        }
    }
    function setVolume(value) { if (audio && writable()) audio.volume = Math.max(0, Math.min(1, value)); }
    function step(amount) { if (audio) setVolume(audio.volume + amount); }
    function mute() { if (audio && writable()) audio.muted = !audio.muted; }
    function setInputVolume(value) { if (inputAudio && writable()) inputAudio.volume = Math.max(0, Math.min(1, value)); }
    function muteInput() { if (inputAudio && writable()) inputAudio.muted = !inputAudio.muted; }
}
