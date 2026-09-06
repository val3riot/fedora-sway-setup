import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "services" as Services
ShellRoot {
    id: root
    property int checks: 0
    property int phase: 0
    property var first: null
    property var ephemeral: null
    property var critical: null
    property var resident: null
    property var timed: null
    function check(value, name) { checks++; if (!value) { console.error("TEST FAILED " + name); Qt.exit(1); } }
    Services.Notifications { id: service; live: false }
    function make(values) {
        const n = Object.assign({id: 0, tracked: false, lastGeneration: false,
            resident: false, transient: false, summary: "Test", body: "Body",
            appName: "Test app", appIcon: "", image: "", urgency: 1,
            expireTimeout: -1, actions: [], closeReason: 0}, values);
        n.expire = function() { n.closeReason = 1; service.remove(service.entries.find(e => e.notification.id === n.id)); };
        n.dismiss = function() { n.closeReason = 2; service.remove(service.entries.find(e => e.notification.id === n.id)); };
        return n;
    }
    QtObject { id: action; property int calls: 0; function invoke() { calls++; } }
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: {
            phase++;
            if (phase === 1) {
                first = make({id: 1, actions: [action]});
                ephemeral = make({id: 2, transient: true});
                critical = make({id: 3, urgency: NotificationUrgency.Critical});
                resident = make({id: 4, resident: true});
                for (const n of [first, ephemeral, critical, resident]) service.receive(n);
                check(first.tracked && service.entries.length === 4, "tracking");
                check(service.count === 3, "count excludes transient");
                check(service.timeoutFor(critical) === 0, "critical no expiry");
                check(service.timeoutFor(first) === 7000, "normal default timeout");
                check(service.timeoutFor({urgency: 0, expireTimeout: -1}) === 4000, "low timeout");
                check(service.timeoutFor({urgency: 1, expireTimeout: 0}) === 0, "explicit no expiry");
                const entry = service.entries.find(e => e.notification.id === first.id);
                service.invoke(entry, action); check(action.calls === 1, "native action invoked");
                service.invoke(entry, null); check(action.calls === 1, "invalid action ignored");
                for (let i = 5; i < 10; i++) service.receive(make({id: i}));
                check(service.toasts.length === 4, "max four toasts");
                service.timedOut(entry);
                check(service.entries.indexOf(entry) >= 0 && !entry.toast, "default remains in center");
                const eTransient = service.entries.find(e => e.notification.id === ephemeral.id);
                service.timedOut(eTransient); check(ephemeral.closeReason === 1, "transient expires");
                timed = make({id: 10, expireTimeout: 50});
                service.receive(timed);
            } else if (phase === 2) {
                check(timed.closeReason === 1, "actual timer expiry");
                service.clear();
                check(service.count === 2, "clear preserves critical and resident");
                check(first.closeReason === 2, "dismiss reason");
                const entry = service.entries.find(e => e.notification.id === critical.id);
                service.dismiss(entry); check(critical.closeReason === 2, "critical explicit dismiss");
                const residentEntry = service.entries.find(e => e.notification.id === resident.id);
                resident.summary = "Replacement";
                service.receive(residentEntry.notification); check(service.count === 1, "replacement no duplicate");
                service.dismiss(residentEntry); check(service.count === 0, "empty count");
                timed = make({id: 11, expireTimeout: 50}); service.receive(timed);
                service.entries[0].hovered = true;
            } else if (phase === 3) {
                check(timed.closeReason === 0, "hover pauses countdown");
                service.entries[0].hovered = false;
            } else if (phase === 4) {
                check(timed.closeReason === 1, "hover exit resumes");
                check(service.imageSource("https:" + "/" + "/example.test/image") === "", "remote images rejected");
                console.warn("TEST notifications OK " + checks + " checks"); Qt.quit();
            }
        }
    }
}
