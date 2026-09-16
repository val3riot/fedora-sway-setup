#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/bin/check-setup.sh"
find "$ROOT_DIR" -type f \( -name '*.sh' -o -path "$ROOT_DIR/bin/laptop-power-mode" -o -path "$ROOT_DIR/bin/stow-dotfiles" \) \
  -not -path "$ROOT_DIR/.git/*" -print0 | xargs -0 shellcheck --severity=warning

for test_script in "$ROOT_DIR"/tests/test-*.sh; do
  printf '=== Running %s ===\n' "${test_script##*/}"
  bash "$test_script"
done

if [[ -f "$ROOT_DIR/bin/test-quickshell-runtime.py" ]] && command -v sway >/dev/null 2>&1 && command -v quickshell >/dev/null 2>&1; then
  python3 "$ROOT_DIR/bin/test-quickshell-runtime.py"
fi

"$ROOT_DIR/bin/check-secrets.sh"
"$ROOT_DIR/bin/audit-urls.sh"
git -C "$ROOT_DIR" diff --check
printf '%s\n' 'OK   suite repository completa'
