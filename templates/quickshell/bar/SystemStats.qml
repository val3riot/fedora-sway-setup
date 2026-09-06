import QtQuick
import ".."
Row {
    required property var stats
    BarButton { text: "CPU " + (stats.cpu === null ? "—" : stats.cpu + "%"); textColor: stats.cpu >= 90 ? Theme.warning : Theme.foreground }
    BarButton { text: "RAM " + (stats.ram === null ? "—" : stats.ram + "%"); textColor: stats.ram >= 90 ? Theme.warning : Theme.foreground }
    BarButton { visible: stats.temperature !== null; text: stats.temperature + "°C"; textColor: stats.temperature >= 90 ? Theme.critical : stats.temperature >= 80 ? Theme.warning : Theme.foreground }
}
