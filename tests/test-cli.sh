#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

help_output="$("$ROOT_DIR/install.sh" --help)"
grep -Fq '  --all' <<<"$help_output"
grep -Fq '  --dev' <<<"$help_output"
grep -Fq '  --agent' <<<"$help_output"
grep -Fq '  --extra' <<<"$help_output"
grep -Fq '  --sway' <<<"$help_output"
grep -Fq '  --gnome' <<<"$help_output"
grep -Fq 'GNOME/Sway non impliciti' <<<"$help_output"
grep -Fq './bin/provenance-audit.sh' <<<"$help_output"
grep -Fq 'versioni e checksum: config/versions.env' <<<"$help_output"
[[ "$("$ROOT_DIR/install.sh" --info)" == "$help_output" ]]

grep -Fq 'PROFILE=all; INSTALL_BASE=true; INSTALL_DEV=true; INSTALL_APPS=true; INSTALL_AGENTS=true' \
  "$ROOT_DIR/install.sh"
grep -Fq '45-agents.sh) [[ "$INSTALL_AGENTS" == true ]]' "$ROOT_DIR/install.sh"
grep -Fq '65-extra.sh) [[ "$INSTALL_EXTRA" == true ]]' "$ROOT_DIR/install.sh"
grep -Fq '75-sway-desktop.sh) [[ "$DESKTOP_ENV" == sway ]]' "$ROOT_DIR/install.sh"
grep -Fq '76-gnome-desktop.sh) [[ "$DESKTOP_ENV" == gnome ]]' "$ROOT_DIR/install.sh"
grep -Fq '[[ "$DESKTOP_ENV" != none || "$INSTALL_EXTRA" == true ]]' "$ROOT_DIR/install.sh"
grep -Fq 'PROFILE=components' "$ROOT_DIR/install.sh"
grep -Fq './install.sh --sway' "$ROOT_DIR/README.md"
grep -Fq './install.sh --extra' "$ROOT_DIR/README.md"
grep -Fq 'clic destro per chiudere il player' "$ROOT_DIR/README.md"
grep -Fq '`Dev 60%`' "$ROOT_DIR/README.md"
grep -Fq '| Cliamp | 1.63.2 |' "$ROOT_DIR/AUDIT.md"
grep -Fq 'templates/extra/cliamp.desktop' "$ROOT_DIR/modules/65-extra.sh"
grep -Fq 'Terminal=false' "$ROOT_DIR/templates/extra/cliamp.desktop"
grep -Fq 'cliamp-widget' "$ROOT_DIR/templates/extra/cliamp.desktop"
grep -Fq 'app_id="^cliamp-widget$"' "$ROOT_DIR/templates/extra/cliamp-sway.conf"
grep -Fq 'warn "Modulo fallito, il setup continua: $module_name"' "$ROOT_DIR/install.sh"
grep -Fq "printf 'SUCCESS (%d)" "$ROOT_DIR/install.sh"
grep -Fq "printf 'FAILED (%d)" "$ROOT_DIR/install.sh"
grep -Fq 'timedatectl set-timezone Europe/Rome' "$ROOT_DIR/modules/10-system-packages.sh"
grep -Fq 'timedatectl set-ntp true' "$ROOT_DIR/modules/10-system-packages.sh"

vm_help="$($ROOT_DIR/bin/create-vms.sh --help)"
grep -Fq 'Uso: create-vms.sh NOME ISO [opzioni]' <<<"$vm_help"
grep -Fq -- '--memory MIB' <<<"$vm_help"
grep -Fq -- '--uefi' <<<"$vm_help"
grep -Fq -- '--tpm' <<<"$vm_help"
! grep -Eq 'debian|fedora|windows11|w11' "$ROOT_DIR/bin/create-vms.sh"

printf '%s\n' 'OK   CLI --help/--info'
