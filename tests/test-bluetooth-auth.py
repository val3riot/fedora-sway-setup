import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch, MagicMock
from gi.repository import Gio, GLib
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('desktop', ROOT / 'templates/quickshell/services/desktop-settings.py')
desktop = importlib.util.module_from_spec(spec); spec.loader.exec_module(desktop)


class Authentication(unittest.TestCase):
    def test_official_agent_activation_does_not_pair_or_open_manager(self):
        calls = []
        class Bus:
            def call_sync(self, name, path, interface, method, parameters, *_):
                calls.append((name, method))
                if method == 'StartServiceByName':
                    self.assert_name = parameters.unpack()[0]
                    assert self.assert_name == 'org.blueman.Applet'
                    return GLib.Variant('(u)', (1,))
                if method == 'GetConnectionUnixProcessID': return GLib.Variant('(u)', (123,))
                if method == 'ListNames': return GLib.Variant('(as)', ([':1.2'],))
                if method == 'QueryPlugins': return GLib.Variant('(as)', (['AuthAgent'],))
                if method == 'Introspect': return GLib.Variant('(s)', ('<interface name="org.bluez.Agent1"/>',))
                raise AssertionError(method)
        with patch.object(desktop.shutil, 'which', return_value='/usr/bin/blueman-applet'), patch.object(Gio, 'bus_get_sync', return_value=Bus()):
            self.assertEqual(desktop.ensure_agent(), 0)
        self.assertFalse(any(name == 'org.blueman.Manager' or method in ('Pair', 'Connect', 'StartDiscovery', 'Set') for name,method in calls))

    def test_missing_agent_fails_without_spawning_manager(self):
        with patch.object(desktop.shutil, 'which', return_value=None), patch.object(desktop.subprocess, 'call') as launch:
            self.assertEqual(desktop.ensure_agent(), 1)
            launch.assert_not_called()

    def test_theme_is_scoped_to_child_environment(self):
        source = MagicMock(); schema = MagicMock(); source.lookup.return_value = schema
        schema.has_key.return_value = True
        settings = MagicMock(); settings.get_string.side_effect = lambda key: {'gtk-theme':'Adwaita', 'color-scheme':'prefer-dark'}[key]
        before = dict(os.environ)
        with patch.object(Gio.SettingsSchemaSource, 'get_default', return_value=source), patch.object(Gio.Settings, 'new_full', return_value=settings):
            self.assertEqual(desktop.theme_environment()['GTK_THEME'], 'Adwaita:dark')
        self.assertEqual(dict(os.environ), before)


if __name__ == '__main__': unittest.main()
