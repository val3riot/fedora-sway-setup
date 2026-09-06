import QtQuick
import Quickshell.I3
import ".."
Row {
    id: root
    required property var output
    required property var occupied
    // Existing numerical workspaces belong only to their output. Unallocated
    // 1–10 slots appear on the focused output; selecting one creates it there.
    property var items: {
        const existing = I3.workspaces.values.filter(w => w.number >= 0);
        const local = existing.filter(w => w.monitor && w.monitor.name === output.name);
        const numbers = local.map(w => w.number);
        if (I3.focusedMonitor && I3.focusedMonitor.name === output.name)
            for (let n = 1; n <= 10; n++)
                if (!existing.some(w => w.number === n)) numbers.push(n);
        return numbers.sort((a, b) => a - b);
    }
    Repeater {
        model: root.items
        BarButton {
            required property int modelData
            property var workspace: I3.workspaces.values.find(w => w.number === modelData) || null
            text: String(modelData)
            textColor: workspace && workspace.urgent ? Theme.critical
                     : workspace && workspace.focused ? Theme.accent
                     : workspace && root.occupied[String(workspace.id)] ? Theme.foreground : Theme.secondary
            onClicked: { if (workspace) workspace.activate(); else I3.dispatch("workspace number " + modelData); }
        }
    }
}
