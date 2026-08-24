#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

help_output="$("$ROOT_DIR/install.sh" --help)"
grep -Fq '  --all' <<<"$help_output"
grep -Fq '  --dev' <<<"$help_output"
grep -Fq '  --agent' <<<"$help_output"
grep -Fq '  --sway' <<<"$help_output"
grep -Fq '  --gnome' <<<"$help_output"
grep -Fq 'GNOME/Sway non impliciti' <<<"$help_output"
grep -Fq './bin/provenance-audit.sh' <<<"$help_output"
grep -Fq 'versioni e checksum: config/versions.env' <<<"$help_output"
[[ "$("$ROOT_DIR/install.sh" --info)" == "$help_output" ]]

grep -Fq 'PROFILE=all; INSTALL_BASE=true; INSTALL_DEV=true; INSTALL_APPS=true; INSTALL_AGENTS=true' \
  "$ROOT_DIR/install.sh"
grep -Fq '45-agents.sh) [[ "$INSTALL_AGENTS" == true ]]' "$ROOT_DIR/install.sh"
grep -Fq '75-sway-desktop.sh) [[ "$DESKTOP_ENV" == sway ]]' "$ROOT_DIR/install.sh"
grep -Fq '76-gnome-desktop.sh) [[ "$DESKTOP_ENV" == gnome ]]' "$ROOT_DIR/install.sh"
grep -Fq 'warn "Modulo fallito, il setup continua: $module_name"' "$ROOT_DIR/install.sh"
grep -Fq "printf 'SUCCESS (%d)" "$ROOT_DIR/install.sh"
grep -Fq "printf 'FAILED (%d)" "$ROOT_DIR/install.sh"

printf '%s\n' 'OK   CLI --help/--info'
