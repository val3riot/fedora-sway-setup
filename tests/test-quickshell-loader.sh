#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cat > "$work/rpm" <<'MOCK'
#!/bin/sh
case "$*" in
  *VENDOR*) printf 'Fedora Project' ;;
  *) echo quickshell-test ;;
esac
MOCK
cat > "$work/ldd" <<'MOCK'
#!/bin/sh
printf 'libQt6Core.so.6 => %s (0x123)\n' "${TEST_QT_PATH:-/usr/lib64/libQt6Core.so.6}"
MOCK
cat > "$work/quickshell" <<'MOCK'
#!/bin/sh
[ "$*" = --version ] || exit 99
[ "$LD_BIND_NOW" = 1 ] || exit 98
if [ "${TEST_ABI_FAIL:-0}" = 1 ]; then
  echo 'symbol lookup error: undefined symbol: QUntypedPropertyBinding, version Qt_6' >&2
  exit 127
fi
echo 'quickshell test'
MOCK
chmod +x "$work/"*
PATH="$work:$PATH" bash "$ROOT_DIR/bin/check-quickshell-runtime.sh" > "$work/good"
grep -q 'OK   Quickshell runtime-loadable' "$work/good"
if PATH="$work:$PATH" TEST_ABI_FAIL=1 bash "$ROOT_DIR/bin/check-quickshell-runtime.sh" > "$work/bad"; then
  echo 'FAIL ABI mismatch accepted'; exit 1
fi
grep -q 'OK   Quickshell executable' "$work/bad"
grep -q 'FAIL Quickshell runtime-loadable.*symbol lookup error' "$work/bad"
if PATH="$work:$PATH" TEST_QT_PATH=/usr/local/lib/libQt6Core.so.6 bash "$ROOT_DIR/bin/check-quickshell-runtime.sh" > "$work/external"; then
  echo 'FAIL external Qt accepted'; exit 1
fi
grep -q 'FAIL Quickshell Qt library' "$work/external"
printf '%s\n' 'OK   Quickshell loader: lazy binding, ABI failure, external Qt'
