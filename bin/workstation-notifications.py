#!/usr/bin/env python3
# workstation-setup: managed notification controller
"""Plan notification autostart migration; switch daemons only on explicit invocation."""
import argparse
import importlib.util
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

MARKER = '# workstation-setup: managed notifications'
MAKO = re.compile(r'^\s*exec(?:_always)?\s+(?:--no-startup-id\s+)?mako\s*$')
DAEMON = re.compile(r'\b(?:mako|dunst)\b')
MASK = object()


def plan(home, content, mode=None):
    if '# workstation-setup: managed sway config' not in content.splitlines():
        raise ValueError('Configurazione Sway personale: migrazione notifiche rifiutata.')
    selection = home / '.config/workstation-setup/notifications'
    mode = mode or (selection.read_text().strip() if selection.exists() else 'quickshell')
    if mode not in ('quickshell', 'mako'):
        raise ValueError('Backend notifiche non valido.')
    if selection.is_symlink():
        raise ValueError('Selettore notifiche symlink da preservare.')
    lines = []
    for line in content.splitlines():
        if MAKO.fullmatch(line):
            lines.append('# workstation-setup: Mako gestito da 95-notifications.conf')
        elif not line.lstrip().startswith('#') and re.match(r'\s*exec', line) and DAEMON.search(line):
            raise ValueError('Autostart notifiche non riconosciuto nel config Sway.')
        else:
            lines.append(line)
    include = 'include ~/.config/sway/config.d/95-notifications.conf'
    if not any(line.strip() in ('include /etc/sway/config', 'include ~/.config/sway/config.d/*',
                               'include ~/.config/sway/config.d/*.conf', include) for line in lines):
        lines.append(include)
    # Do not guess at personal launchers or modify unrelated snippets/autostarts.
    for directory in (home / '.config/sway/config.d', Path('/etc/sway/config.d'), Path('/usr/share/sway/config.d')):
        for file in directory.glob('*.conf'):
            if file.name == '95-notifications.conf' and directory == home / '.config/sway/config.d':
                continue
            if any(not line.lstrip().startswith('#') and re.match(r'\s*exec', line) and DAEMON.search(line)
                   for line in file.read_text().splitlines()):
                raise ValueError('Avvio notifiche esterno da riconciliare: ' + str(file))
    for directory in (home / '.config/autostart', Path('/etc/xdg/autostart')):
        for file in directory.glob('*.desktop'):
            text = file.read_text()
            if 'Hidden=true' not in text and any(line.startswith('Exec=') and DAEMON.search(line) for line in text.splitlines()):
                raise ValueError('Autostart notifiche desktop da disabilitare: ' + str(file))
    changes = {
        selection: mode + '\n',
        home / '.config/sway/config.d/95-notifications.conf': MARKER + '\n' +
            ('exec --no-startup-id systemctl --user start mako.service\n' if mode == 'mako' else '# Quickshell owns org.freedesktop.Notifications\n'),
        home / '.local/share/dbus-1/services/org.freedesktop.Notifications.service': MARKER + '\n[D-BUS Service]\nName=org.freedesktop.Notifications\n' +
            ('Exec=/usr/bin/mako\nSystemdService=mako.service\n' if mode == 'mako' else
             'Exec=/usr/bin/false\nSystemdService=workstation-notifications-disabled.service\n'),
        home / '.config/systemd/user/mako.service': MASK if mode == 'quickshell' else None,
        home / '.config/systemd/user/dunst.service': MASK,
        home / '.config/systemd/user/workstation-notifications-disabled.service': MASK,
        home / '.local/bin/workstation-notifications.py': Path(__file__).read_text(),
    }
    for target, value in changes.items():
        if target.is_symlink():
            if target.parent != home / '.config/systemd/user' or os.readlink(target) != '/dev/null':
                raise ValueError('Symlink personale da preservare: ' + str(target))
        elif target.exists() and target != selection:
            expected_marker = '# workstation-setup: managed notification controller' if target.name == 'workstation-notifications.py' else MARKER
            if not target.is_file() or expected_marker not in target.read_text():
                raise ValueError('File notifiche personale da preservare: ' + str(target))
        if any(p.is_symlink() for p in target.parents if p != home):
            raise ValueError('Directory notifiche symlink da preservare: ' + str(target))
    return '\n'.join(lines) + '\n', changes


