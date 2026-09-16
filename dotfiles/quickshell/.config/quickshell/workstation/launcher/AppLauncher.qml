import QtQuick
import Quickshell
import Quickshell.Io
import "../desktop"
import "../desktop/Search.js" as Search
SearchPopup {
    id: root
    heading: "Applicazioni"
    property var validIds: []
    Process {
        id: catalog
        command: ["/usr/bin/python3", Quickshell.shellPath("launcher/catalog.py")]
        running: true
        stdout: SplitParser { onRead: line => {
            const ids = JSON.parse(line).ids;
            if (JSON.stringify(ids) !== JSON.stringify(root.validIds)) root.validIds = ids;
        } }
    }
    Connections { target: DesktopEntries; function onApplicationsChanged() { refresh.restart(); } }
    Timer { id: refresh; interval: 200; onTriggered: if (!catalog.running) catalog.running = true }

    readonly property var applications: DesktopEntries.applications.values
        .filter(app => app && !app.noDisplay && app.name && app.command.length > 0 && root.validIds.indexOf(app.id.replace(/\.desktop$/, "")) >= 0)
        .map(app => ({name: app.name, icon: app.icon, entry: app}))
        .sort((a,b) => a.name.localeCompare(b.name))
    rows: Search.rank(applications, query)
    onSelected: row => {
        if (row.entry && applications.some(app => app.entry === row.entry)) {
            if (Quickshell.env("WORKSTATION_QUICKSHELL_TEST") !== "1") row.entry.execute();
            root.closeRequested();
        }
    }
}
