#!/usr/bin/env python3
"""Render Bluetooth hotplug/power transitions on isolated Sway with fake devices."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from PIL import Image, ImageChops
ROOT = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix='bluetooth-popup-') as tmp:
        work = Path(tmp)
        runtime = work / 'runtime'; runtime.mkdir(mode=0o700)
        config = work / 'config'; shutil.copytree(ROOT / 'templates/quickshell', config)
        shutil.copyfile(ROOT / 'tests/fixtures/quickshell/bluetooth-popup.qml', config / 'shell.qml')
        sway_config = work / 'sway.conf'
        sway_config.write_text('output * resolution 1280x720\nseat seat0 fallback true\ninclude ' + str(ROOT / 'templates/sway/config.d/62-system-utilities.conf') + '\n')
        env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='1',
                   WLR_LIBINPUT_NO_DEVICES='1', WORKSTATION_QUICKSHELL_TEST='1', QT_QPA_PLATFORM='wayland')
        env.pop('SWAYSOCK', None); env.pop('I3SOCK', None)
        with (work / 'sway.log').open('w') as slog, (work / 'qs.log').open('w') as qlog:
            sway = subprocess.Popen(['sway', '-c', str(sway_config)], env=env, stdout=slog, stderr=slog)
            qs = None
            try:
                socket = runtime / f'sway-ipc.{os.getuid()}.{sway.pid}.sock'
                for _ in range(100):
                    if socket.exists(): break
                    time.sleep(.05)
                assert socket.exists(), 'Sway test startup'
                display = next(p.name for p in runtime.glob('wayland-*') if not p.name.endswith('.lock'))
                env.update(WAYLAND_DISPLAY=display, SWAYSOCK=str(socket), I3SOCK=str(socket))
                qs = subprocess.Popen(['quickshell', '--no-color', '--path', str(config)], env=env, stdout=qlog, stderr=qlog)
                time.sleep(.8)
                def ipc(method, *args):
                    return subprocess.check_output(['quickshell', 'ipc', '--pid', str(qs.pid), 'call', 'popupTest', method, *map(str,args)], env=env, text=True)
                snapshots = []
                for i, mode in enumerate([0, 1, 0, 3, 0, 4, 0, 1, 0]):
                    ipc('change', mode); time.sleep(.25)
                    geometry = json.loads(ipc('geometry'))
                    path = work / f'{i}.png'
                    subprocess.run(['grim', str(path)], env=env, check=True)
                    snapshots.append((mode, geometry, Image.open(path).convert('RGB')))
                baseline = snapshots[0][2].crop((952, 32, 1272, 66))
                for mode, geometry, shot in snapshots:
                    assert geometry == snapshots[0][1], ('Popup resized during update', mode, geometry)
                    # Header ON must retain the same pixels through list/message resizes.
                    if mode != 3:
                        assert max(hi for lo, hi in ImageChops.difference(baseline, shot.crop((952, 32, 1272, 66))).getextrema()) <= 2, ('Header distorted', mode, geometry)
                assert ImageChops.difference(snapshots[0][2], snapshots[1][2]).getbbox(), 'Device update not rendered'
                assert ImageChops.difference(baseline, snapshots[3][2].crop((952, 32, 1272, 66))).getbbox(), 'Power state not rendered'
                # Overlay must cover the popup and fullscreen without changing focus.
                utility = subprocess.Popen([str(ROOT / 'bin/workstation-system-tool'), 'bluetooth', '--', '/usr/bin/sleep', '30'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                def leaves(node):
                    yield node
                    for child in node.get('nodes', []) + node.get('floating_nodes', []):
                        yield from leaves(child)
                def tree():
                    return json.loads(subprocess.check_output(['swaymsg', '-r', '-t', 'get_tree'], env=env))
                try:
                    for _ in range(60):
                        window = next((n for n in leaves(tree()) if n.get('app_id') == 'workstation-bluetooth'), None)
                        if window: break
                        time.sleep(.1)
                    assert window and window['type'] == 'floating_con', window
                    rect = window['rect']
                    assert 800 <= rect['width'] <= 900 and 500 <= rect['height'] <= 650, rect
                    assert abs(rect['x'] + rect['width']/2 - 640) <= 3, rect
                    focus = next(n['id'] for n in leaves(tree()) if n.get('focused'))
                    # Place utility beneath the toast to verify floating-window layering too.
                    subprocess.run(['swaymsg', '[con_id=' + str(window['id']) + '] move position 700 32'], env=env, check=True, stdout=subprocess.DEVNULL)
                    for fullscreen in (False, True):
                        if fullscreen:
                            subprocess.run(['swaymsg', '[con_id=' + str(window['id']) + '] fullscreen enable'], env=env, check=True, stdout=subprocess.DEVNULL)
                        ipc('toast', 'true'); time.sleep(.25)
                        path = work / ('fullscreen.png' if fullscreen else 'overlay.png')
                        subprocess.run(['grim', str(path)], env=env, check=True)
                        shot = Image.open(path).convert('RGB')
                        # Critical border at right-anchored 360px toast (x=908, y=40).
                        assert shot.getpixel((908, 50)) == (224, 108, 117), ('toast below popup/fullscreen', fullscreen, shot.getpixel((908, 50)))
                        assert next(n['id'] for n in leaves(tree()) if n.get('focused')) == focus, 'notification stole keyboard focus'
                        ipc('toast', 'false')
                    print('OK overlay: popup, floating utility, fullscreen; keyboard focus preserved')
                finally:
                    if window:
                        subprocess.run(['swaymsg', '[con_id=' + str(window['id']) + '] kill'], env=env, stdout=subprocess.DEVNULL)
                    utility.wait(timeout=5)
                short = subprocess.Popen([str(ROOT / 'bin/workstation-system-tool'), 'bluetooth', '--', '/usr/bin/sleep', '1.5'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                time.sleep(.4)
                assert any(n.get('app_id') == 'workstation-bluetooth' for n in leaves(tree())), 'short utility never mapped'
                assert short.wait(timeout=5) == 0
                time.sleep(.15)
                assert not any(n.get('app_id') == 'workstation-bluetooth' for n in leaves(tree())), 'Kitty held window after command exit'
                print('OK utility: command exit closes Kitty')
                print('OK Bluetooth popup: repeated discovery, removal, power and message rendering')
                print('Geometries:', [(m,g) for m,g,_ in snapshots])
            finally:
                if qs: qs.terminate(); qs.wait(timeout=5)
                sway.terminate(); sway.wait(timeout=5)
                output = (work / 'qs.log').read_text()
                print(output)
                if os.environ.get('WORKSTATION_KEEP_POPUP_TEST'):
                    dest = Path('/tmp/workstation-popup-render-test'); shutil.copytree(work,dest,dirs_exist_ok=True,ignore=shutil.ignore_patterns('runtime'))
        assert not any(t in output for t in ('ERROR', 'WARN scene', 'TypeError', 'Binding loop')), output

if __name__ == '__main__':
    main()
