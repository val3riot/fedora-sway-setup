"""Use installed Fedora Blueman for authentication and the explicit manager fallback."""
import os
import shutil
import subprocess
import sys
import time
from gi.repository import Gio, GLib


def theme_environment():
    env = dict(os.environ)
    source = Gio.SettingsSchemaSource.get_default()
    schema = source.lookup('org.gnome.desktop.interface', True) if source else None
    if schema:
        settings = Gio.Settings.new_full(schema, None, None)
        theme = settings.get_string('gtk-theme')
        if theme:
            if schema.has_key('color-scheme') and settings.get_string('color-scheme') == 'prefer-dark' and 'dark' not in theme.lower():
                theme += ':dark'
            env['GTK_THEME'] = theme
    return env


def ensure_agent():
    if not shutil.which('blueman-applet'):
        return 1
    session = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    system = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    def call(bus, name, path, interface, method, parameters=None):
        return bus.call_sync(name, path, interface, method, parameters, None,
                             Gio.DBusCallFlags.NONE, 3000, None).unpack()
    def dbus(bus, method, parameters=None):
        return call(bus, 'org.freedesktop.DBus', '/org/freedesktop/DBus',
                    'org.freedesktop.DBus', method, parameters)
    # Official D-Bus activation is singleton and does not open the manager.
    dbus(session, 'StartServiceByName', GLib.Variant('(su)', ('org.blueman.Applet', 0)))
    pid = dbus(session, 'GetConnectionUnixProcessID', GLib.Variant('(s)', ('org.blueman.Applet',)))[0]
    # Bounded startup readiness only, on the user's Pair click; no background polling.
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline:
        try:
            plugins = call(session, 'org.blueman.Applet', '/org/blueman/Applet',
                           'org.blueman.Applet', 'QueryPlugins')[0]
            if 'AuthAgent' not in plugins:
                return 1  # Respect an intentionally disabled authentication plugin.
            for name in dbus(system, 'ListNames')[0]:
                if not name.startswith(':'):
                    continue
                try:
                    if dbus(system, 'GetConnectionUnixProcessID', GLib.Variant('(s)', (name,)))[0] != pid:
                        continue
                    xml = call(system, name, '/org/bluez/agent/blueman',
                               'org.freedesktop.DBus.Introspectable', 'Introspect')[0]
                    if 'org.bluez.Agent1' in xml:
                        return 0
                except GLib.Error:
                    continue
        except GLib.Error:
            pass
        time.sleep(0.05)
    return 1


def main():
    if os.environ.get('WORKSTATION_QUICKSHELL_TEST') == '1':
        return 0
    if sys.argv[1:] == ['ensure-agent']:
        return ensure_agent()
    if sys.argv[1:] != ['bluetooth']:
        return 2
    for command in (['blueman-manager'], ['gnome-control-center', 'bluetooth']):
        executable = shutil.which(command[0])
        if executable:
            return subprocess.call([executable, *command[1:]], env=theme_environment(),
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (GLib.Error, OSError):
        # Never print D-Bus payloads, PINs or passkeys.
        raise SystemExit(1)
