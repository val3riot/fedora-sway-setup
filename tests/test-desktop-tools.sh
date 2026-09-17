#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if command -v sway >/dev/null && command -v quickshell >/dev/null && command -v grim >/dev/null; then
  /usr/bin/python3 "$ROOT_DIR/tests/test-desktop-tools-runtime.py"
fi
