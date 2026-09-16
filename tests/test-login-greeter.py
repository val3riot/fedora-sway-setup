#!/usr/bin/env python3
"""Tests for greetd + gtkgreet configuration and templates."""
from pathlib import Path
import subprocess
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GreeterConfigTests(unittest.TestCase):
    def test_greetd_toml_validity(self):
        toml_path = ROOT / 'templates/greetd/config.toml'
        self.assertTrue(toml_path.is_file())
        with open(toml_path, 'rb') as f:
            cfg = tomllib.load(f)

        self.assertIn('terminal', cfg)
        self.assertEqual(cfg['terminal'].get('vt'), 1)
        self.assertIn('default_session', cfg)
        self.assertEqual(cfg['default_session'].get('user'), 'greetd')
        self.assertIn('sway --config /etc/greetd/sway-config', cfg['default_session'].get('command', ''))

    def test_sway_greeter_config_syntax(self):
        sway_conf = ROOT / 'templates/greetd/sway-config'
        self.assertTrue(sway_conf.is_file())
        text = sway_conf.read_text()
        self.assertIn('output * bg /etc/greetd/wallpaper.jpg fill #16161a', text)
        self.assertIn('gtkgreet', text)
        self.assertIn('start-sway', text)
        self.assertIn('xwayland disable', text)

        # Validate syntax via sway -C
        res = subprocess.run(['sway', '-C', '-c', str(sway_conf)], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Sway config validation failed: {res.stderr}")

    def test_gtkgreet_css_theme(self):
        css_path = ROOT / 'templates/greetd/gtkgreet.css'
        self.assertTrue(css_path.is_file())
        css_text = css_path.read_text()
        self.assertIn('#body', css_text)
        self.assertIn('#e88923', css_text)
        self.assertIn('transparent', css_text)

    def test_environments_entries(self):
        env_path = ROOT / 'templates/greetd/environments'
        self.assertTrue(env_path.is_file())
        lines = [line.strip() for line in env_path.read_text().splitlines() if line.strip()]
        self.assertIn('start-sway', lines)
        self.assertIn('sway', lines)

    def test_module_integration(self):
        mod_text = (ROOT / 'modules/75-sway-desktop.sh').read_text()
        self.assertIn('greetd gtkgreet greetd-selinux', mod_text)
        self.assertIn('/etc/greetd/config.toml', mod_text)
        self.assertIn('/etc/greetd/sway-config', mod_text)
        self.assertIn('/etc/greetd/gtkgreet.css', mod_text)
        self.assertIn('workstation-wallpaper', mod_text)


if __name__ == '__main__':
    unittest.main()
