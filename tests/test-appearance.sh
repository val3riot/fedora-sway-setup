#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/tests/test-appearance.py"
python3 "$ROOT_DIR/tests/test-control-center-runtime.py"
