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
    def setUp(self):
        self.valid_image = ROOT / 'wallpapers/mita.jpg'
        self.assertTrue(self.valid_image.is_file(), "mita.jpg missing in wallpapers/")

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


if __name__ == '__main__':
    unittest.main()