def apply(changes):
    for target, value in changes.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        if value is MASK:
            if not target.is_symlink():
                target.symlink_to('/dev/null')
        elif value is None:
            target.unlink(missing_ok=True)
        else:
            target.write_text(value)
            if target.name == 'workstation-notifications.py':
                target.chmod(0o755)


def check(home):
    config = home / '.config/sway/config'
    content, changes = plan(home, config.read_text())
    if content != config.read_text():
        raise ValueError('Mako ancora configurato nel file Sway.')
    for target, value in changes.items():
        if target.name == 'workstation-notifications.py':
            continue  # Controller version can be upgraded by the setup.
        if value is MASK:
            valid = target.is_symlink() and os.readlink(target) == '/dev/null'
        elif value is None:
            valid = not target.exists() and not target.is_symlink()
        else:
            valid = target.is_file() and target.read_text() == value
        if not valid:
            raise ValueError('Configurazione notifiche incoerente: ' + str(target))


def runtime_owner(home):
    path = home / '.config/quickshell/workstation/services/notification-bus.py'
    spec = importlib.util.spec_from_file_location('notification_bus', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.owner(module.Gio.bus_get_sync(module.Gio.BusType.SESSION, None))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['quickshell', 'mako', 'doctor'])
    args = parser.parse_args()
    home = Path.home()
    if args.mode == 'doctor':
        check(home)
        state = runtime_owner(home)
        mode = (home / '.config/workstation-setup/notifications').read_text().strip()
        expected = '/usr/bin/quickshell' if mode == 'quickshell' else '/usr/bin/mako'
        if not state['known'] or state['executable'] != expected:
            raise ValueError('Ownership notifiche inattesa: ' + (state['executable'] or 'nessun daemon'))
        if mode == 'quickshell':
            command = Path('/proc', str(state['pid']), 'cmdline').read_bytes().split(b'\0')
            if os.fsencode(home / '.config/quickshell/workstation') not in command:
                raise ValueError('Il notification owner è una configurazione Quickshell diversa.')
        print('OK   Notifications owner:', expected, 'PID', state['pid'])
        return
    config = home / '.config/sway/config'
    content, changes = plan(home, config.read_text(), args.mode)
    state = runtime_owner(home)
    if not state['known']:
        raise ValueError('Ownership notifiche non verificabile: migrazione interrotta.')
    if state['pid'] and state['executable'] not in ('/usr/bin/mako', '/usr/bin/quickshell'):
        raise ValueError('Un altro daemon occupa il bus: ' + state['executable'])
    if state['executable'] == '/usr/bin/quickshell':
        cmd = Path('/proc', str(state['pid']), 'cmdline').read_bytes().split(b'\0')
        if os.fsencode(home / '.config/quickshell/workstation') not in cmd:
            raise ValueError('Un’altra configurazione Quickshell occupa il bus.')
    subprocess.run(['systemctl', '--user', 'stop', 'workstation-bar.service'], check=True)
    try:
        # Explicit migration only: terminate the verified Mako bus owner, never pkill.
        if state['executable'] == '/usr/bin/mako':
            fd = os.pidfd_open(state['pid'])
            try:
                if runtime_owner(home)['pid'] == state['pid']:
                    signal.pidfd_send_signal(fd, signal.SIGTERM)
            finally:
                os.close(fd)
        backup = config.with_name('config.pre-notifications.bak')
        if not backup.exists():
            shutil.copy2(config, backup)
        apply(changes)
        config.write_text(content)
        subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
        # dbus-broker notices service-directory changes; ReloadConfig is explicit too.
        subprocess.run(['busctl', '--user', 'call', 'org.freedesktop.DBus', '/org/freedesktop/DBus',
                        'org.freedesktop.DBus', 'ReloadConfig'], check=True)
        time.sleep(1)
        if args.mode == 'mako':
            subprocess.run(['systemctl', '--user', 'start', 'mako.service'], check=True)
    finally:
        subprocess.run(['systemctl', '--user', 'start', 'workstation-bar.service'], check=True)
    expected = '/usr/bin/quickshell' if args.mode == 'quickshell' else '/usr/bin/mako'
    for _ in range(50):
        if runtime_owner(home)['executable'] == expected:
            print('OK   Backend notifiche:', args.mode)
            return
        time.sleep(0.1)
    raise ValueError('Daemon notifiche non avviato: controllare journal e doctor. Nessun fallback automatico.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
