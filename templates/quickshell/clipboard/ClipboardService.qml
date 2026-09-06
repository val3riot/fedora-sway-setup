import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id: root
    property bool opened: false
    property string query: ""
    property string error: ""
    property var rows: []
    function send(command) { if (store.running) store.write(JSON.stringify(command) + "\n"); }
    function refresh() { if (opened) send({op: "list", query: query}); }
    function copy(id) { send({op: "copy", id: id}); }
    function clear() { send({op: "clear"}); }
    onQueryChanged: refresh()
    onOpenedChanged: { if (opened) { query = ""; refresh(); } else rows = []; }
    Process {
        id: store; stdinEnabled: true
        running: Quickshell.env("WORKSTATION_QUICKSHELL_TEST") !== "1"
        command: ["/usr/bin/python3", Quickshell.shellPath("clipboard/store.py")]
        stdout: SplitParser { onRead: line => {
            const data = JSON.parse(line);
            if (data.error) root.error = data.error;
            if (data.changed) root.refresh();
            if (data.rows && root.opened && data.query === root.query) root.rows = data.rows;
        } }
        onExited: { root.error = "Cronologia non disponibile; riavviare la shell."; root.rows = []; }
    }
}
