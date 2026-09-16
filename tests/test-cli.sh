#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

help_output="$("$ROOT_DIR/install.sh" --help)"
grep -Fq -- '--no-quickshell' <<<"$help_output"
grep -Fq -- '--dry-run' <<<"$help_output"
grep -Fq -- '--doctor' <<<"$help_output"
grep -Fq -- '--set-wallpaper' <<<"$help_output"
grep -Fq 'workstation-tools' <<<"$help_output"
[[ "$("$ROOT_DIR/install.sh" --info)" == "$help_output" ]]
[[ "$("$ROOT_DIR/install.sh" -h)" == "$help_output" ]]

# Test dry-run default
dry_run_default="$("$ROOT_DIR/install.sh" --dry-run)"
grep -Fq '75-sway-desktop.sh' <<<"$dry_run_default"
grep -Fq '76-quickshell.sh' <<<"$dry_run_default"
grep -Fq '20-shell.sh' <<<"$dry_run_default"

# Test dry-run without quickshell
dry_run_no_qs="$("$ROOT_DIR/install.sh" --dry-run --no-quickshell)"
grep -Fq '75-sway-desktop.sh' <<<"$dry_run_no_qs"
! grep -Fq '76-quickshell.sh' <<<"$dry_run_no_qs"

# Test invalid flag
if "$ROOT_DIR/install.sh" --unsupported-flag >/dev/null 2>&1; then
  printf '%s\n' 'FAIL atteso errore su opzione non valida' >&2
  exit 1
fi

# Ensure removed monolithic flags are not present in help
! grep -Eq -- '--all|--dev|--agent|--extra|--gnome' <<<"$help_output"

# Moduli e logiche di completamento
grep -Fq 'warn "Modulo fallito, il setup continua: $module_name"' "$ROOT_DIR/install.sh"
grep -Fq "printf 'SUCCESS (%d)" "$ROOT_DIR/install.sh"
grep -Fq "printf 'FAILED (%d)" "$ROOT_DIR/install.sh"
grep -Fq 'timedatectl set-timezone Europe/Rome' "$ROOT_DIR/modules/10-system-packages.sh"
grep -Fq 'timedatectl set-ntp true' "$ROOT_DIR/modules/10-system-packages.sh"

printf '%s\n' 'OK   CLI desktop install.sh (--help, --info, --dry-run, --no-quickshell)'
