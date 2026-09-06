#!/usr/bin/env python3
"""Validate QML in a disposable headless Sway, never in the user's compositor."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=Path, default=Path(__file__).resolve().parents[1] / 'templates/quickshell')
    parser.add_argument('--quickshell', default='quickshell')
    args = parser.parse_args()
    for executable in (args.quickshell, 'sway', 'swaymsg'):
        if not shutil.which(executable):
            print('SKIP Quickshell runtime: eseguibile assente:', executable)
            return 0
    original_runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/nonexistent'))
    with tempfile.TemporaryDirectory(prefix='workstation-qs-test-') as temporary:
        work = Path(temporary)
        runtime = work / 'runtime'
        runtime.mkdir(mode=0o700)
        # Keep PipeWire read access while isolating Wayland and Sway completely.
        if (original_runtime / 'pipewire-0').exists():
            (runtime / 'pipewire-0').symlink_to(original_runtime / 'pipewire-0')
        config = work / 'config'
        shutil.copytree(args.config, config, ignore=shutil.ignore_patterns('__pycache__'))
        sway_config = work / 'sway.conf'
        sway_config.write_text('output * resolution 1280x720\nseat seat0 fallback true\n')
        env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless',
                   WLR_HEADLESS_OUTPUTS='2', WLR_LIBINPUT_NO_DEVICES='1',
                   WORKSTATION_QUICKSHELL_TEST='1', QT_QPA_PLATFORM='wayland')
        env.pop('SWAYSOCK', None)
        env.pop('I3SOCK', None)
        with (work / 'sway.log').open('w') as log:
            sway = subprocess.Popen(['sway', '-c', str(sway_config)], env=env, stdout=log, stderr=log)
            try:
                socket = runtime / f'sway-ipc.{os.getuid()}.{sway.pid}.sock'
                deadline = time.monotonic() + 5
                while not socket.exists() and sway.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.05)
                if not socket.exists():
                    print('FAIL Sway headless:', (work / 'sway.log').read_text())
                    return 1
                displays = [p for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')]
                env.update(SWAYSOCK=str(socket), I3SOCK=str(socket), WAYLAND_DISPLAY=displays[0].name)

                def launch(seconds):
                    process = subprocess.Popen([args.quickshell, '--no-color', '--path', str(config)],
                                               env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                    try:
                        output, _ = process.communicate(timeout=seconds)
                        alive = False
                    except subprocess.TimeoutExpired:
                        alive = True
                        process.terminate()
                        output, _ = process.communicate(timeout=5)
                    print(output, end='')
                    bad = any(token in output for token in ('ERROR:', 'WARN scene:', 'TypeError:', 'ReferenceError:', 'Traceback', 'non-bindable', 'Binding loop'))
                    return alive and 'Configuration Loaded' in output and not bad, output

                valid, _ = launch(4)
                if not valid:
                    return 1
                # Harness reuses the real components and services. No power action
                # is invoked; TEST also blocks the helper independently of QML.
                (config / 'shell.qml').write_text('''
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Services.Pipewire
import "bar"
import "services"
ShellRoot {
    id: root
    property string opened: ""
    property int phase: 0
    SystemData { id: telemetry }
    AudioService { id: sound }
    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
            systemData: telemetry
            audioService: sound
            opened: root.opened
        }
    }
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: {
            root.phase++;
            if (root.phase === 2) I3.workspaces.values[1].activate();
            if (root.phase === 3) I3.dispatch("workspace number 7");
            const names = ["audio", "network", "calendar", "power", "", "audio", "calendar", ""];
            root.opened = names[(root.phase - 1) % names.length];
            console.warn("TEST popup " + root.opened);
            if (root.phase === 7) {
                console.warn("TEST snapshot " + JSON.stringify({
                    screens: Quickshell.screens.length,
                    workspaces: I3.workspaces.values.map(w => ({number: w.number, output: w.monitor ? w.monitor.name : "", focused: w.focused})),
                    stats: telemetry.stats, network: telemetry.network.state,
                    pipewire: Pipewire.ready, audio: sound.label
                }));
                if (Quickshell.screens.length !== 2 || I3.workspaces.values.length < 2
                    || !I3.focusedWorkspace || I3.focusedWorkspace.number !== 7
                    || telemetry.stats.cpu === null || telemetry.stats.ram === null)
                    console.error("TEST FAILED");
            }
        }
    }
}
''')
                valid, output = launch(9)
                if not valid or 'TEST snapshot' not in output or 'TEST FAILED' in output:
                    return 1
                print('OK Quickshell QML, 2 output, Sway IPC, statistiche e popup; power non eseguito')
                return 0
            finally:
                sway.terminate()
                try:
                    sway.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    sway.kill()
                    sway.wait()


if __name__ == '__main__':
    raise SystemExit(main())
