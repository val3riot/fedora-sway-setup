import QtQuick
import QtQuick.Controls
import ".."
BarPopup {
    id: root
    required property date today
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    onVisibleChanged: if (visible) month = new Date(today.getFullYear(), today.getMonth(), 1)
    Row {
        spacing: 10
        ActionButton { text: "‹"; onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() - 1, 1) }
        Text { anchors.verticalCenter: parent.verticalCenter; text: root.month.toLocaleDateString(Qt.locale("it_IT"), "MMMM yyyy"); color: Theme.foreground }
        ActionButton { text: "›"; onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() + 1, 1) }
    }
    Grid {
        columns: 7
        Repeater {
            model: ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]
            Text { required property string modelData; width: 42; height: 28; horizontalAlignment: Text.AlignHCenter; text: modelData; color: Theme.secondary }
        }
        Repeater {
            model: 42
            Rectangle {
                required property int index
                property int day: index - ((root.month.getDay() + 6) % 7) + 1
                property bool valid: day > 0 && day <= new Date(root.month.getFullYear(), root.month.getMonth() + 1, 0).getDate()
                property bool current: valid && day === root.today.getDate() && root.month.getMonth() === root.today.getMonth() && root.month.getFullYear() === root.today.getFullYear()
                width: 42; height: 30; color: current ? Theme.accent : "transparent"
                Text { anchors.centerIn: parent; text: parent.valid ? parent.day : ""; color: parent.current ? Theme.background : Theme.foreground }
            }
        }
    }
    ActionButton { text: "Chiudi"; onClicked: root.closeRequested() }
}
