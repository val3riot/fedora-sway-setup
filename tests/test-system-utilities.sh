#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 "$ROOT_DIR/tests/test-system-utilities.py"
if ! command -v quickshell >/dev/null; then
  echo 'SKIP markup QML: Quickshell assente'; exit 0
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
qs_src="$ROOT_DIR/dotfiles/quickshell/.config/quickshell/workstation"
[[ -d "$qs_src" ]] || qs_src="$ROOT_DIR/templates/quickshell"
cp -r "$qs_src/." "$work/"
cp "$ROOT_DIR/tests/fixtures/quickshell/markup.qml" "$work/shell.qml"
if ! env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen WORKSTATION_QUICKSHELL_TEST=1 timeout 10 quickshell --no-color --path "$work" > "$work/log" 2>&1; then
  cat "$work/log"; exit 1
fi
cat "$work/log"
! grep -Eq 'TEST FAILED|ERROR|TypeError|ReferenceError' "$work/log"
grep -q 'TEST markup OK' "$work/log"
