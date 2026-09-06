import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


stats = module('stats', 'templates/quickshell/services/stats.py')
occupancy = module('occupancy', 'templates/quickshell/services/occupancy.py')


class Statistics(unittest.TestCase):
    def test_cpu_delta_and_guest(self):
        self.assertEqual(stats.cpu_sample('cpu 10 2 3 80 5 0 0 0 9 1'), (100, 85))
        self.assertEqual(stats.cpu_usage((100, 85), (200, 155)), 30)
        for previous, current in [(None, (0, 0)), ((10, 5), (10, 5)), ((20, 10), (10, 5))]:
            self.assertIsNone(stats.cpu_usage(previous, current))

    def test_available_memory(self):
        self.assertEqual(stats.memory_usage('MemTotal: 1000 kB\nMemFree: 10 kB\nMemAvailable: 660 kB'), 34)
        self.assertIsNone(stats.memory_usage('MemTotal: 0 kB'))
        self.assertIsNone(stats.memory_usage('MemTotal: 100 kB\nMemAvailable: 101 kB'))

    def test_sensor_detection(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, driver, label, value in [('hwmon7', 'coretemp', 'Package id 0', '52000'),
                                                ('hwmon0', 'nvme', 'Composite', '85000')]:
                sensor = root / 'class/hwmon' / name
                sensor.mkdir(parents=True)
                for file, data in [('name', driver), ('temp1_label', label), ('temp1_input', value)]:
                    (sensor / file).write_text(data)
            paths = stats.detect_temperature(root)
            self.assertEqual(len(paths), 1)
            self.assertEqual(stats.temperature(paths), 52)
            paths[0].unlink()
            self.assertIsNone(stats.temperature(paths))
            self.assertIsNone(stats.temperature([]))

    def test_fullscreen_output(self):
        tree = {'nodes': [{'type': 'output', 'name': 'test-output', 'nodes': [
            {'type': 'workspace', 'fullscreen_mode': 1, 'nodes': []}]}]}
        self.assertEqual(occupancy.fullscreen_outputs(tree), {})
        tree['nodes'][0]['nodes'][0]['nodes'] = [{'type': 'con', 'fullscreen_mode': 1}]
        self.assertEqual(occupancy.fullscreen_outputs(tree), {'test-output': True})

    def test_occupancy_floating_and_empty(self):
        self.assertEqual(occupancy.counts({'nodes': [
            {'type': 'workspace', 'id': 4, 'nodes': [{'type': 'con', 'nodes': []}]},
            {'type': 'workspace', 'id': 5, 'floating_nodes': [{'pid': 123}]},
        ]}), {'4': False, '5': True})


class Migration(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.config = self.home / '.config/sway/config'
        self.config.parent.mkdir(parents=True)
        self.original = ('# workstation-setup: managed sway config\n'
                         'exec --no-startup-id waybar\nexec mako\n'
                         'set $lock $HOME/.local/bin/workstation-lock\n'
                         'include ~/.config/sway/config.d/*\n')
        self.config.write_text(self.original)

    def tearDown(self):
        self.tmp.cleanup()

    def configure(self, success=True):
        env = dict(os.environ)
        env.pop('XDG_CONFIG_HOME', None)
        result = subprocess.run(['python3', str(ROOT / 'bin/configure-quickshell.py'), '--home', str(self.home)],
                                env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)

    def snapshot(self):
        return {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob('*') if p.is_file()}

    def test_upgrade_idempotent_preserves_helpers(self):
        self.configure()
        before = self.snapshot()
        self.configure()
        self.assertEqual(before, self.snapshot())
        text = self.config.read_text()
        self.assertNotIn('\nexec --no-startup-id waybar\n', text)
        self.assertIn('exec mako', text)
        self.assertIn('workstation-lock', text)
        self.assertEqual(self.config.with_name('config.pre-quickshell.bak').read_text(), self.original)
        self.assertEqual(len(list(self.home.rglob('*.bak'))), 1)

    def test_personal_config_unchanged(self):
        self.config.write_text('exec waybar\n')
        before = self.snapshot()
        self.configure(False)
        self.assertEqual(before, self.snapshot())

    def test_unknown_include_and_bar_refused(self):
        for extra in ['include ~/personal-sway.conf\n', 'exec waybar --config custom\n', 'bar {\n}\n']:
            self.config.write_text(self.original + extra)
            before = self.snapshot()
            self.configure(False)
            self.assertEqual(before, self.snapshot())

    def test_personal_qml_refused_without_partial_write(self):
        self.configure()
        shell = self.home / '.config/quickshell/workstation/shell.qml'
        shell.write_text(shell.read_text() + '// personal\n')
        before = self.snapshot()
        self.configure(False)
        self.assertEqual(before, self.snapshot())

    def test_personal_dropin_refused(self):
        directory = self.config.parent / 'config.d'
        directory.mkdir()
        (directory / '90-bar.conf').write_text('exec waybar\n')
        before = self.snapshot()
        self.configure(False)
        self.assertEqual(before, self.snapshot())

    def test_no_include_is_added_once(self):
        self.config.write_text(self.original.replace('include ~/.config/sway/config.d/*\n', ''))
        self.configure()
        self.configure()
        self.assertEqual(self.config.read_text().count('include ~/.config/sway/config.d/90-bar.conf'), 1)


class CliAndRollback(unittest.TestCase):
    def test_cli_module_selection(self):
        if os.geteuid() == 0:
            self.skipTest('CLI intentionally rejects root')
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib').mkdir()
            (root / 'modules').mkdir()
            (root / 'bin').mkdir()
            (root / 'install.sh').write_bytes((ROOT / 'install.sh').read_bytes())
            (root / 'lib/common.sh').write_text("require_fedora_44() { :; }\nload_config() { :; }\nvalidate_config() { :; }\ncommand_exists() { return 0; }\nlog() { :; }\ndie() { echo \"$*\" >&2; exit 1; }\n")
            for extra in ['laptop-power-mode', 'docker-runtime']:
                (root / 'bin' / extra).write_text('#!/bin/bash\n')
            for name in [p.name for p in (ROOT / 'modules').glob('*.sh')]:
                (root / 'modules' / name).write_text('echo "' + name + ' $CONFIG_QUICKSHELL" >> "$CLI_RECORD"\n')
            def run(flags):
                record = root / 'record'
                record.write_text('')
                result = subprocess.run(['bash', str(root / 'install.sh'), *flags],
                    env=dict(os.environ, HOME=str(root), CLI_RECORD=str(record), XDG_STATE_HOME=str(root / 'state')),
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                return record.read_text()
            standalone = run(['--config-quickshell'])
            self.assertIn('76-quickshell.sh true', standalone)
            self.assertNotIn('75-sway-desktop.sh', standalone)
            self.assertNotIn('20-shell.sh', standalone)
            combined = run(['--sway-desktop', '--config-quickshell'])
            self.assertIn('75-sway-desktop.sh true', combined)
            self.assertIn('76-quickshell.sh true', combined)
            normal = run(['--sway-desktop'])
            self.assertNotIn('76-quickshell.sh', normal)
            self.assertIn('75-sway-desktop.sh false', normal)

    def test_fallback_and_rollback(self):
        import socket
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            bindir = home / 'bin'
            bindir.mkdir()
            selection = home / '.config/workstation-setup/bar'
            selection.parent.mkdir(parents=True)
            selection.write_text('quickshell\n')
            for name, body in {'pgrep': 'exit 1', 'pkill': 'exit 1',
                               'quickshell': 'echo "qs $*" >> "$RECORD"; exit 1',
                               'waybar': 'echo waybar >> "$RECORD"',
                               'systemctl': 'echo "systemctl $*" >> "$RECORD"'}.items():
                target = bindir / name
                target.write_text('#!/bin/bash\n' + body + '\n')
                target.chmod(0o755)
            with socket.socket(socket.AF_UNIX) as sock:
                path = home / 'sway.sock'
                sock.bind(str(path))
                env = dict(os.environ, HOME=str(home), SWAYSOCK=str(path), XDG_RUNTIME_DIR=str(home),
                           RECORD=str(home / 'record'), PATH=str(bindir) + ':' + os.environ['PATH'])
                subprocess.run(['bash', str(ROOT / 'bin/workstation-bar.sh'), 'run'], env=env, check=True, capture_output=True)
                lines = (home / 'record').read_text().splitlines()
                self.assertEqual(lines[-1], 'waybar')
                self.assertEqual(lines.count('waybar'), 1)
                subprocess.run(['bash', str(ROOT / 'bin/workstation-bar.sh'), 'waybar'], env=env, check=True)
                self.assertEqual(selection.read_text(), 'waybar\n')
                self.assertIn('systemctl --user restart workstation-bar.service', (home / 'record').read_text())


if __name__ == '__main__':
    unittest.main()
