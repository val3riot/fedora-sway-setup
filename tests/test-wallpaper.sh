#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/tests/test-wallpaper.py"
"$ROOT_DIR/bin/set-wallpaper.sh" --check >/dev/null
"$ROOT_DIR/bin/workstation-wallpaper" --check >/dev/null

printf '%s\n' 'OK   wallpaper engine e validazione'
