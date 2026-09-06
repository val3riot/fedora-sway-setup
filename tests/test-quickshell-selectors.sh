#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if /usr/bin/python3 -c 'import gi; gi.require_version("NM", "1.0")' 2>/dev/null; then
  PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 "$ROOT_DIR/tests/test-quickshell-wifi.py"
  PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 "$ROOT_DIR/tests/test-bluetooth-auth.py"
else
  printf '%s\n' 'SKIP Wi-Fi mock integration: libnm assente'
fi
if ! command -v quickshell >/dev/null; then
  printf '%s\n' 'SKIP native QML selector mocks: Quickshell assente'
  exit 0
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -r "$ROOT_DIR/templates/quickshell/." "$work/"
cp "$ROOT_DIR/tests/fixtures/quickshell/selectors.qml" "$work/shell.qml"
if ! env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen WORKSTATION_QUICKSHELL_TEST=1 timeout 15 quickshell --no-color --path "$work" > "$work/log" 2>&1; then
  cat "$work/log"; exit 1
fi
cat "$work/log"
! grep -Eq 'TEST FAILED|ERROR|TypeError|ReferenceError|non-bindable|Binding loop' "$work/log"
grep -q 'TEST selectors OK' "$work/log"
if command -v sway >/dev/null && command -v grim >/dev/null &&
   /usr/bin/python3 -c 'from PIL import Image' 2>/dev/null; then
  /usr/bin/python3 "$ROOT_DIR/tests/test-bluetooth-popup.py"
else
  echo 'SKIP rendering popup Bluetooth: richiesti Sway, grim e Pillow'
fi
