#!/usr/bin/env python3
"""Install the small desktop helpers after a complete non-destructive preflight."""
from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parents[1]
LEGACY_LOCK = '''#!/usr/bin/env bash
set -Eeuo pipefail

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/workstation-setup/theme"
[[ -r "$state_file" ]] && read -r theme < "$state_file" || theme=dark
[[ "$theme" == light ]] && color=f4f0e6 || color=1a1b26
exec swaylock -f -c "$color"
'''


def plan(home):
    files = [('bin/workstation-shell', '.local/bin/workstation-shell', 0o755),
             ('bin/workstation-screenshot', '.local/bin/workstation-screenshot', 0o755),
             ('bin/workstation-lock', '.local/bin/workstation-lock', 0o755),
             ('templates/swaylock/config', '.config/swaylock/config', 0o644),
             ('templates/sway/config.d/92-desktop-tools.conf', '.config/sway/config.d/92-desktop-tools.conf', 0o644)]
    changes = []
    for source, destination, mode in files:
        source, target = ROOT / source, home / destination
        content = source.read_text()
        marker = next(line for line in content.splitlines() if line.startswith('# workstation-setup:'))
        if target.is_symlink(): raise ValueError('Symlink personale da preservare: ' + str(target))
        if target.exists() and marker not in target.read_text() and not (target.name == 'workstation-lock' and target.read_text() == LEGACY_LOCK):
            raise ValueError('Configurazione personale da preservare: ' + str(target))
        changes.append((target, content, mode))
    return changes


def apply(home, changes):
    backup = home / '.config/workstation-setup/backups/desktop-tools'
    for target, content, mode in changes:
        if target.exists() and target.read_text() == content: continue
        if target.exists():
            backup.mkdir(parents=True, exist_ok=True)
            saved = backup / (target.parent.name + '-' + target.name)
            if not saved.exists(): shutil.copy2(target, saved)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        target.chmod(mode)


if __name__ == '__main__':
    apply(Path.home(), plan(Path.home()))
