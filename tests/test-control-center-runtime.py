#!/usr/bin/env python3
"""Production shell coordination in two isolated outputs; never perform session actions."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from wayland_keys import Keyboard
ROOT = Path(__file__).resolve().parents[1]


def main():
    if not all(shutil.which(p) for p in ('quickshell','sway','grim','dbus-daemon')):
        print('SKIP Quick Settings runtime: compositor tools absent'); return
    with tempfile.TemporaryDirectory(prefix='desktop-tools-control-') as tmp:
        work=Path(tmp); runtime=work/'runtime'; runtime.mkdir(mode=0o700)
        config=work/'config'; shutil.copytree(ROOT/'templates/quickshell',config,ignore=shutil.ignore_patterns('__pycache__'))
        source=(config/'shell.qml').read_text().replace('import QtQuick','import QtQuick\nimport Quickshell.Io')
        source=source.replace('id: desktopRoot','''id: desktopRoot
    property var testBars: []
    function find(object, name) {
        if (object.objectName === name) return object;
        for (const child of object.children || []) { const found = find(child, name); if (found) return found; }
        return null;
    }
    IpcHandler {
        target: "controlsTest"
        function open(index: int): void { desktopRoot.testBars[index].quickSettingsRequested(); }
        function navigate(name: string): void { controlLoader.item.navigate(name); }
        function volume(name: string, value: real): void { const slider = desktopRoot.find(controlLoader.item.contentItem, name); slider.value = value; slider.moved(); }
        function close(): void { desktopRoot.controlPanel = null; }
        function notice(): void { notifications.receive({id: 999, summary: "Overlay test", body: "Above Quick Settings", appName: "Test", appIcon: "", image: "", actions: [], urgency: 2, expireTimeout: 0, transient: false}); }
        function state(): string { return JSON.stringify({open: controlLoader.active, screen: desktopRoot.controlPanel ? desktopRoot.controlPanel.screen.name : "", bars: desktopRoot.testBars.map(b => b.opened), output: audio.audio.volume, input: audio.inputAudio.volume}); }
    }''')
        source=source.replace('Loader {','Loader {\n        id: controlLoader',1).replace('id: outputBar','id: outputBar\n            Component.onCompleted: desktopRoot.testBars.push(outputBar)')
        (config/'shell.qml').write_text(source)
        (config/'services/AudioService.qml').write_text('''import QtQuick
import Quickshell
Scope {
    property bool ready: true; property bool available: true; property string label: "VOL 40%"; property string error: ""
    property var sink: ({description:"Fixture output"}); property var source: ({description:"Fixture input"})
    property var outputs: [sink]; property var inputs: [source]
    property QtObject audio: QtObject { property real volume: .4; property bool muted: false }
    property QtObject inputAudio: QtObject { property real volume: .6; property bool muted: false }
    function name(node) { return node.description; }
    function step(n) { audio.volume += n; }
    function setVolume(n) { audio.volume=n; }
    function setInputVolume(n) { inputAudio.volume=n; }
    function mute() { audio.muted=!audio.muted; }
    function muteInput() { inputAudio.muted=!inputAudio.muted; }
}''')
        (work/'sway.conf').write_text('output * resolution 1280x720\nseat seat0 fallback true\n')
        (work/'bus.conf').write_text('<busconfig><type>session</type><listen>unix:path='+str(runtime/'bus')+'</listen><auth>EXTERNAL</auth><policy context="default"><allow send_destination="*"/><allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
        env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),DBUS_SESSION_BUS_ADDRESS='unix:path='+str(runtime/'bus'),WLR_BACKENDS='headless',WLR_HEADLESS_OUTPUTS='2',WLR_LIBINPUT_NO_DEVICES='1',QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='software',WORKSTATION_QUICKSHELL_TEST='1')
        env.pop('SWAYSOCK',None);env.pop('I3SOCK',None)
        processes=[]; keyboard=None
        with (work/'log').open('w') as log:
            try:
                bus=subprocess.Popen(['dbus-daemon','--nofork','--config-file='+str(work/'bus.conf')],stdout=log,stderr=log);processes.append(bus)
                sway=subprocess.Popen(['sway','-c',str(work/'sway.conf')],env=env,stdout=log,stderr=log);processes.append(sway)
                sock=runtime/f'sway-ipc.{os.getuid()}.{sway.pid}.sock'
                for _ in range(80):
                    if sock.exists():break
                    time.sleep(.05)
                env.update(SWAYSOCK=str(sock),I3SOCK=str(sock),WAYLAND_DISPLAY=next(p.name for p in runtime.glob('wayland-*') if not p.name.endswith('.lock')))
                qs=subprocess.Popen(['quickshell','--no-color','--path',str(config)],env=env,stdout=log,stderr=log);processes.append(qs)
                keyboard=Keyboard(runtime,env['WAYLAND_DISPLAY']);time.sleep(1)
                def ipc(method,*args):return subprocess.check_output(['quickshell','ipc','--pid',str(qs.pid),'call','controlsTest',method,*map(str,args)],env=env,text=True).strip()
                def state():return json.loads(ipc('state'))
                ipc('open',0);time.sleep(.2);assert state()['open']
                ipc('open',0);assert not state()['open']
                ipc('open',0);first=state()['screen'];ipc('open',1);assert state()['screen']!=first
                for destination in ('network','bluetooth','audio','power','notifications'):
                    ipc('navigate',destination);assert not state()['open'] and destination in state()['bars']
                    ipc('open',0);assert state()['bars']==['','']
                ipc('volume','quickOutput',.73);ipc('volume','quickInput',.32)
                assert state()['output']==.73 and state()['input']==.32
                ipc('notice');time.sleep(.2)
                subprocess.run(['grim',str(work/'control-center.png')],env=env,check=True)
                # OnDemand accepts Escape after the user interacts with the panel.
                outputs=json.loads(subprocess.check_output(['swaymsg','-t','get_outputs'],env=env))
                rect=next(o['rect'] for o in outputs if o['name']==state()['screen'])
                keyboard.pointer(rect['x']+1100,300);keyboard.pointer(pressed=True);keyboard.pointer(pressed=False)
                keyboard.key(1);assert not state()['open'],state()
                print('OK Quick Settings: single panel, two outputs, navigation, output/input sliders, Escape, notifications')
            finally:
                if keyboard:keyboard.close()
                for process in reversed(processes):
                    if process.poll() is None:process.terminate()
                    process.wait(timeout=5)
                output=(work/'log').read_text();print(output)
        assert not any(s in output for s in ('ERROR:', 'TypeError:', 'ReferenceError:', 'Binding loop')),output

if __name__=='__main__':main()
