#!/usr/bin/env python3
"""Plan all changes before writing. Only migrate recognized managed Sway files."""
import argparse
import os
from pathlib import Path
import re
import shutil
import sys

MARKER = '# workstation-setup: managed quickshell bar'
DROPIN = MARKER + '\nexec_always --no-startup-id systemctl --user start workstation-bar.service\n'
DIRECT = re.compile(r'^\s*exec(?:_always)?\s+(?:--no-startup-id\s+)?waybar\s*$')
START = re.compile(r'^\s*(?:exec(?:_always)?\b.*\b(?:waybar|quickshell|qs)\b|bar\s*(?:\{|\w)|swaybar_command\b)')


def plan(home, source):
    config = home / '.config/sway/config'
    if not config.is_file() or (config.is_symlink() and 'dotfiles' not in str(config.resolve())):
        raise ValueError('Serve una configurazione Sway managed regolare; eseguire prima --sway.')
    # Do not compete with independently enabled user services/autostart apps.
    for wants in (home / '.config/systemd/user').glob('*.wants'):
        for unit in wants.glob('*.service'):
            if unit.is_file() and unit.name != 'workstation-bar.service':
                if re.search(r'^ExecStart=.*\b(?:waybar|quickshell)\b', unit.read_text(), re.M):
                    raise ValueError('Autostart barra esterno da disabilitare: ' + str(unit))
    for directory in (home / '.config/autostart', Path('/etc/xdg/autostart')):
        for desktop in directory.glob('*.desktop'):
            entry = desktop.read_text()
            if 'Hidden=true' not in entry and re.search(r'^Exec=.*\b(?:waybar|quickshell)\b', entry, re.M):
                raise ValueError('Autostart barra esterno da disabilitare: ' + str(desktop))
    text = config.read_text()
    if '# workstation-setup: managed sway config' not in text.splitlines():
        raise ValueError('Configurazione Sway personale: migrazione automatica rifiutata.')
    dropdir = config.parent / 'config.d'
    drop = dropdir / '90-bar.conf'
    if drop.is_symlink() or (drop.exists() and drop.read_text().strip() and drop.read_text() != DROPIN):
        raise ValueError('90-bar.conf personale: migrazione rifiutata, nessun file modificato.')
    # Follow only known includes. An unknown include can hide another bar; fail
    # closed instead of commenting out arbitrary personal startup commands.
    def inspect(lines, main=False):
        for line in lines:
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue
            if main and DIRECT.fullmatch(line):
                continue
            if START.search(line):
                raise ValueError('Avvio barra non riconosciuto: ' + line)
            if stripped.startswith('include '):
                target = stripped[8:].strip()
                known = ('/etc/sway/config', '/etc/sway/config.d/*',
                         '~/.config/sway/config.d/*', '~/.config/sway/config.d/*.conf',
                         '~/.config/sway/config.d/90-bar.conf', '~/.config/sway/config.d/95-notifications.conf')
                if not main or target not in known:
                    raise ValueError('Include personale da verificare prima della migrazione: ' + target)
    inspect(text.splitlines(), main=True)
    for file in sorted(dropdir.glob('*')):
        if file != drop and file.is_file():
            inspect(file.read_text().splitlines())
    # Fedora's 90-bar.conf is suppressed by the user file via layered-include.
    # Direct /etc includes cannot be suppressed that way: reject bar definitions.
    system_dirs = [Path('/etc/sway/config.d')]
    if 'include /etc/sway/config\n' in text:
        fedora = Path('/etc/sway/config')
        if not fedora.exists() or 'layered-include' not in fedora.read_text():
            raise ValueError('Configurazione Fedora senza layered-include: verificare manualmente gli avvii barra.')
        system_dirs.append(Path('/usr/share/sway/config.d'))
    for directory in system_dirs:
        for file in directory.glob('*.conf'):
            if file.name == '90-bar.conf' and directory == Path('/usr/share/sway/config.d'):
                continue
            if directory == Path('/usr/share/sway/config.d') and (dropdir / file.name).exists():
                continue
            # System snippets can have dynamic includes unrelated to the bar.
            if any(START.search(line) for line in file.read_text().splitlines()):
                raise ValueError('Avvio barra in configurazione di sistema: ' + str(file))
    lines = [('# workstation-setup: Waybar gestita da 90-bar.conf' if DIRECT.fullmatch(line) else line)
             for line in text.splitlines()]
    if not any(line.strip() in ('include ~/.config/sway/config.d/*',
                                 'include ~/.config/sway/config.d/*.conf',
                                 'include ~/.config/sway/config.d/90-bar.conf',
                                 'include /etc/sway/config') for line in lines):
        lines.append('include ~/.config/sway/config.d/90-bar.conf')
    destination = home / '.config/quickshell/workstation'
    manifest = destination / '.workstation-managed'
    previous = {}
    if destination.exists():
        if (destination.is_symlink() and 'dotfiles' not in str(destination.resolve())) or \
           (manifest.is_symlink() and 'dotfiles' not in str(manifest.resolve())):
            raise ValueError('Directory Quickshell personale: non verrà sovrascritta.')
        if manifest.is_file():
            import json
            previous = json.loads(manifest.read_text())
    import hashlib
    files = {str(f.relative_to(source)): f for f in source.rglob('*') if f.is_file() and '__pycache__' not in f.parts}
    for name, file in files.items():
        target = destination / name
        if target.is_symlink():
            if 'dotfiles' not in str(target.resolve()):
                raise ValueError('Symlink nella configurazione: ' + str(target))
            continue
        if target.exists():
            digest = hashlib.sha256(target.read_bytes()).hexdigest()
            if digest != previous.get(name) and target.read_bytes() != file.read_bytes():
                raise ValueError('Modifiche QML personali da preservare: ' + str(target))
    import importlib.util
    spec = importlib.util.spec_from_file_location('notifications_config', Path(__file__).with_name('workstation-notifications.py'))
    notifications = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(notifications)
    content, notification_changes = notifications.plan(home, '\n'.join(lines) + '\n')
    return config, content, drop, destination, files, notifications, notification_changes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--home', type=Path, default=Path.home())
    repo_root = Path(__file__).resolve().parents[1]
    default_source = repo_root / 'dotfiles/quickshell/.config/quickshell/workstation'
    if not default_source.exists():
        default_source = repo_root / 'templates/quickshell'
    parser.add_argument('--source', type=Path, default=default_source)
    args = parser.parse_args()
    if os.environ.get('XDG_CONFIG_HOME', str(args.home / '.config')) != str(args.home / '.config'):
        raise ValueError('Il profilo Sway corrente usa ~/.config; XDG_CONFIG_HOME alternativo non supportato.')
    config, content, drop, destination, files, notifications, notification_changes = plan(args.home, args.source)
    import importlib.util
    spec = importlib.util.spec_from_file_location('desktop_tools', Path(__file__).with_name('configure-desktop-tools.py'))
    desktop_tools = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(desktop_tools)
    desktop_changes = desktop_tools.plan(args.home)
    if args.check:
        return
    import hashlib
    import json
    backup = config.with_name('config.pre-quickshell.bak')
    if not backup.exists():
        shutil.copy2(config, backup)
    notification_backup = config.with_name('config.pre-notifications.bak')
    if not notification_backup.exists():
        shutil.copy2(config, notification_backup)
    destination.mkdir(parents=True, exist_ok=True)
    hashes = {}
    for name, source in files.items():
        target = destination / name
        if target.is_symlink() and 'dotfiles' in str(target.resolve()):
            hashes[name] = hashlib.sha256(source.read_bytes()).hexdigest()
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        hashes[name] = hashlib.sha256(source.read_bytes()).hexdigest()
    (destination / '.workstation-managed').write_text(json.dumps(hashes, sort_keys=True, indent=2) + '\n')
    drop.parent.mkdir(parents=True, exist_ok=True)
    drop.write_text(DROPIN)
    desktop_tools.apply(args.home, desktop_changes)
    notifications.apply(notification_changes)
    if not (config.is_symlink() and 'dotfiles' in str(config.resolve())):
        config.write_text(content)
    state = args.home / '.config/workstation-setup/bar'
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text('quickshell\n')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        sys.exit(str(error))
