import importlib.util
from pathlib import Path
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('windows', ROOT / 'bin/configure-sway-windows.py')
windows = importlib.util.module_from_spec(spec); spec.loader.exec_module(windows)


class WindowRules(unittest.TestCase):
    def test_migrate_idempotently(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp); conf = home / '.config/sway/config.d'; conf.mkdir(parents=True)
            (conf / '65-cliamp.conf').write_text('# workstation-setup: managed Cliamp widget rule\n'
                'for_window [app_id="^cliamp-widget$"] floating enable, border pixel 1, resize set width 920 height 640, move position center\n')
            launcher = home / '.local/bin/cliamp-widget'; launcher.parent.mkdir(parents=True)
            launcher.write_text('# old launcher --class cliamp-widget\n# .scratchpad_state\n')
            windows.configure(home)
            self.assertFalse((conf / '65-cliamp.conf').exists())
            self.assertNotIn('scratchpad', launcher.read_text())
            self.assertIn('] focus', launcher.read_text())
            self.assertIn('pavucontrol', (conf / '61-desktop-app-windows.conf').read_text())
            before = {str(p): p.read_bytes() for p in home.rglob('*') if p.is_file()}
            windows.configure(home)
            self.assertEqual(before, {str(p): p.read_bytes() for p in home.rglob('*') if p.is_file()})

    def test_personal_utility_launcher_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            target = home / '.local/bin/workstation-system-tool'
            target.parent.mkdir(parents=True)
            target.write_text('# personal launcher\n')
            with self.assertRaises(ValueError): windows.configure(home)
            self.assertEqual(target.read_text(), '# personal launcher\n')
            self.assertFalse((home / '.config/sway/config.d').exists())

    def test_personal_rule_is_preserved_before_any_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp); conf = home / '.config/sway/config.d'; conf.mkdir(parents=True)
            target = conf / '65-cliamp.conf'; target.write_text('# personal rule\n')
            with self.assertRaises(ValueError): windows.configure(home)
            self.assertEqual(list(conf.iterdir()), [target])


if __name__ == '__main__': unittest.main()
