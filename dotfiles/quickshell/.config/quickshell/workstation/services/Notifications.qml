import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../notifications"
Scope {
    id: root
    // One service in ShellRoot. Headless doctor/mocks never claim the real bus.
    property bool enabled: Quickshell.env("WORKSTATION_NOTIFICATIONS") !== "mako"
    property bool live: Quickshell.env("WORKSTATION_QUICKSHELL_TEST") !== "1"
                        || Quickshell.env("WORKSTATION_NOTIFICATION_TEST_BUS") === "1"
    property var busState: ({known: false, pid: 0, ours: false})
    property string error: ""
    readonly property bool registered: enabled && busState.ours === true
    property var entries: []
    readonly property var centerEntries: entries.filter(e => e.notification && !e.notification.transient)
    readonly property int count: centerEntries.length
    readonly property var toasts: entries.filter(e => e.notification && e.toast).slice(0, 4)
    readonly property bool canClear: centerEntries.some(e => !e.notification.resident && e.notification.urgency !== NotificationUrgency.Critical)
    Process {
        command: ["/usr/bin/python3", Quickshell.shellPath("services/notification-bus.py")]
        running: root.enabled && root.live
        stdout: SplitParser {
            onRead: line => {
                root.busState = JSON.parse(line);
                root.error = !root.busState.known ? "Bus notifiche non verificabile" : root.busState.pid && !root.busState.ours
                    ? "Conflitto notifiche: " + root.busState.executable : "";
                if (root.error) console.error(root.error);
            }
        }
        onExited: (code, status) => { if (root.enabled && root.live) root.error = "Monitor D-Bus notifiche terminato"; }
    }
    Loader {
        // Construct during reload so the native server can transfer tracked notifications.
        // Registration never replaces another owner; the signal monitor reports collisions.
        active: root.enabled && root.live
        sourceComponent: Component {
            NotificationServer {
                keepOnReload: true
                persistenceSupported: true
                bodySupported: true
                bodyMarkupSupported: true
                bodyHyperlinksSupported: false
                bodyImagesSupported: false
                imageSupported: true
                actionsSupported: true
                actionIconsSupported: false
                inlineReplySupported: false
                onNotification: notification => root.receive(notification)
            }
        }
    }
    PersistentProperties { id: memory; reloadableId: "workstation-notifications"; property string records: "{}" }
    Component { id: entryComponent; NotificationEntry { service: root } }
    function receive(notification) {
        notification.tracked = true;
        const existing = entries.find(e => e.notification === notification);
        if (existing) { existing.refresh(); return; }
        const entry = entryComponent.createObject(root, {notification: notification});
        entries = [entry].concat(entries);
        const saved = JSON.parse(memory.records)[notification.id];
        if (notification.lastGeneration && saved) {
            entry.receivedAt = saved.time; entry.toast = false;
            entry.remaining = saved.deadline > 0 ? Math.max(1, saved.deadline - Date.now()) : saved.remaining;
            entry.resume();
        } else entry.refresh(!notification.lastGeneration);
    }
    function remember(entry) {
        if (!entry.notification) return;
        const copy = JSON.parse(memory.records);
        copy[entry.notification.id] = {time: entry.receivedAt, remaining: entry.remaining,
            deadline: entry.remaining > 0 && !entry.hovered ? entry.deadline : 0};
        memory.records = JSON.stringify(copy);
    }
    function remove(entry) {
        if (entry.notification) {
            const copy = JSON.parse(memory.records); delete copy[entry.notification.id]; memory.records = JSON.stringify(copy);
        }
        entries = entries.filter(e => e !== entry);
        entry.notification = null;
        entry.destroy();
    }
    function timeoutFor(notification) {
        if (notification.urgency === NotificationUrgency.Critical || notification.expireTimeout === 0) return 0;
        if (notification.expireTimeout > 0) return notification.expireTimeout; // Installed Fedora 0.2.1 returns protocol milliseconds (native test).
        return notification.urgency === NotificationUrgency.Low ? 4000 : 7000;
    }
    function timedOut(entry) {
        if (!entry.notification) return;
        entry.toast = false;
        remember(entry);
        // Default persistence stays in the center; explicit application expiry closes.
        if (entry.notification.transient || entry.notification.expireTimeout > 0) entry.notification.expire();
    }
    function dismiss(entry) { if (entries.indexOf(entry) >= 0 && entry.notification) entry.notification.dismiss(); }
    function invoke(entry, action) {
        if (entries.indexOf(entry) >= 0 && entry.notification && entry.notification.actions.indexOf(action) >= 0) action.invoke();
    }
    function clear() {
        centerEntries.slice().forEach(e => {
            if (e.notification && !e.notification.resident && e.notification.urgency !== NotificationUrgency.Critical) dismiss(e);
        });
    }
    function imageSource(value) {
        if (!value) return "";
        // Native image-path hints may become icon URLs even when the theme lacks the icon.
        if (value.startsWith("image://icon/")) value = value.substring(13);
        if (value.startsWith("/") || value.startsWith("file://") || value.startsWith("image://")) return value;
        if (Quickshell.hasThemeIcon(value)) return Quickshell.iconPath(value);
        return Quickshell.hasThemeIcon(value + "-symbolic") ? Quickshell.iconPath(value + "-symbolic") : "";
    }
}
