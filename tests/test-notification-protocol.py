#!/usr/bin/env python3
"""Native protocol tests on a PRIVATE session bus; never notify the user's session."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import gi
from gi.repository import Gio, GLib
ROOT = Path(__file__).resolve().parents[1]


def main():
    if os.environ.get('WORKSTATION_PRIVATE_NOTIFICATION_TEST') != '1':
        return subprocess.call(['dbus-run-session', '--', 'env', 'WORKSTATION_PRIVATE_NOTIFICATION_TEST=1',
                                '/usr/bin/python3', __file__])
    with tempfile.TemporaryDirectory(prefix='notification-protocol-') as tmp:
        config = Path(tmp) / 'config'
        qs_src = ROOT / 'dotfiles/quickshell/.config/quickshell/workstation'
        if not qs_src.exists():
            qs_src = ROOT / 'templates/quickshell'
        shutil.copytree(qs_src, config)
        shutil.copyfile(ROOT / 'tests/fixtures/quickshell/notification-server.qml', config / 'shell.qml')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', WORKSTATION_QUICKSHELL_TEST='1',
                   WORKSTATION_NOTIFICATION_TEST_BUS='1', WORKSTATION_NOTIFICATIONS='quickshell')
        env.pop('WAYLAND_DISPLAY', None)
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        events = []
        bus.signal_subscribe(None, 'org.freedesktop.Notifications', None, '/org/freedesktop/Notifications',
                             None, Gio.DBusSignalFlags.NONE,
                             lambda b, sender, path, iface, name, params: events.append((name, params.unpack())))
        def drain():
            deadline = time.monotonic() + .12
            while time.monotonic() < deadline:
                while GLib.MainContext.default().iteration(False):
                    pass
                time.sleep(.01)
        with (Path(tmp) / 'log').open('w') as log:
            qs = subprocess.Popen(['quickshell', '--no-color', '--path', str(config)], env=env, stdout=log, stderr=log)
            try:
                for _ in range(60):
                    owned = bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                        'NameHasOwner', GLib.Variant('(s)', ('org.freedesktop.Notifications',)), None, Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]
                    if owned:
                        break
                    time.sleep(.1)
                assert owned, 'native server did not acquire bus'
                def call(method, params=None):
                    return bus.call_sync('org.freedesktop.Notifications', '/org/freedesktop/Notifications',
                        'org.freedesktop.Notifications', method, params, None, Gio.DBusCallFlags.NONE, 2000, None).unpack()
                def notify(title, timeout=-1, hints=None, replace=0, actions=None):
                    result = call('Notify', GLib.Variant('(susssasa{sv}i)', ('Workstation test', replace,
                        'dialog-information', title, '<b>Plain body</b>', actions or [], hints or {}, timeout)))[0]
                    drain()
                    return result
                def ipc(method, *args):
                    return subprocess.check_output(['quickshell', 'ipc', '--pid', str(qs.pid), 'call',
                        'notificationTest', method, *map(str, args)], env=env, text=True).strip()
                def state():
                    raw = ipc('state')
                    assert raw.startswith('{'), repr(raw)
                    return json.loads(raw)
                caps = call('GetCapabilities')[0]
                assert 'actions' in caps and 'body-markup' in caps
                normal = notify('Normal', actions=['default', 'Open'])
                assert state()['count'] == 1
                assert notify('Replacement', replace=normal) == normal
                assert state()['count'] == 1 and state()['entries'][0]['summary'] == 'Replacement'
                notify('Action', replace=normal, actions=['default', 'Open'])
                ipc('action', normal); drain()
                assert ('ActionInvoked', (normal, 'default')) in events
                assert state()['count'] == 0
                resident = notify('Resident', hints={'resident': GLib.Variant('b', True)}, actions=['default', 'Open'])
                ipc('action', resident); drain(); assert state()['count'] == 1
                transient = notify('Transient', timeout=120, hints={'transient': GLib.Variant('b', True)})
                time.sleep(.2); drain()
                assert ('NotificationClosed', (transient, 1)) in events, (events, state())
                critical = notify('Critical', timeout=120, hints={'urgency': GLib.Variant('y', 2)})
                time.sleep(.2); assert state()['count'] == 2
                # Native hot reload must retain ids/count without replaying old toasts.
                shell = config / 'shell.qml'
                shell.write_text(shell.read_text() + '\n// reload test\n')
                time.sleep(3)
                assert state()['count'] == 2, ('reload persistence', state())
                assert state()['toasts'] == 0, ('reload no replay', state())
                ids = [notify('Stack ' + str(i)) for i in range(6)]
                assert state()['toasts'] == 4 and state()['count'] == 8
                ipc('clear'); drain(); assert state()['count'] == 2
                assert ('NotificationClosed', (ids[0], 2)) in events
                ipc('dismiss', critical); drain(); assert state()['count'] == 1
                call('CloseNotification', GLib.Variant('(u)', (resident,))); drain()
                assert ('NotificationClosed', (resident, 3)) in events and state()['count'] == 0
                # Exercise the standard client too; no notification survives this bus.
                subprocess.run(['notify-send', '-t', '400', '-u', 'low', '-i', 'dialog-information', 'Client test', 'Body'], check=True)
                time.sleep(.6); assert state()['count'] == 0, state()
                collision = Path(tmp) / 'collision'
                shutil.copytree(config, collision)
                with (Path(tmp) / 'collision.log').open('w') as collision_log:
                    other = subprocess.Popen(['quickshell', '--no-color', '--path', str(collision)], env=env,
                                             stdout=collision_log, stderr=collision_log)
                    try:
                        time.sleep(.8)
                        owner_pid = bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                            'org.freedesktop.DBus', 'GetConnectionUnixProcessID',
                            GLib.Variant('(s)', ('org.freedesktop.Notifications',)), None,
                            Gio.DBusCallFlags.NONE, 1000, None).unpack()[0]
                        assert owner_pid == qs.pid, 'collision must never replace owner'
                    finally:
                        other.terminate(); other.wait(timeout=5)
                assert 'Conflitto notifiche:' in (Path(tmp) / 'collision.log').read_text()
                print('OK native notifications: ownership, capabilities, replacement, actions, resident, transient, critical, stack, clear, close reasons, notify-send')
            finally:
                qs.terminate(); qs.wait(timeout=5)
                print((Path(tmp) / "log").read_text())
        output = (Path(tmp) / 'log').read_text()
        assert not any(x in output for x in ('ERROR', 'WARN scene', 'TypeError', 'ReferenceError', 'Binding loop')), output
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
