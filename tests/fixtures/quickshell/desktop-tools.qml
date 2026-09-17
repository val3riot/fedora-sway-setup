import QtQuick
import Quickshell
import Quickshell.Io
import "osd"
import "launcher"
import "clipboard"
import "desktop/Search.js" as Search
ShellRoot {
    id: root
    property bool appsOpen: false
    property bool clipsOpen: false
    QtObject { id: output; property real volume: .4; property bool muted: false }
    QtObject { id: input; property real volume: .6; property bool muted: false }
    QtObject {
        id: audio
        property var audio: output
        property var inputAudio: input
        function step(n) { output.volume = Math.max(0, Math.min(1, output.volume + n)); }
        function mute() { output.muted = !output.muted; }
        function muteInput() { input.muted = !input.muted; }
        function setInputVolume(n) { input.volume = n; }
    }
    OsdService { id: osd; audioService: audio }
    Osd { service: osd }
    ClipboardService { id: clips; opened: root.clipsOpen }
    Loader { id: apps; active: root.appsOpen; sourceComponent: AppLauncher { visible: true; onCloseRequested: root.appsOpen = false } }
    Loader { id: picker; active: root.clipsOpen; sourceComponent: ClipboardPopup { visible: true; service: clips; onCloseRequested: root.clipsOpen = false } }
    IpcHandler {
        target: "toolsTest"
        function action(name: string): void { osd.action(name); }
        function openApps(): void { root.clipsOpen = false; root.appsOpen = true; }
        function openClips(): void { root.appsOpen = false; root.clipsOpen = true; }
        function query(text: string): void { if (apps.item) apps.item.query = text; if (picker.item) picker.item.query = text; }
        function move(amount: int): void { if (apps.item) apps.item.move(amount); if (picker.item) picker.item.move(amount); }
        function choose(): void { if (apps.item) apps.item.choose(); if (picker.item) picker.item.choose(); }
        function clear(): void { clips.clear(); }
        function close(): void { root.appsOpen = false; root.clipsOpen = false; }
        function state(): string { return JSON.stringify({shown: osd.shown, title: osd.title, value: osd.value, muted: osd.muted,
            apps: apps.item ? apps.item.rows.map(r => r.name) : [], index: apps.item ? apps.item.selectedIndex : -1,
            clipCount: clips.rows.length, clipNames: clips.rows.map(r => r.name), appsOpen: root.appsOpen, clipsOpen: root.clipsOpen,
            rank: Search.rank([{name:"Firefox"},{name:"Files"},{name:"Terminal"}], "ffx").map(r=>r.name)}); }
    }
}
