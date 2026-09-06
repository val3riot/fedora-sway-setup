import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('controller', ROOT / 'bin/workstation-notifications.py')
controller = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controller)


class Migration(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.original = '# workstation-setup: managed sway config\nexec --no-startup-id mako\ninclude ~/.config/sway/config.d/*\n'

    def snapshot(self):
        return {str(p.relative_to(self.home)): ('mask' if p.is_symlink() else p.read_text())
                for p in self.home.rglob('*') if p.is_file() or p.is_symlink()}

    def test_migration_idempotent_and_rollback(self):
        content, changes = controller.plan(self.home, self.original)
        controller.apply(changes)
        self.assertNotIn('\nexec --no-startup-id mako\n', content)
        self.assertTrue((self.home / '.config/systemd/user/mako.service').is_symlink())
        self.assertTrue((self.home / '.config/systemd/user/dunst.service').is_symlink())
        before = self.snapshot()
        again, changes = controller.plan(self.home, content)
        controller.apply(changes)
        self.assertEqual(content, again)
        self.assertEqual(before, self.snapshot())
        rollback, changes = controller.plan(self.home, content, 'mako')
        controller.apply(changes)
        self.assertFalse((self.home / '.config/systemd/user/mako.service').is_symlink())
        self.assertIn('start mako.service', (self.home / '.config/sway/config.d/95-notifications.conf').read_text())
        _, changes = controller.plan(self.home, rollback)
        controller.apply(changes)
        self.assertEqual((self.home / '.config/workstation-setup/notifications').read_text(), 'mako\n')

    def test_personal_autostart_and_units_refused(self):
        with self.assertRaises(ValueError):
            controller.plan(self.home, self.original + 'exec mako --config private\n')
        unit = self.home / '.config/systemd/user/mako.service'
        unit.parent.mkdir(parents=True)
        unit.write_text('[Service]\nExecStart=/usr/bin/mako\n')
        before = self.snapshot()
        with self.assertRaises(ValueError):
            controller.plan(self.home, self.original)
        self.assertEqual(before, self.snapshot())

    def test_explicit_include_not_duplicated(self):
        content, changes = controller.plan(self.home, self.original.replace('include ~/.config/sway/config.d/*\n', ''))
        controller.apply(changes)
        again, _ = controller.plan(self.home, content)
        self.assertEqual(again.count('include ~/.config/sway/config.d/95-notifications.conf'), 1)


if __name__ == '__main__':
    unittest.main()
