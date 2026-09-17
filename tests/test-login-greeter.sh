#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/tests/test-login-greeter.py"

printf '%s\n' 'OK   login greeter configurazione e validazione'
