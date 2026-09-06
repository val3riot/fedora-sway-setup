import QtQuick
import QtQuick.Controls
import Quickshell
import ".."
BarPopup {
    id: root
    property bool testMode: Quickshell.env("WORKSTATION_QUICKSHELL_TEST") === "1"
    Text { text: "Scegli un’azione"; color: Theme.foreground }
    Repeater {
        model: ["Lock", "Logout", "Suspend", "Reboot", "Shutdown"]
        ActionButton {
            required property string modelData
            text: modelData; width: parent.width
            onClicked: {
                root.closeRequested();
                if (!root.testMode)
                    Quickshell.execDetached(["bash", Quickshell.shellPath("services/power.sh"), modelData]);
            }
        }
    }
    ActionButton { text: "Annulla"; onClicked: root.closeRequested() }
}
