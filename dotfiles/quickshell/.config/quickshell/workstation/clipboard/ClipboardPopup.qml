import QtQuick
import "../desktop"
SearchPopup {
    id: root
    required property var service
    heading: service.error || "Clipboard · solo questa sessione"
    clearAvailable: true
    rows: service.rows
    onQueryChanged: service.query = query
    onClearRequested: service.clear()
    onSelected: row => { service.copy(row.id); root.closeRequested(); }
}
