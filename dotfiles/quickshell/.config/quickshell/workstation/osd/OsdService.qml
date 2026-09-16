import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id: root
    required property var audioService
    property bool shown: false
    property bool listening: false
    property string title: ""
    property real value: 0
    property bool valueKnown: true
    property bool muted: false
    function show(label, level, mute) {
        title = label; valueKnown = Number.isFinite(level); value = valueKnown ? Math.max(0, Math.min(1, level)) : 0; muted = mute;
        shown = true; expiry.restart();
    }
    function output() { if (audioService.audio) show("Volume", audioService.audio.volume, audioService.audio.muted); }
    function input() { if (audioService.inputAudio) show("Microfono", audioService.inputAudio.volume, audioService.inputAudio.muted); }
    Timer { interval: 500; running: true; onTriggered: root.listening = true }
    Timer { id: expiry; interval: 1600; onTriggered: root.shown = false }
    Connections {
        target: root.audioService.audio
        function onVolumeChanged() { if (root.listening) root.output(); }
        function onMutedChanged() { if (root.listening) root.output(); }
    }
    Connections {
        target: root.audioService.inputAudio
        function onVolumeChanged() { if (root.listening) root.input(); }
        function onMutedChanged() { if (root.listening) root.input(); }
    }
    function action(name) {
        if (name === "volume-up") audioService.step(.05);
        else if (name === "volume-down") audioService.step(-.05);
        else if (name === "mute") audioService.mute();
        else if (name === "mic-mute") audioService.muteInput();
        else if (name === "mic-up" && audioService.inputAudio) audioService.setInputVolume(audioService.inputAudio.volume + .05);
        else if (name === "mic-down" && audioService.inputAudio) audioService.setInputVolume(audioService.inputAudio.volume - .05);
        else if (name === "brightness-up" || name === "brightness-down") {
            if (Quickshell.env("WORKSTATION_QUICKSHELL_TEST") !== "1" && !brightness.running) {
                brightness.command = ["/usr/bin/python3", Quickshell.shellPath("osd/brightness.py"), name];
                brightness.running = true;
            }
            return;
        } else return;
        if (name.indexOf("mic-") === 0) input(); else output();
    }
    Process {
        id: brightness
        stdout: SplitParser { onRead: line => {
            const result = JSON.parse(line);
            root.show(result.ok ? "Luminosità" : "Luminosità non disponibile", result.ok ? result.value : NaN, false);
        } }
    }
}
