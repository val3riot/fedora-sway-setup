#!/usr/bin/env bash
# Harmless loader probe: no compositor, QML or persistent bar is started.
set -Eeuo pipefail
failed=0
if rpm -q quickshell >/dev/null 2>&1; then
  printf 'OK   Quickshell installed: %s\n' "$(rpm -q quickshell)"
else
  printf 'FAIL Quickshell installed: RPM assente\n'
  failed=1
fi
executable="$(command -v quickshell || true)"
if [[ -z "$executable" || ! -x "$executable" ]]; then
  printf 'FAIL Quickshell executable: eseguibile assente\n'
  exit 1
fi
printf 'OK   Quickshell executable: %s\n' "$executable"
# --version alone can miss lazy relocations. Force resolution of all symbols.
if output="$(timeout 10 env LD_BIND_NOW=1 "$executable" --version 2>&1)"; then
  printf 'OK   Quickshell runtime-loadable: %s\n' "$output"
else
  printf 'FAIL Quickshell runtime-loadable: %s\n' "$output"
  printf 'Verificare ABI Qt/RPM e library path; confrontare con DNF Fedora prima di correggere.\n'
  failed=1
fi
if libraries="$(LC_ALL=C ldd "$executable" 2>&1)"; then
  count=0
  while read -r name arrow path rest; do
    [[ "$name" == libQt6* && "$arrow" == '=>' ]] || continue
    count=$((count + 1))
    resolved="$(readlink -f "$path" 2>/dev/null || true)"
    if [[ "$resolved" == /usr/lib64/libQt6* || "$resolved" == /usr/lib/libQt6* ]] &&
       [[ "$(rpm -qf --qf '%{VENDOR}' "$resolved" 2>/dev/null || true)" == 'Fedora Project' ]]; then
      printf 'OK   Quickshell Qt library: %s\n' "$resolved"
    else
      printf 'FAIL Quickshell Qt library: %s => %s (path/vendor non Fedora o libreria assente)\n' "$name" "$path"
      failed=1
    fi
  done <<< "$libraries"
  if [[ "$count" == 0 ]]; then
    printf 'FAIL Quickshell Qt libraries: nessuna dipendenza Qt rilevata\n'
    failed=1
  fi
else
  printf 'FAIL Quickshell Qt libraries: %s\n' "$libraries"
  failed=1
fi
exit "$failed"
