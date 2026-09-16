#!/usr/bin/env python3
"""Keep system-settings floating rules; retire the managed Cliamp widget layout."""
import argparse
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def configure(home):
    directory = home / '.config/sway/config.d'
    changes = []
    for name in ('60-policykit-window.conf', '61-desktop-app-windows.conf', '62-system-utilities.conf'):
        source = ROOT / 'dotfiles/sway/.config/sway/config.d' / name
        if not source.exists():
            source = ROOT / 'templates/sway/config.d' / name
        target = directory / name
        content = source.read_text()
        if target.is_symlink():
            if 'dotfiles' not in str(target.resolve()):
                raise ValueError('Regola Sway personale da preservare: ' + str(target))
            continue
        if target.exists() and not target.read_text().startswith(content.splitlines()[0] + "\n"):
            raise ValueError('Regola Sway personale da preservare: ' + str(target))
        changes.append((target, content, False))
    utility = home / '.local/bin/workstation-system-tool'
    if utility.is_symlink():
        if 'dotfiles' not in str(utility.resolve()):
            raise ValueError('Launcher utility personale da preservare: ' + str(utility))
    elif utility.exists() and '# workstation-setup: managed system utility launcher' not in utility.read_text():
        raise ValueError('Launcher utility personale da preservare: ' + str(utility))
    else:
        src_util = ROOT / 'dotfiles/scripts/.local/bin/workstation-system-tool'
        if not src_util.exists(): src_util = ROOT / 'bin/workstation-system-tool'
        changes.append((utility, src_util.read_text(), True))
    old_rule = directory / '65-cliamp.conf'
    if old_rule.exists() or old_rule.is_symlink():
        if old_rule.is_symlink() or old_rule.read_text() != ('# workstation-setup: managed Cliamp widget rule\n'
            'for_window [app_id="^cliamp-widget$"] floating enable, border pixel 1, resize set width 920 height 640, move position center\n'):
            raise ValueError('Regola Cliamp non riconosciuta: ' + str(old_rule))
        changes.append((old_rule, None, False))
    launcher = home / '.local/bin/cliamp-widget'
    if launcher.exists():
        old = launcher.read_text()
        if launcher.is_symlink():
            if 'dotfiles' not in str(launcher.resolve()):
                raise ValueError('Launcher Cliamp personale da preservare: ' + str(launcher))
        elif not ('# workstation-setup: managed Cliamp launcher' in old or
            ('--class cliamp-widget' in old and '.scratchpad_state' in old)):
            raise ValueError('Launcher Cliamp personale da preservare: ' + str(launcher))
        else:
            src_launcher = ROOT / 'dotfiles/scripts/.local/bin/cliamp-widget'
            if not src_launcher.exists(): src_launcher = ROOT / 'bin/cliamp-widget'
            changes.append((launcher, src_launcher.read_text(), True))
    # Preflight above is complete before any mutation. Backups stay outside Sway includes.
    backup = home / '.config/workstation-setup/backups/sway-windows'
    for target, content, executable in changes:
        if target.is_symlink() and 'dotfiles' in str(target.resolve()): continue
        if target.exists() and (content is None or target.read_text() != content):
            backup.mkdir(parents=True, exist_ok=True)
            if not (backup / target.name).exists():
                shutil.copy2(target, backup / target.name)
        if content is None:
            target.unlink()
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
            if executable:
                target.chmod(0o755)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--home', type=Path, default=Path.home())
    args = parser.parse_args()
    try:
        configure(args.home)
    except (ValueError, OSError) as error:
        parser.exit(1, str(error) + '\n')
