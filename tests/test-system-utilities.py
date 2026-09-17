import importlib.machinery
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('utility', str(ROOT / 'bin/workstation-system-tool'))
spec = importlib.util.spec_from_loader(loader.name, loader)
utility = importlib.util.module_from_spec(spec)
loader.exec_module(utility)


class SystemUtilities(unittest.TestCase):
    def test_size_scales_with_output(self):
        self.assertEqual(utility.dimensions(dict(width=2560, height=1440)), (860, 580))
        self.assertEqual(utility.dimensions(dict(width=800, height=600)), (752, 504))

    def test_argv_preserves_arguments_and_theme(self):
        argv = utility.kitty_command('bluetooth', ['/test/tool', 'a; b', '$HOME'], dict(width=1280, height=720))
        self.assertEqual(argv[1:3], ['--app-id', 'workstation-bluetooth'])
        self.assertEqual(argv[-3:], ['/test/tool', 'a; b', '$HOME'])
        self.assertNotIn('--hold', argv)
        self.assertNotIn('--config', argv)
        self.assertNotIn('sh', argv)

    def test_no_normal_app_floating_rule(self):
        sway_util = ROOT / 'dotfiles/sway/.config/sway/config.d/62-system-utilities.conf'
        if not sway_util.exists():
            sway_util = ROOT / 'templates/sway/config.d/62-system-utilities.conf'
        rule = sway_util.read_text()
        self.assertIn('^workstation-(', rule)
        self.assertNotIn('app_id="kitty', rule)
        self.assertNotIn('workspace ', rule)

    def test_bt_popup_never_invokes_gui_or_pair(self):
        qs_src = ROOT / 'dotfiles/quickshell/.config/quickshell/workstation'
        if not qs_src.exists():
            qs_src = ROOT / 'templates/quickshell'
        service = (qs_src / 'services/BluetoothService.qml').read_text()
        row = (qs_src / 'popups/BluetoothDeviceRow.qml').read_text()
        for obsolete in ('desktop-settings.py', '.pair()', 'blueman-manager', 'preparePair'):
            self.assertNotIn(obsolete, service + row)
        self.assertIn('service.manage()', row)
        self.assertIn('workstation-system-tool', service)


if __name__ == '__main__':
    unittest.main()
