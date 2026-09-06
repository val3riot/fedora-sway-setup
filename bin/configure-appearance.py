#!/usr/bin/env python3
"""Standard desktop appearance settings; preserve unrelated user preferences."""
import argparse
import configparser
import io
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
INTERFACE = {
    'color-scheme': 'prefer-dark', 'gtk-theme': 'Adwaita',  # Built-in theme + dark variant, not a missing Adwaita-dark directory.
    'icon-theme': 'Adwaita', 'cursor-theme': 'Adwaita', 'cursor-size': 24,
    'font-name': 'Adwaita Sans 11', 'monospace-font-name': 'Cascadia Mono NF 11',
    'accent-color': 'orange',
}
GTK = {
    'gtk-application-prefer-dark-theme': 'true', 'gtk-theme-name': INTERFACE['gtk-theme'],
    'gtk-icon-theme-name': INTERFACE['icon-theme'], 'gtk-cursor-theme-name': INTERFACE['cursor-theme'],
    'gtk-cursor-theme-size': str(INTERFACE['cursor-size']), 'gtk-font-name': INTERFACE['font-name'],
}
ENV = {'QT_QPA_PLATFORMTHEME': 'xdgdesktopportal', 'XCURSOR_THEME': INTERFACE['cursor-theme'], 'XCURSOR_SIZE': str(INTERFACE['cursor-size'])}


def plan(home):
    changes = []
    for version in ('3.0', '4.0'):
        path = home / f'.config/gtk-{version}/settings.ini'
        if path.is_symlink(): raise ValueError('Preservare symlink personale: ' + str(path))
        settings = configparser.ConfigParser(interpolation=None)
        if path.exists(): settings.read(path)
        if not settings.has_section('Settings'): settings.add_section('Settings')
        for key, value in GTK.items(): settings.set('Settings', key, value)
        stream = io.StringIO(); settings.write(stream)
        changes.append((path, stream.getvalue()))
    managed = {
        '.config/fontconfig/conf.d/60-workstation-fonts.conf': '<!-- workstation-setup: managed font aliases -->\n<fontconfig>\n<alias><family>sans-serif</family><prefer><family>Adwaita Sans</family></prefer></alias>\n<alias><family>monospace</family><prefer><family>Cascadia Mono NF</family></prefer></alias>\n</fontconfig>\n',
        '.config/environment.d/91-workstation-appearance.conf': '# workstation-setup: managed appearance environment\n' + ''.join(k+'='+v+'\n' for k,v in ENV.items()),
        '.config/sway/config.d/93-appearance.conf': '# workstation-setup: managed cursor\nseat * xcursor_theme '+ENV['XCURSOR_THEME']+' '+ENV['XCURSOR_SIZE']+'\n',
        '.config/sway/config.d/99-theme.conf': (ROOT/'templates/sway/config.d/99-theme.conf').read_text(),
    }
    for name, content in managed.items():
        path = home/name
        legacy_border = content.partition('\n')[2].replace('#e88923', '#ff8c00').replace('#e06c75', '#ff3b30') if name.endswith('/99-theme.conf') else None
        if path.is_symlink() or (path.exists() and not path.read_text().startswith(content.splitlines()[0]+'\n') and path.read_text() != legacy_border):
            raise ValueError('Preservare configurazione personale: ' + str(path))
        changes.append((path, content))
    return changes


def apply(home):
    changes = plan(home)
    for path, content in changes:
        if path.exists() and path.read_text() == content: continue
        backup = home/'.config/workstation-setup/backups/appearance'/path.relative_to(home)
        if path.exists() and not backup.exists():
            backup.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(path, backup)
        path.parent.mkdir(parents=True, exist_ok=True); path.write_text(content)
    for key, value in INTERFACE.items():
        subprocess.run(['gsettings', 'set', 'org.gnome.desktop.interface', key, str(value)], check=True)
    # These variables select Fedora plugins/settings; never change library paths.
    subprocess.run(['dbus-update-activation-environment', '--systemd', *[k+'='+v for k,v in ENV.items()]], check=True)


def doctor(home):
    errors = []
    for path, content in plan(home):
        if not path.exists() or path.read_text() != content: errors.append(str(path))
    for key, value in INTERFACE.items():
        actual = subprocess.check_output(['gsettings','get','org.gnome.desktop.interface',key],text=True).strip().strip("'")
        if actual != str(value): errors.append(key)
    plugin = '/usr/lib64/qt6/plugins/platformthemes/libqxdgdesktopportal.so'
    if not Path(plugin).is_file(): errors.append('Qt portal plugin absent')
    else:
        vendor = subprocess.check_output(['rpm','-qf','--qf','%{VENDOR}',plugin],text=True)
        if vendor != 'Fedora Project': errors.append('Qt portal plugin not Fedora')
    try:
        from gi.repository import Gio, GLib
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        result = bus.call_sync('org.freedesktop.portal.Desktop', '/org/freedesktop/portal/desktop',
            'org.freedesktop.portal.Settings', 'Read', GLib.Variant('(ss)', ('org.freedesktop.appearance', 'color-scheme')),
            None, Gio.DBusCallFlags.NONE, 2000, None).unpack()[0]
        if result != 1: errors.append('portal dark preference')
    except Exception: errors.append('portal Settings unavailable')
    print(('FAIL' if errors else 'OK') + ' appearance: ' + (', '.join(errors) if errors else 'GTK dark, cursor, icons, font, Qt portal, Sway'))
    return bool(errors)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check: raise SystemExit(doctor(Path.home()))
    apply(Path.home())
