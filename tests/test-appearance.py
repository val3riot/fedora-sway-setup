import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('appearance', ROOT/'bin/configure-appearance.py')
appearance = importlib.util.module_from_spec(spec); spec.loader.exec_module(appearance)


class Appearance(unittest.TestCase):
    def test_merge_and_idempotence(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(appearance.subprocess, 'run'):
            home = Path(tmp); path = home/'.config/gtk-3.0/settings.ini'
            path.parent.mkdir(parents=True); path.write_text('[Settings]\ngtk-enable-animations=false\n')
            appearance.apply(home)
            first = {str(p): p.read_text() for p in home.rglob('*') if p.is_file()}
            appearance.apply(home)
            self.assertEqual(first, {str(p): p.read_text() for p in home.rglob('*') if p.is_file()})
            self.assertIn('gtk-enable-animations = false', path.read_text())
            self.assertIn('gtk-application-prefer-dark-theme = true', path.read_text())
            self.assertNotIn('LD_LIBRARY_PATH', (home/'.config/environment.d/91-workstation-appearance.conf').read_text())

    def test_symlink_preflight(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp); target = home/'.config/gtk-4.0/settings.ini'
            target.parent.mkdir(parents=True); target.symlink_to(home/'personal')
            with self.assertRaises(ValueError): appearance.plan(home)
            self.assertFalse((home/'.config/gtk-3.0/settings.ini').exists())

    def test_quick_settings_composition(self):
        shell = (ROOT/'templates/quickshell/shell.qml').read_text()
        quick = (ROOT/'templates/quickshell/popups/QuickSettings.qml').read_text()
        self.assertEqual(shell.count('sourceComponent: QuickSettings {'), 1)
        self.assertNotIn('QuickSettings {', (ROOT/'templates/quickshell/bar/Bar.qml').read_text())
        for backend in ('Process {', 'Timer {', 'BluetoothService {', 'AudioService {', 'SystemData {'):
            self.assertNotIn(backend, quick)
        for operation in ('setVolume(value)', 'setInputVolume(value)', 'muteInput()', 'toggle()', 'networkCommand(', 'navigate("power")'):
            self.assertIn(operation, quick)
        self.assertIn('WORKSTATION_QUICKSHELL_TEST', quick)
        self.assertNotIn('session("Shutdown")', quick)

if __name__ == '__main__': unittest.main()
