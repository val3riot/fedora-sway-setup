import QtQuick
import Quickshell
Scope {
    id: root
    required property var service
    property var notification: null
    property double receivedAt: Date.now()
    property bool toast: true
    property bool hovered: false
    property real remaining: 0
    property double deadline: 0
    function refresh(showToast = true) {
        if (!notification) return;
        receivedAt = Date.now(); toast = showToast;
        countdown.stop();
        remaining = service.timeoutFor(notification);
        resume();
    }
    function resume() {
        if (remaining > 0 && !hovered) { deadline = Date.now() + remaining; countdown.interval = Math.max(1, remaining); countdown.restart(); }
        service.remember(root);
    }
    onHoveredChanged: {
        if (hovered && countdown.running) { remaining = Math.max(1, deadline - Date.now()); countdown.stop(); service.remember(root); }
        else if (!hovered) resume();
    }
    Timer { id: countdown; onTriggered: { root.remaining = 0; root.service.timedOut(root); } }
    Connections {
        target: root.service.live ? root.notification : null
        function onClosed(reason) { countdown.stop(); root.service.remove(root); }
        function onSummaryChanged() { root.refresh(); }
        function onBodyChanged() { root.refresh(); }
        function onExpireTimeoutChanged() { root.refresh(); }
        function onUrgencyChanged() { root.refresh(); }
        function onActionsChanged() { root.refresh(); }
        function onImageChanged() { root.refresh(); }
    }
}
