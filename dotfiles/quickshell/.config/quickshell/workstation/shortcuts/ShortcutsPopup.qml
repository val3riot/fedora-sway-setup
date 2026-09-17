import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.I3
import Quickshell.Wayland
import ".."
import "../popups"
import "../desktop/Search.js" as Search
import "ShortcutsData.js" as ShortcutsData

PanelWindow {
    id: root
    signal closeRequested()
    property string query: ""

    screen: Quickshell.screens.find(s => I3.focusedWorkspace && I3.focusedWorkspace.monitor && s.name === I3.focusedWorkspace.monitor.name) || Quickshell.screens[0] || null
    implicitWidth: screen ? Math.min(640, screen.width - 40) : 640
    implicitHeight: screen ? Math.min(520, screen.height - 80) : 520
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "workstation-shortcuts"
    color: Theme.surface

    onVisibleChanged: if (visible) { query = ""; search.text = ""; search.forceActiveFocus(); }

    readonly property var allShortcuts: ShortcutsData.allItems()
    readonly property var filteredItems: query.trim() !== "" ? Search.rank(allShortcuts, query) : allShortcuts

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Theme.accent
        border.width: 1
    }

    Column {
        x: 18; y: 16
        width: parent.width - 36
        height: parent.height - 32
        spacing: 12

        Row {
            width: parent.width
            Text {
                width: parent.width - closeBtn.width
                text: "Scorciatoie da tastiera Sway"
                font.pixelSize: 15
                font.bold: true
                color: Theme.foreground
            }
            ActionButton {
                id: closeBtn
                text: "Chiudi (Esc)"
                onClicked: root.closeRequested()
            }
        }

        TextField {
            id: search
            width: parent.width
            placeholderText: "Cerca scorciatoia o comando…"
            focus: true
            color: Theme.foreground
            selectionColor: Theme.accent
            selectedTextColor: Theme.background
            background: Rectangle {
                color: Theme.background
                border.color: search.activeFocus ? Theme.accent : Theme.secondary
                border.width: 1
                radius: 4
            }
            onTextChanged: root.query = text
            Keys.onEscapePressed: root.closeRequested()
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - y - 8
            clip: true
            model: root.filteredItems
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width
                height: 44
                color: index % 2 === 0 ? Theme.background : "#181818"
                radius: 4

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(160, keyText.implicitWidth + 16)
                        height: 28
                        color: "#242424"
                        radius: 4
                        border.color: Theme.accent
                        border.width: 1

                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: modelData.keys
                            font.family: "monospace"
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.accent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - keyText.parent.width - 16
                        spacing: 2

                        Text {
                            width: parent.width
                            text: modelData.desc
                            font.pixelSize: 13
                            color: Theme.foreground
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: modelData.category
                            font.pixelSize: 10
                            color: Theme.secondary
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.filteredItems.length === 0
        text: "Nessuna scorciatoia trovata"
        color: Theme.secondary
        font.pixelSize: 14
    }
}
