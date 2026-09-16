#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/bin/check-setup.sh"
find "$ROOT_DIR" -type f \( -name '*.sh' -o -path "$ROOT_DIR/bin/docker-runtime" -o -path "$ROOT_DIR/bin/laptop-power-mode" -o -path "$ROOT_DIR/bin/stow-dotfiles" \) \
  -not -path "$ROOT_DIR/.git/*" -print0 | xargs -0 shellcheck --severity=warning

for test_script in "$ROOT_DIR"/tests/test-*.sh; do
  bash "$test_script"
done

"$ROOT_DIR/bin/check-secrets.sh"
"$ROOT_DIR/bin/audit-urls.sh"
git -C "$ROOT_DIR" diff --check
printf '%s\n' 'OK   suite repository completa'
