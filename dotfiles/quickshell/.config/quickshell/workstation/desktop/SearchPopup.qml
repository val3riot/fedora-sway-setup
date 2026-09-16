import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import ".."
import "../popups"
PanelWindow {
    id: root
    property string heading: ""
    property string query: ""
    property var rows: []
    property bool clearAvailable: false
    signal selected(var row)
    signal clearRequested()
    signal closeRequested()
    readonly property int selectedIndex: list.currentIndex
    property int preferredIndex: 0
    screen: Quickshell.screens.find(s => I3.focusedWorkspace && I3.focusedWorkspace.monitor && s.name === I3.focusedWorkspace.monitor.name) || Quickshell.screens[0] || null
    implicitWidth: screen ? Math.min(540, screen.width - 40) : 540
    implicitHeight: screen ? Math.min(440, screen.height - 80) : 440
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "workstation-search"
    color: Theme.surface
    onVisibleChanged: if (visible) { query = ""; search.text = ""; search.forceActiveFocus(); }
    // DesktopEntries can rebuild in several signals. Preserve keyboard position
    // across model refreshes, but restart at the first result for a new query.
    onQueryChanged: preferredIndex = 0
    onRowsChanged: Qt.callLater(function() { list.currentIndex = rows.length ? Math.min(preferredIndex, rows.length - 1) : -1; })
    function choose() { if (list.currentIndex >= 0 && list.currentIndex < rows.length) selected(rows[list.currentIndex]); }
    function move(delta) {
        if (!rows.length) return;
        preferredIndex = Math.max(0, Math.min(rows.length - 1, list.currentIndex + delta));
        list.currentIndex = preferredIndex;
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    Rectangle { anchors.fill: parent; color: "transparent"; border.color: Theme.accent; border.width: 1 }
    Column {
        x: 16; y: 14; width: parent.width - 32; spacing: 10
        Row {
            width: parent.width
            Text { width: parent.width - (clearButton.visible ? clearButton.width : 0); text: root.heading; color: Theme.secondary }
            ActionButton { id: clearButton; visible: root.clearAvailable; text: "Pulisci"; onClicked: root.clearRequested() }
        }
        TextField {
            id: search; width: parent.width; placeholderText: "Cerca…"; focus: true
            color: Theme.foreground; selectionColor: Theme.accent; selectedTextColor: Theme.background
            background: Rectangle { color: Theme.background; border.color: search.activeFocus ? Theme.accent : Theme.secondary }
            onTextChanged: root.query = text
            Keys.onEscapePressed: root.closeRequested()
            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            Keys.onReturnPressed: root.choose()
            Keys.onEnterPressed: root.choose()
        }
        ListView {
            id: list; width: parent.width; height: root.height - y - 36; clip: true
            model: root.rows; spacing: 2; currentIndex: 0; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width; height: 38
                color: ListView.isCurrentItem ? "#303030" : Theme.surface
                Rectangle { width: 2; height: parent.height; color: Theme.accent; visible: parent.ListView.isCurrentItem }
                Image {
                    id: icon; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22
                    source: modelData.icon && Quickshell.hasThemeIcon(modelData.icon) ? Quickshell.iconPath(modelData.icon) : ""
                    visible: source.toString() !== "" && status === Image.Ready
                }
                Text { x: icon.visible ? 42 : 12; width: parent.width - x - 10; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: Theme.foreground }
                MouseArea { anchors.fill: parent; onClicked: { list.currentIndex = index; root.selected(modelData); } }
            }
        }
    }
    Text { anchors.centerIn: parent; visible: !root.rows.length; text: "Nessun risultato"; color: Theme.secondary }
}
