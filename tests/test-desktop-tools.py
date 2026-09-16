import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
ROOT = Path(__file__).resolve().parents[1]


def module(name, relative):
    target = ROOT / relative
    if not target.exists():
        target = ROOT / 'dotfiles/quickshell/.config/quickshell/workstation' / Path(relative).relative_to('templates/quickshell')
    loader = importlib.machinery.SourceFileLoader(name, str(target))
    spec = importlib.util.spec_from_loader(name, loader)
    result = importlib.util.module_from_spec(spec); loader.exec_module(result)
    return result


qs_root = 'dotfiles/quickshell/.config/quickshell/workstation' if (ROOT / 'dotfiles/quickshell/.config/quickshell/workstation').exists() else 'templates/quickshell'
clipboard = module('clipboard_store', f'{qs_root}/clipboard/store.py')
screenshot = module('screenshot', 'bin/workstation-screenshot')
lock = module('lock', 'bin/workstation-lock')
setup = module('desktop_setup', 'bin/configure-desktop-tools.py')
catalog = module('catalog', f'{qs_root}/launcher/catalog.py')


class DesktopTools(unittest.TestCase):
    def test_memory_history_full_text_dedup_and_clear(self):
        store = clipboard.History()
        text = 'line 1\n' + 'long text ' * 500
        self.assertTrue(store.add(text))
        self.assertEqual(store.get(store.rows()[0]['id']), text)
        self.assertEqual(len(store.rows('LONG')), 1)
        store.add('second'); store.add(text)
        self.assertEqual(len(store.rows()), 2)
        self.assertEqual(store.get(store.rows()[0]['id']), text)
        store.items.clear(); self.assertFalse(store.rows())

    def test_sensitive_and_size_limits(self):
        store = clipboard.History()
        for state in ('sensitive', 'nil', 'clear', 'unknown'):
            self.assertFalse(store.add('secret', state))
        for value in ('', '\x00', 'x' * (clipboard.LIMIT + 1)):
            self.assertFalse(store.add(value))
        for i in range(130): store.add(str(i))
        self.assertEqual(len(store.rows()), 100)
        clipboard_script = ROOT / f'{qs_root}/clipboard/store.py'
        result = subprocess.run(['/usr/bin/python3', str(clipboard_script), 'capture'],
                                input='never log this', text=True, capture_output=True,
                                env=dict(os.environ, CLIPBOARD_STATE='sensitive'))
        self.assertEqual(result.stdout + result.stderr, '')

    def test_cancel_area_writes_nothing(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(Path, 'home', return_value=Path(tmp)), \
             patch.object(screenshot.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, stdout='')):
            self.assertIsNone(screenshot.capture('area'))
            self.assertFalse(list(Path(tmp).iterdir()))

    def test_window_geometry_negative_origin(self):
        self.assertEqual(screenshot.geometry(dict(x=-1280, y=32, width=800, height=600)), '-1280,32 800x600')
        with self.assertRaises(ValueError): screenshot.geometry(dict(width=0, height=0))

    def test_screenshot_saves_and_copies_png(self):
        png = b'\x89PNG\r\n\x1a\nexample'
        outputs = b'[{"focused":true,"active":true,"name":"HEADLESS-1"}]'
        with tempfile.TemporaryDirectory() as tmp, patch.object(Path, 'home', return_value=Path(tmp)), \
             patch.object(screenshot.subprocess, 'check_output', side_effect=[outputs, png, outputs, png]), \
             patch.object(screenshot.subprocess, 'run') as run:
            first, second = screenshot.capture('output'), screenshot.capture('output')
            self.assertNotEqual(first, second)
            self.assertEqual(first.read_bytes(), png)
            self.assertEqual(first.stat().st_mode & 0o777, 0o600)
            self.assertEqual(run.call_args_list[0].kwargs['input'], png)

    def test_configuration_idempotence_and_lock_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            setup.apply(home, setup.plan(home))
            before = {str(p): p.read_bytes() for p in home.rglob('*') if p.is_file()}
            setup.apply(home, setup.plan(home))
            self.assertEqual(before, {str(p): p.read_bytes() for p in home.rglob('*') if p.is_file()})
            lock.check(home)
            self.assertIn('-C', lock.command(home))
            self.assertNotIn('--clock', lock.command(home))
            target = home / '.local/bin/workstation-shell'; target.write_text('personal')
            with self.assertRaises(ValueError): setup.plan(home)

    def test_invalid_desktop_entries(self):
        from gi.repository import GioUnix
        with tempfile.TemporaryDirectory() as tmp:
            for executable, expected in [('/bin/true', True), ('workstation-missing-application', False), ('', False)]:
                path = Path(tmp) / 'test.desktop'
                path.write_text('[Desktop Entry]\nType=Application\nName=Fixture\nExec=' + executable + '\n')
                try: app = GioUnix.DesktopAppInfo.new_from_filename(str(path))
                except TypeError: app = None
                self.assertEqual(bool(app and catalog.launchable(app)), expected)


if __name__ == '__main__': unittest.main()
