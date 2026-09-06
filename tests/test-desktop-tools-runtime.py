#!/usr/bin/env python3
"""Desktop overlays, keyboard, clipboard and screenshots on private Wayland."""
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
    with tempfile.TemporaryDirectory(prefix='desktop-tools-') as tmp:
        work = Path(tmp); runtime = work/'runtime'; runtime.mkdir(mode=0o700)
        home = work/'home'; home.mkdir()
        data = work/'data'; apps = data/'applications'; apps.mkdir(parents=True)
        for name, command in [('Alpha Fixture', '/usr/bin/touch ' + str(work/'launched')),
                              ('Beta Fixture', '/usr/bin/true'), ('Invalid Fixture', 'workstation-does-not-exist')]:
            (apps/(name.replace(' ','-')+'.desktop')).write_text('[Desktop Entry]\nType=Application\nName='+name+'\nExec='+command+'\n')
        config = work/'config'; shutil.copytree(ROOT/'templates/quickshell',config)
        shutil.copyfile(ROOT/'tests/fixtures/quickshell/desktop-tools.qml',config/'shell.qml')
        swayconf = work/'sway.conf'; swayconf.write_text('output * resolution 1280x720\nseat seat0 fallback true\n')
        env = dict(os.environ, HOME=str(home), XDG_RUNTIME_DIR=str(runtime), XDG_DATA_HOME=str(data), XDG_DATA_DIRS=str(data),
                   WLR_BACKENDS='headless', WLR_HEADLESS_OUTPUTS='2', WLR_LIBINPUT_NO_DEVICES='1', QT_QPA_PLATFORM='wayland', QT_QUICK_BACKEND='software', WORKSTATION_QUICKSHELL_TEST='0')
        env.pop('SWAYSOCK',None); env.pop('I3SOCK',None)
        processes = []; keyboard = None
        with (work/'sway.log').open('w') as sl, (work/'qml.log').open('w') as ql:
            try:
                # Private bus without activation directories: no portals/keyring or user daemons.
                busconf = work/'bus.conf'
                busconf.write_text('<busconfig><type>session</type><listen>unix:path='+str(runtime/'bus')+'</listen><auth>EXTERNAL</auth><policy context="default"><allow send_destination="*"/><allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
                bus = subprocess.Popen(['dbus-daemon','--nofork','--config-file='+str(busconf)], stdout=sl, stderr=sl)
                processes.append(bus)
                env['DBUS_SESSION_BUS_ADDRESS'] = 'unix:path='+str(runtime/'bus')
                for _ in range(60):
                    if (runtime/'bus').exists(): break
                    time.sleep(.05)
                sway = subprocess.Popen(['sway','-c',str(swayconf)],env=env,stdout=sl,stderr=sl); processes.append(sway)
                sock=runtime/f'sway-ipc.{os.getuid()}.{sway.pid}.sock'
                for _ in range(80):
                    if sock.exists():break
                    time.sleep(.05)
                display=next(p.name for p in runtime.glob('wayland-*') if not p.name.endswith('.lock'))
                env.update(SWAYSOCK=str(sock),I3SOCK=str(sock),WAYLAND_DISPLAY=display)
                qs=subprocess.Popen(['quickshell','--no-color','--path',str(config)],env=env,stdout=ql,stderr=ql);processes.append(qs)
                keyboard=Keyboard(runtime,display)
                time.sleep(.7)
                def ipc(method,*args):
                    return subprocess.check_output(['quickshell','ipc','--pid',str(qs.pid),'call','toolsTest',method,*map(str,args)],env=env,text=True).strip()
                def state():return json.loads(ipc('state'))
                ipc('action','volume-up');time.sleep(.1)
                assert state()['shown'] and abs(state()['value']-.45)<.001,state()
                ipc('action','volume-down');ipc('action','mute');assert state()['muted']
                ipc('action','mic-mute');assert state()['title']=='Microfono' and state()['muted']
                ipc('action','mic-up');assert abs(state()['value']-.65)<.001
                assert state()['rank']==['Firefox']
                ipc('openApps');time.sleep(.5)
                assert state()['apps']==['Alpha Fixture','Beta Fixture'],state()
                subprocess.run(['grim',str(work/'launcher.png')],env=env,check=True)
                keyboard.key(108);assert state()['index']==1,state()
                keyboard.key(103);assert state()['index']==0
                keyboard.key(1);assert not state()['appsOpen']
                ipc('openApps');time.sleep(.3);keyboard.key(30) # a: case-insensitive matching
                assert state()['apps']==['Alpha Fixture','Beta Fixture']
                ipc('query','ALPHA');time.sleep(.1);assert state()['apps']==['Alpha Fixture']
                keyboard.key(28);time.sleep(.3);assert (work/'launched').exists() and not state()['appsOpen']
                def copy(text,sensitive=False):
                    subprocess.run(['wl-copy',*(['--sensitive'] if sensitive else []),'--type','text/plain'],input=text.encode(),env=env,check=True);time.sleep(.2)
                copy('First full text\nsecond line');copy('Second text');copy('password-test',True)
                ipc('openClips');time.sleep(.3)
                assert state()['clipCount']==2,state()
                ipc('query','FIRST');time.sleep(.2);assert state()['clipCount']==1
                keyboard.key(28);time.sleep(.3)
                assert subprocess.check_output(['wl-paste','--no-newline'],env=env)==b'First full text\nsecond line'
                ipc('openClips');time.sleep(.2);ipc('clear');time.sleep(.2);assert state()['clipCount']==0
                keyboard.key(1);assert not state()['clipsOpen']
                keyboard.pointer(100, 100)
                # A harmless real focused window supplies compositor geometry.
                kitty=subprocess.Popen(['/usr/bin/kitty','--app-id','fixture-terminal','/usr/bin/sleep','30'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);processes.append(kitty)
                time.sleep(.6)
                def swaycmd(cmd):subprocess.run(['swaymsg',cmd],env=env,check=True,stdout=subprocess.DEVNULL)
                for mode in ('output','window'):
                    subprocess.run([str(ROOT/'bin/workstation-screenshot'),mode],env=env,check=True,stdout=subprocess.DEVNULL)
                    assert subprocess.check_output(['wl-paste','--type','image/png'],env=env).startswith(b'\x89PNG')
                before=list((home/'Pictures/Screenshots').glob('*.png'))
                cancel=subprocess.Popen([str(ROOT/'bin/workstation-screenshot'),'area'],env=env,stdout=subprocess.DEVNULL)
                time.sleep(.3);keyboard.key(1);assert cancel.wait(timeout=4)==0
                assert before==list((home/'Pictures/Screenshots').glob('*.png'))
                area=subprocess.Popen([str(ROOT/'bin/workstation-screenshot'),'area'],env=env,stdout=subprocess.DEVNULL)
                time.sleep(.3)
                keyboard.pointer(100,100);keyboard.pointer(pressed=True)
                keyboard.pointer(400,300);keyboard.pointer(pressed=False)
                assert area.wait(timeout=4)==0
                assert len(list((home/'Pictures/Screenshots').glob('*.png')))==3
                def focused():
                    from importlib.machinery import SourceFileLoader
                    module = SourceFileLoader('screenshot_probe', str(ROOT/'bin/workstation-screenshot')).load_module()
                    tree = json.loads(subprocess.check_output(['swaymsg','-r','-t','get_tree'],env=env))
                    return next(n['id'] for n in module.nodes(tree) if n.get('focused'))
                focus = focused()
                ipc('action','volume-up');time.sleep(.15)
                assert focused() == focus, 'OSD stole focus'

                subprocess.run(['grim',str(work/'osd.png')],env=env,check=True)
                from PIL import Image
                image = Image.open(work/'osd.png').convert('RGB')
                outputs = json.loads(subprocess.check_output(['swaymsg','-r','-t','get_outputs'],env=env))
                hits = 0
                for output in outputs:
                    rect = output['rect']
                    point = (rect['x']+rect['width']//2-140, rect['y']+rect['height']-round(rect['height']*.12)-72+10)
                    hits += image.getpixel(point) == (232,137,35)
                assert hits == 1, ('OSD missing or duplicated', hits)
                time.sleep(1.8);assert not state()['shown']
                print('OK desktop runtime: OSD, app search/invalid/navigation/Enter/Esc/launch, sensitive clipboard/history/search/copy/clear, screenshots output/window/area/cancel')
            finally:
                if keyboard:keyboard.close()
                for process in reversed(processes):
                    if process.poll() is None:process.terminate()
                    process.wait(timeout=5)
                output=(work/'qml.log').read_text()
                print(output)
                if os.environ.get('WORKSTATION_KEEP_DESKTOP_TEST'):
                    shutil.copytree(work,'/tmp/workstation-desktop-test',dirs_exist_ok=True,ignore=shutil.ignore_patterns('runtime'))
        assert not any(token in output for token in ('ERROR','TypeError','ReferenceError','Binding loop')),output


if __name__=='__main__':main()
