import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    file_path = ROOT / path if not Path(path).is_absolute() else Path(path)
    spec = importlib.util.spec_from_file_location(name, file_path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


QS_DIR = ROOT / 'dotfiles/quickshell/.config/quickshell/workstation' if (ROOT / 'dotfiles/quickshell/.config/quickshell/workstation').exists() else ROOT / 'templates/quickshell'
SWAY_CONF = ROOT / 'dotfiles/sway/.config/sway/config' if (ROOT / 'dotfiles/sway/.config/sway/config').exists() else ROOT / 'templates/sway/config'
stats = module('stats', QS_DIR / 'services/stats.py')
occupancy = module('occupancy', QS_DIR / 'services/occupancy.py')


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
        self.assertNotIn('\nexec mako\n', text)
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

    def test_current_sway_template_migrates_after_rerun(self):
        self.config.write_bytes(SWAY_CONF.read_bytes())
        self.configure()
        first = self.config.read_bytes()
        self.assertNotIn('exec --no-startup-id mako', first.decode())
        self.assertNotIn('exec --no-startup-id waybar', first.decode())
        self.config.write_bytes(SWAY_CONF.read_bytes())
        self.configure()
        self.assertEqual(first, self.config.read_bytes())

    def test_personal_dropin_refused(self):
        directory = self.config.parent / 'config.d'
        directory.mkdir()
        (directory / '90-bar.conf').write_text('exec waybar\n')
        before = self.snapshot()
        self.configure(False)
        self.assertEqual(before, self.snapshot())

    def test_managed_dotfiles_dropin_allowed(self):
        directory = self.config.parent / 'config.d'
        directory.mkdir()
        dotfiles_target = self.home / 'dotfiles/sway/.config/sway/config.d/90-bar.conf'
        dotfiles_target.parent.mkdir(parents=True)
        dotfiles_target.write_text('# workstation-setup: managed quickshell bar\nexec_always --no-startup-id systemctl --user start workstation-bar.service\n')
        (directory / '90-bar.conf').symlink_to(dotfiles_target)
        self.configure(True)

    def test_no_include_is_added_once(self):
        self.config.write_text(self.original.replace('include ~/.config/sway/config.d/*\n', ''))
        self.configure()
        self.configure()
        self.assertEqual(self.config.read_text().count('include ~/.config/sway/config.d/90-bar.conf'), 1)


class CliAndBar(unittest.TestCase):
    def test_cli_module_selection(self):
        if os.geteuid() == 0:
            self.skipTest('CLI intentionally rejects root')
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'lib').mkdir()
            (root / 'modules').mkdir()
            (root / 'bin').mkdir()
            (root / 'install.sh').write_bytes((ROOT / 'install.sh').read_bytes())
            (root / 'lib/common.sh').write_text("start_sudo_keepalive() { :; }\nstop_sudo_keepalive() { :; }\nrequire_fedora_44() { :; }\nload_config() { :; }\nvalidate_config() { :; }\ncommand_exists() { return 0; }\nlog() { :; }\ndie() { echo \"$*\" >&2; exit 1; }\n")
            for extra in ['laptop-power-mode', 'stow-dotfiles']:
                (root / 'bin' / extra).write_text('#!/bin/bash\n')
            for name in [p.name for p in (ROOT / 'modules').glob('*.sh')]:
                (root / 'modules' / name).write_text('echo "' + name + '" >> "$CLI_RECORD"\n')
            def run(flags):
                record = root / 'record'
                record.write_text('')
                result = subprocess.run(['bash', str(root / 'install.sh'), *flags],
                    env=dict(os.environ, HOME=str(root), CLI_RECORD=str(record), XDG_STATE_HOME=str(root / 'state')),
                    capture_output=True, text=True)
                return result.returncode, record.read_text(), result.stderr
            code, default_run, _ = run([])
            self.assertEqual(code, 0)
            self.assertIn('76-quickshell.sh', default_run)
            self.assertIn('75-sway-desktop.sh', default_run)
            self.assertIn('20-shell.sh', default_run)
            code, _, stderr = run(['--no-quickshell'])
            self.assertNotEqual(code, 0)
            self.assertIn('Opzione non valida', stderr)

    def test_bar_launcher(self):
        import socket
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            bindir = home / 'bin'
            bindir.mkdir()
            for name, body in {'quickshell': 'echo "qs $*" >> "$RECORD"',
                               'systemctl': 'echo "systemctl $*" >> "$RECORD"'}.items():
                target = bindir / name
                target.write_text('#!/bin/bash\n' + body + '\n')
                target.chmod(0o755)
            with socket.socket(socket.AF_UNIX) as sock:
                path = home / 'sway.sock'
                sock.bind(str(path))
                env = dict(os.environ, HOME=str(home), SWAYSOCK=str(path), XDG_RUNTIME_DIR=str(home),
                           RECORD=str(home / 'record'), PATH=str(bindir) + ':' + os.environ['PATH'])
                bar_script = ROOT / 'dotfiles/scripts/.local/bin/workstation-bar.sh'
                subprocess.run(['bash', str(bar_script), 'run'], env=env, check=True)
                lines = (home / 'record').read_text().splitlines()
                self.assertTrue(any('qs' in line and '--no-duplicate' in line for line in lines))
                subprocess.run(['bash', str(bar_script), 'restart'], env=env, check=True)
                self.assertIn('systemctl --user restart workstation-bar.service', (home / 'record').read_text())
                res = subprocess.run(['bash', str(bar_script), 'waybar'], env=env, capture_output=True)
                self.assertEqual(res.returncode, 2)



if __name__ == '__main__':
    unittest.main()
