"""Observe notification bus ownership using signals, without activating a daemon."""
import json
import os
from pathlib import Path
import sys
from gi.repository import Gio, GLib

NAME = 'org.freedesktop.Notifications'


def owner(bus):
    def call(method, parameters, result):
        return bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                             'org.freedesktop.DBus', method, parameters,
                             GLib.VariantType(result), Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]
    if not call('NameHasOwner', GLib.Variant('(s)', (NAME,)), '(b)'):
        return dict(known=True, pid=0, executable='', ours=False)
    try:
        unique = call('GetNameOwner', GLib.Variant('(s)', (NAME,)), '(s)')
        pid = call('GetConnectionUnixProcessID', GLib.Variant('(s)', (unique,)), '(u)')
        executable = str(Path('/proc', str(pid), 'exe').resolve())
        return dict(known=True, pid=pid, executable=executable, ours=pid == os.getppid())
    except (GLib.Error, OSError):
        return dict(known=False, pid=0, executable='', ours=False)


def main():
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    previous = None
    def publish(*_):
        nonlocal previous
        state = json.dumps(owner(bus))
        if state != previous:
            print(state, flush=True)
            previous = state
    bus.signal_subscribe('org.freedesktop.DBus', 'org.freedesktop.DBus',
                         'NameOwnerChanged', '/org/freedesktop/DBus', NAME,
                         Gio.DBusSignalFlags.NONE, publish)
    publish()
    if '--once' not in sys.argv:
        GLib.MainLoop().run()


if __name__ == '__main__':
    try:
        main()
    except (GLib.Error, BrokenPipeError):
        raise SystemExit(1)
