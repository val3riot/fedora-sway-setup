import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
QS_SERVICES = ROOT / 'dotfiles/quickshell/.config/quickshell/workstation/services'
if not QS_SERVICES.exists():
    QS_SERVICES = ROOT / 'templates/quickshell/services'
sys.path.insert(0, str(QS_SERVICES))
import wifi
import network
from network import NM


def row(ssid='Home', strength=50, current=False, path='/ap/1'):
    return dict(ssid=ssid or 'Rete nascosta', ssidKey=ssid.encode().hex(), strength=strength,
                current=current, path=path, secure=True, security='WPA/RSN')


class Wifi(unittest.TestCase):
    def setUp(self):
        disconnect = patch.object(network.GObject.Object, 'disconnect')
        disconnect.start()
        self.addCleanup(disconnect.stop)
        self.client = MagicMock()
        self.client.get_devices.return_value = []
        self.client.get_nm_running.return_value = True
        self.client.wireless_get_enabled.return_value = True
        self.client.wireless_hardware_get_enabled.return_value = True
        self.client.get_primary_connection.return_value = None
        self.service = network.Network(self.client)
        self.device = MagicMock()
        self.device.get_device_type.return_value = NM.DeviceType.WIFI
        self.device.is_real.return_value = True
        self.device.get_path.return_value = '/device/1'
        self.device.get_iface.return_value = 'wlan0'
        self.device.get_ip4_config.return_value = None
        self.device.get_state.return_value = NM.DeviceState.ACTIVATED
        self.ap = MagicMock()
        self.ap.get_path.return_value = '/ap/1'
        self.ap.get_ssid.return_value.get_data.return_value = b'Home'
        self.ap.get_strength.return_value = 75
        self.ap.get_wpa_flags.return_value = 1
        self.ap.get_rsn_flags.return_value = 1
        self.ap.get_flags.return_value = 1
        self.device.get_access_points.return_value = [self.ap]
        self.device.get_active_access_point.return_value = self.ap
        self.device.get_available_connections.return_value = []

    def snapshot(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.service.previous = None
            self.service.update()
        return json.loads(out.getvalue())

    def hardware(self):
        self.client.get_devices.return_value = [self.device]

    def test_absent_and_present_current(self):
        self.assertFalse(self.snapshot()['wifiAvailable'])
        self.hardware()
        state = self.snapshot()
        self.assertTrue(state['wifiAvailable'])
        self.assertTrue(state['accessPoints'][0]['current'])
        self.assertEqual(state['accessPoints'][0]['strength'], 75)
        self.device.is_real.return_value = False
        self.assertFalse(self.snapshot()['wifiAvailable'])

    def test_dedup_sort_current_and_hidden(self):
        rows = [row(strength=20, current=True), row(strength=95, path='/ap/2'),
                row('Office', 90, path='/ap/3'), row('', 30, path='/ap/4'), row('', 40, path='/ap/5')]
        result = wifi.deduplicate(rows)
        self.assertEqual(len(result), 4)
        self.assertEqual(result[0]['path'], '/ap/1')
        self.assertEqual(result[0]['strength'], 95)
        self.assertEqual([r['strength'] for r in result], [95, 90, 40, 30])
        self.assertEqual(wifi.deduplicate([]), [])

    def test_saved_activation_without_secrets(self):
        self.hardware()
        profile = MagicMock()
        self.device.get_available_connections.return_value = [profile]
        self.ap.connection_valid.return_value = True
        self.service.command({'action': 'connect', 'path': '/ap/1'})
        args = self.client.activate_connection_async.call_args.args
        self.assertEqual(args[:3], (profile, self.device, '/ap/1'))
        self.assertTrue(self.service.busy)
        self.assertEqual(self.service.message, 'Connecting…')
        active = MagicMock()
        active.get_state.return_value = NM.ActiveConnectionState.ACTIVATED
        self.client.activate_connection_finish.return_value = active
        args[4](self.client, None)
        self.snapshot()
        self.assertFalse(self.service.busy)
        self.assertEqual(self.service.message, 'Connessa')
        profile.get_secrets.assert_not_called()

    def test_open_and_secured_fallback(self):
        self.hardware()
        with patch.object(self.service, 'configure') as configure:
            self.service.command({'action': 'connect', 'path': '/ap/1'})
            configure.assert_called_once()
        self.client.add_and_activate_connection_async.assert_not_called()
        self.ap.get_wpa_flags.return_value = 0
        self.ap.get_rsn_flags.return_value = 0
        self.ap.get_flags.return_value = 0
        self.service.command({'action': 'connect', 'path': '/ap/1'})
        self.assertIsNone(self.client.add_and_activate_connection_async.call_args.args[0])

    def test_toggle_and_disabled_list(self):
        self.hardware()
        self.service.command({'action': 'toggle', 'enabled': False})
        args = self.client.dbus_set_property.call_args.args
        self.assertEqual(args[2], 'WirelessEnabled')
        self.assertFalse(args[3].unpack())
        args[6](self.client, None)
        self.client.wireless_get_enabled.return_value = False
        self.assertEqual(self.snapshot()['accessPoints'], [])

    def test_scan_rate_limit_and_disappearance(self):
        self.hardware()
        self.service.command({'action': 'scan'})
        self.service.command({'action': 'scan'})
        self.device.request_scan_async.assert_called_once()
        self.device.get_access_points.return_value = []
        self.service.command({'action': 'connect', 'path': '/ap/1'})
        self.assertIn('non più disponibile', self.service.message)

    def test_system_editor_no_credentials_and_async_reap(self):
        with patch.object(network.shutil, 'which', return_value='/usr/bin/nm-connection-editor'), \
             patch.object(network.Gio.Subprocess, 'new') as launch:
            self.service.configure()
            self.assertEqual(launch.call_args.args[0],
                             ['/usr/bin/nm-connection-editor', '--create', '--type=802-11-wireless'])
            launch.return_value.wait_check_async.assert_called_once()
        with patch.object(network.shutil, 'which', return_value=None):
            self.service.configure()
            self.assertIn('tool NetworkManager', self.service.message)

    def test_scan_and_toggle_failure(self):
        self.hardware()
        self.service.command({'action': 'scan'})
        self.device.request_scan_finish.side_effect = network.GLib.Error('private detail')
        self.device.request_scan_async.call_args.args[1](self.device, None)
        self.assertEqual(self.service.scan_count, 0)
        self.assertIn('fallita', self.service.message)
        self.service.command({'action': 'toggle', 'enabled': False})
        self.client.dbus_set_property_finish.side_effect = network.GLib.Error('private detail')
        self.client.dbus_set_property.call_args.args[6](self.client, None)
        self.assertFalse(self.service.busy)
        self.assertIn('fallito', self.service.message)

    def test_empty_ssid_uses_system_editor(self):
        self.hardware()
        self.ap.get_ssid.return_value = None
        state = self.snapshot()
        self.assertTrue(state['accessPoints'][0]['hidden'])
        with patch.object(self.service, 'configure') as configure:
            self.service.command({'action': 'connect', 'path': '/ap/1'})
            configure.assert_called_once()

    def test_multiple_adapters_dedup(self):
        self.hardware()
        second = MagicMock(wraps=self.device)
        second.get_device_type.return_value = NM.DeviceType.WIFI
        second.is_real.return_value = True
        second.get_access_points.return_value = [self.ap]
        second.get_state.return_value = NM.DeviceState.DISCONNECTED
        second.get_ip4_config.return_value = None
        second.get_iface.return_value = 'wlan1'
        self.client.get_devices.return_value = [self.device, second]
        state = self.snapshot()
        self.assertEqual(len(state['interfaces']), 2)
        self.assertEqual(len(state['accessPoints']), 1)

    def test_errors_and_no_secret_output(self):
        self.hardware()
        profile = MagicMock()
        self.device.get_available_connections.return_value = [profile]
        self.ap.connection_valid.return_value = True
        self.service.command({'action': 'connect', 'path': '/ap/1'})
        self.client.activate_connection_finish.side_effect = network.GLib.Error('DO-NOT-LOG-password')
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.client.activate_connection_async.call_args.args[4](self.client, None)
            self.service.command({'action': 'connect', 'path': '/ap/1', 'password': 'DO-NOT-LOG-password'})
            self.service.update()
        self.assertNotIn('DO-NOT-LOG', out.getvalue())
        self.assertIn('fallita', self.service.message)
        self.assertFalse(wifi.valid_command({'action': 'toggle', 'enabled': 'false'}))
        self.assertFalse(wifi.valid_command({'action': 'arbitrary'}))


if __name__ == '__main__':
    unittest.main()
