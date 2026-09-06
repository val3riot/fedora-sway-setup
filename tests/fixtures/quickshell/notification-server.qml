import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
import "notifications"
ShellRoot {
    Connections { target: Quickshell; function onReloadCompleted() { Quickshell.inhibitReloadPopup(); } }
    Services.Notifications { id: notices }
    // This IPC exists only in the isolated protocol-test fixture.
    IpcHandler {
        target: "notificationTest"
        function state(): string { return JSON.stringify({iconExists: Quickshell.hasThemeIcon("dialog-information"), count: notices.count, toasts: notices.toasts.length,
            entries: notices.entries.map(e => ({id: e.notification.id, summary: e.notification.summary, image: e.notification.image, appIcon: e.notification.appIcon,
                hovered: e.hovered, remaining: e.remaining, transient: e.notification.transient, timeout: e.notification.expireTimeout}))}); }
        function dismiss(id: int): void { const e = notices.entries.find(e => e.notification.id === id); if (e) notices.dismiss(e); }
        function action(id: int): void { const e = notices.entries.find(e => e.notification.id === id); if (e) notices.invoke(e, e.notification.actions[0]); }
        function clear(): void { notices.clear(); }
    }
    // Instantiate the real visual delegates without touching the user's compositor.
    FloatingWindow {
        visible: true; implicitWidth: 380; implicitHeight: 720
        Column { x: 40; y: 40; width: parent.width - 40; Repeater { model: notices.toasts
            NotificationItem { required property var modelData; entry: modelData; service: notices; compact: true }
        } }
    }
}
