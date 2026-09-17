#!/usr/bin/env python3
"""Unit and integration tests for workstation-wallpaper switcher."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, MagicMock

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('workstation_wallpaper', str(ROOT / 'bin/workstation-wallpaper'))
spec = importlib.util.spec_from_loader('workstation_wallpaper', loader)
wallpaper = importlib.util.module_from_spec(spec)
loader.exec_module(wallpaper)


class WallpaperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp_dir = tempfile.TemporaryDirectory()
        existing = next((p for p in (ROOT / 'wallpapers').glob('*') if p.suffix.lower() in ('.jpg', '.jpeg', '.png') and p.is_file()), None)
        if existing:
            cls.valid_image = existing
        else:
            cls.valid_image = Path(cls._tmp_dir.name) / 'fixture.png'
            from gi.repository import GdkPixbuf
            pixbuf = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, False, 8, 64, 64)
            pixbuf.fill(0x336699ff)
            pixbuf.savev(str(cls.valid_image), 'png', [], [])

    @classmethod
    def tearDownClass(cls):
        cls._tmp_dir.cleanup()

    def test_validate_valid_image(self):
        pixbuf = wallpaper.validate_image(self.valid_image)
        self.assertGreater(pixbuf.get_width(), 0)
        self.assertGreater(pixbuf.get_height(), 0)

    def test_validate_nonexistent_file(self):
        with self.assertRaises(FileNotFoundError):
            wallpaper.validate_image(Path('/nonexistent/file.jpg'))

    def test_validate_non_image_file(self):
        with tempfile.NamedTemporaryFile(suffix='.txt', delete=False) as f:
            f.write(b"this is not an image file")
            tmp_path = Path(f.name)
        try:
            with self.assertRaises(ValueError):
                wallpaper.validate_image(tmp_path)
        finally:
            tmp_path.unlink(missing_ok=True)

    def test_atomic_update(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_target = Path(tmp_dir) / 'canonical/workstation-setup.jpg'
            wallpaper.update_target_atomically(self.valid_image, tmp_target)

            self.assertTrue(tmp_target.is_file())
            self.assertEqual(tmp_target.stat().st_size, self.valid_image.stat().st_size)
            self.assertEqual(tmp_target.stat().st_mode & 0o777, 0o644)

    def test_outside_sway_graceful_exit(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            target = Path(tmp_dir) / 'workstation-setup.jpg'
            with patch.object(wallpaper, 'CANONICAL_WALLPAPER_PATH', target), \
                 patch.object(wallpaper, 'apply_sway_runtime', return_value=False), \
                 patch.object(wallpaper, 'sync_gsettings'):
                exit_code = wallpaper.set_wallpaper(self.valid_image)
                self.assertEqual(exit_code, 0)
                self.assertTrue(target.is_file())

    def test_spaces_in_path(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            dir_with_spaces = Path(tmp_dir) / 'folder with spaces'
            dir_with_spaces.mkdir()
            img_with_spaces = dir_with_spaces / 'my image with spaces.jpg'
            wallpaper.update_target_atomically(self.valid_image, img_with_spaces)

            target = dir_with_spaces / 'canonical target.jpg'
            with patch.object(wallpaper, 'CANONICAL_WALLPAPER_PATH', target), \
                 patch.object(wallpaper, 'apply_sway_runtime', return_value=True), \
                 patch.object(wallpaper, 'sync_gsettings'):
                exit_code = wallpaper.set_wallpaper(img_with_spaces)
                self.assertEqual(exit_code, 0)
                self.assertTrue(target.is_file())

    def test_ensure_wallpaper_preserves_existing_valid(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            target = Path(tmp_dir) / 'workstation-setup.jpg'
            wallpaper.update_target_atomically(self.valid_image, target)
            original_mtime = target.stat().st_mtime_ns

            with patch.object(wallpaper, 'CANONICAL_WALLPAPER_PATH', target), \
                 patch.object(wallpaper, 'sync_greeter_wallpaper'), \
                 patch.object(wallpaper, 'sync_gsettings'), \
                 patch.object(wallpaper, 'apply_sway_runtime', return_value=False):
                code = wallpaper.ensure_wallpaper()
                self.assertEqual(code, 0)
                self.assertEqual(target.stat().st_mtime_ns, original_mtime)

    def test_ensure_wallpaper_picks_arbitrary_named_image(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            target = Path(tmp_dir) / 'canonical/workstation-setup.jpg'
            custom_img = Path(tmp_dir) / 'custom_wallpaper_name_123.jpg'
            wallpaper.update_target_atomically(self.valid_image, custom_img)

            with patch.object(wallpaper, 'CANONICAL_WALLPAPER_PATH', target), \
                 patch.object(wallpaper, 'find_best_default_wallpaper', return_value=custom_img), \
                 patch.object(wallpaper, 'sync_greeter_wallpaper'), \
                 patch.object(wallpaper, 'sync_gsettings'), \
                 patch.object(wallpaper, 'apply_sway_runtime', return_value=False):
                code = wallpaper.ensure_wallpaper()
                self.assertEqual(code, 0)
                self.assertTrue(target.is_file())
                self.assertEqual(target.stat().st_size, custom_img.stat().st_size)

    def test_ensure_wallpaper_generates_dark_fallback_when_none_available(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            target = Path(tmp_dir) / 'canonical/workstation-setup.jpg'

            with patch.object(wallpaper, 'CANONICAL_WALLPAPER_PATH', target), \
                 patch.object(wallpaper, 'find_best_default_wallpaper', return_value=None), \
                 patch.object(wallpaper, 'sync_greeter_wallpaper'), \
                 patch.object(wallpaper, 'sync_gsettings'), \
                 patch.object(wallpaper, 'apply_sway_runtime', return_value=False):
                code = wallpaper.ensure_wallpaper()
                self.assertEqual(code, 0)
                self.assertTrue(target.is_file())
                pixbuf = wallpaper.validate_image(target)
                self.assertEqual(pixbuf.get_width(), 1920)
                self.assertEqual(pixbuf.get_height(), 1080)

    def test_find_best_default_wallpaper_prefers_repo_then_user_then_system(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            repo_dir = Path(tmp_dir) / 'repo/wallpapers'
            repo_dir.mkdir(parents=True)
            custom_repo_img = repo_dir / 'my_custom_photo.png'
            wallpaper.update_target_atomically(self.valid_image, custom_repo_img)

            with patch.object(wallpaper, 'find_available_wallpapers', return_value=[custom_repo_img]):
                chosen = wallpaper.find_best_default_wallpaper()
                self.assertEqual(chosen, custom_repo_img)


if __name__ == '__main__':
    unittest.main()
