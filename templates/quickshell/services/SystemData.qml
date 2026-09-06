import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id: root
    property var stats: ({cpu: null, ram: null, temperature: null})
    property var network: ({connected: false, state: "Non disponibile", interfaces: []})
    property var occupied: ({})
    property var fullscreen: ({})
    Process {
        id: statsProcess
        command: ["python3", Quickshell.shellPath("services/stats.py")]
        running: true
        stdout: SplitParser { onRead: line => { root.stats = JSON.parse(line); } }
        onExited: retryStats.restart()
    }
    Timer { id: retryStats; interval: 30000; onTriggered: statsProcess.running = true }
    Process {
        id: networkProcess
        command: ["/usr/bin/python3", Quickshell.shellPath("services/network.py")]
        running: true
        stdout: SplitParser { onRead: line => { root.network = JSON.parse(line); } }
        onExited: { root.network = {connected: false, state: "Non disponibile", interfaces: []}; retryNetwork.restart(); }
    }
    Timer { id: retryNetwork; interval: 30000; onTriggered: networkProcess.running = true }
    // The native workspace model does not expose window counts. This read-only
    // IPC subscriber supplements it on window events, without swaymsg polling.
    Process {
        id: occupancyProcess
        command: ["python3", Quickshell.shellPath("services/occupancy.py")]
        running: true
        stdout: SplitParser { onRead: line => { const state = JSON.parse(line); root.occupied = state.occupied; root.fullscreen = state.fullscreen; } }
        onExited: retryOccupancy.restart()
    }
    Timer { id: retryOccupancy; interval: 30000; onTriggered: occupancyProcess.running = true }
}
