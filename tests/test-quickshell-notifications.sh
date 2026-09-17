#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v quickshell >/dev/null || { echo 'SKIP notification QML mocks: Quickshell assente'; exit 0; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
qs_src="$ROOT_DIR/dotfiles/quickshell/.config/quickshell/workstation"
[[ -d "$qs_src" ]] || qs_src="$ROOT_DIR/templates/quickshell"
cp -r "$qs_src/." "$work/"
cp "$ROOT_DIR/tests/fixtures/quickshell/notifications.qml" "$work/shell.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen WORKSTATION_QUICKSHELL_TEST=1 timeout 10 quickshell --no-color --path "$work" > "$work/log" 2>&1 || { cat "$work/log"; exit 1; }
cat "$work/log"
! grep -Eq 'ERROR|TEST FAILED|TypeError|ReferenceError|Binding loop' "$work/log"
grep -q 'TEST notifications OK' "$work/log"
if command -v dbus-run-session >/dev/null && command -v notify-send >/dev/null &&
   /usr/bin/python3 -c 'from gi.repository import Gio, GLib' 2>/dev/null; then
  /usr/bin/python3 "$ROOT_DIR/tests/test-notification-protocol.py"
else
  echo 'SKIP protocollo notifiche: richiesti dbus-run-session, notify-send e Python Gio'
fi
