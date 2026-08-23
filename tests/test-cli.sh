#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

help_output="$("$ROOT_DIR/install.sh" --help)"
grep -Fq '  --all' <<<"$help_output"
grep -Fq '  --gnome-desktop' <<<"$help_output"
grep -Fq '  --sway-desktop' <<<"$help_output"
grep -Fq './install.sh --development --sway-desktop' <<<"$help_output"
grep -Fq 'Super+G' <<<"$help_output"
grep -Fq -- '--config-zsh-theme' <<<"$help_output"
grep -Fq 'INSTALL_AGENTS=true in config/local.env' <<<"$help_output"
grep -Fq './bin/provenance-audit.sh' <<<"$help_output"
grep -Fq 'Versioni, fonti e checksum: config/sources.env' <<<"$help_output"
[[ "$("$ROOT_DIR/install.sh" --info)" == "$help_output" ]]

grep -Fq 'Log installazione:' "$ROOT_DIR/install.sh"
grep -Fq 'module_percent=$((module_index * 100 / module_total))' "$ROOT_DIR/install.sh"
grep -Fq 'Dettagli nel log: $LOG_FILE' "$ROOT_DIR/install.sh"

printf '%s\n' 'OK   CLI --help/--info'
