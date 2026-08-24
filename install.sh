#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"

show_info() {
  cat <<'INFO'
Fedora Workstation Setup

USO
  ./install.sh [PROFILO] COMPONENTE...

PROFILI
  --base          Sistema essenziale, shell, rete e strumenti di base.
  --dev           Strumenti di sviluppo indipendenti dal desktop, incluso Docker rootless.
  --all           Base, sviluppo, applicazioni desktop e agenti CLI.

COMPONENTI
  --agent         Installa Codex, Claude Code e Copilot CLI.
  --extra         Installa software ricreativo e non essenziale (attualmente Cliamp).
  --sway          Installa/aggiorna esclusivamente Sway e la sua configurazione.
  --gnome         Installa/aggiorna esclusivamente GNOME e la sua configurazione.

OPZIONI
  --set-wallpaper     Sceglie uno sfondo dalla cartella wallpapers/.
  --help, --info, -h  Mostra questa guida.

COMPONENTI PRINCIPALI
  Dev           Kitty, tmux, SDKMAN, Node/NVM, Miniconda, TeX Live,
                Docker rootless, VS Code, KVM/libvirt e Vagrant.
  All           Base, Dev, app desktop e agenti; GNOME/Sway non impliciti.

CONFIGURAZIONE
  Fonti: config/sources.env; versioni e checksum: config/versions.env

VERIFICA
  ./bin/test.sh                 Suite completa del repository.
  ./bin/doctor.sh               Stato della workstation.
  ./bin/provenance-audit.sh     Provenienza del software installato.
  ./bin/audit-urls.sh --online  Fonti e raggiungibilità degli endpoint.

UTILITÀ
  ./bin/add-git-identity.sh
  docker-runtime status|rootless|desktop
  laptop-power-mode status|dev|quiet|normal|full|default
  install-kitty-terminfo-remote user@host
INFO
}

if [[ "${1:-}" == --info || "${1:-}" == --help || "${1:-}" == -h ]]; then
  (( $# == 1 )) || die "--help/--info non accettano altri argomenti."
  show_info
  exit 0
fi

[[ ${EUID:-$(id -u)} -ne 0 ]] ||
  die "Esegui install.sh come utente normale; lo script richiederà sudo quando necessario."

require_fedora_44
command_exists sudo || die "sudo non è installato."
load_config "$ROOT_DIR"
validate_config

PROFILE=""
INSTALL_BASE=false
INSTALL_DEV=false
INSTALL_APPS=false
INSTALL_AGENTS=false
INSTALL_EXTRA=false
DESKTOP_ENV=none
profile_selected=false

while (($#)); do
  case "$1" in
    --base)
      [[ "$profile_selected" == false ]] || die "Specifica un solo profilo."
      PROFILE=base; INSTALL_BASE=true; profile_selected=true
      ;;
    --dev)
      [[ "$profile_selected" == false ]] || die "Specifica un solo profilo."
      PROFILE=dev; INSTALL_DEV=true; profile_selected=true
      ;;
    --all)
      [[ "$profile_selected" == false ]] || die "Specifica un solo profilo."
      PROFILE=all; INSTALL_BASE=true; INSTALL_DEV=true; INSTALL_APPS=true; INSTALL_AGENTS=true; profile_selected=true
      ;;
    --agent) INSTALL_AGENTS=true ;;
    --extra) INSTALL_EXTRA=true ;;
    --sway)
      [[ "$DESKTOP_ENV" == none ]] || die "--sway e --gnome sono mutuamente esclusivi."
      DESKTOP_ENV=sway
      ;;
    --gnome)
      [[ "$DESKTOP_ENV" == none ]] || die "--sway e --gnome sono mutuamente esclusivi."
      DESKTOP_ENV=gnome
      ;;
    --set-wallpaper)
      (( $# == 1 )) || die "--set-wallpaper non accetta altri argomenti."
      exec "$ROOT_DIR/bin/set-wallpaper.sh"
      ;;
    *) die "Opzione non valida: $1. Usa --help per l'elenco dei comandi." ;;
  esac
  shift
done

if [[ "$profile_selected" == false ]]; then
  [[ "$DESKTOP_ENV" != none || "$INSTALL_EXTRA" == true ]] ||
    die "Specifica un profilo o un componente: --base, --dev, --all, --agent, --extra, --sway oppure --gnome."
  PROFILE=components
fi

export ROOT_DIR PROFILE DESKTOP_ENV

start_sudo_keepalive
trap stop_sudo_keepalive EXIT

log "Controllo sintassi degli script"
while IFS= read -r -d '' script; do
  bash -n "$script" || die "Errore di sintassi in: ${script#"$ROOT_DIR"/}"
done < <(find "$ROOT_DIR" -type f -name '*.sh' -print0)
bash -n "$ROOT_DIR/bin/laptop-power-mode"
bash -n "$ROOT_DIR/bin/docker-runtime"

module_enabled() {
  case "$1" in
    00-directories.sh) return 0 ;;
    05-agent-context.sh) return 1 ;;
    10-system-packages.sh) [[ "$INSTALL_BASE" == true || "$INSTALL_DEV" == true ]] ;;
    12-tailscale.sh|15-xdg-user-dirs.sh|20-shell.sh|25-zsh-theme.sh|80-git.sh|90-power-mode.sh)
      [[ "$INSTALL_BASE" == true ]]
      ;;
    26-kitty.sh|27-tmux.sh|30-sdkman.sh|40-node.sh|50-miniconda.sh|55-docker.sh|57-virtualization.sh|60-vscode.sh)
      [[ "$INSTALL_DEV" == true ]]
      ;;
    45-agents.sh) [[ "$INSTALL_AGENTS" == true ]] ;;
    65-extra.sh) [[ "$INSTALL_EXTRA" == true ]] ;;
    70-desktop-apps.sh) [[ "$INSTALL_APPS" == true ]] ;;
    75-sway-desktop.sh) [[ "$DESKTOP_ENV" == sway ]] ;;
    76-gnome-desktop.sh) [[ "$DESKTOP_ENV" == gnome ]] ;;
    *) die "Modulo senza categoria: $1" ;;
  esac
}

successful_modules=()
failed_modules=()

for module in "$ROOT_DIR"/modules/*.sh; do
  module_name="$(basename "$module")"
  module_enabled "$module_name" || continue
  log "Modulo: $module_name"
  # Dopo l'unico `sudo -v` iniziale il setup è deliberatamente non interattivo.
  # Un installer che tenta di leggere deve ricevere EOF, mai bloccare il flusso.
  if bash "$module" </dev/null; then
    successful_modules+=("$module_name")
  else
    failed_modules+=("$module_name")
    warn "Modulo fallito, il setup continua: $module_name"
  fi
done

log "Aggiornamento finale del contesto macchina per agenti"
if bash "$ROOT_DIR/modules/05-agent-context.sh" </dev/null; then
  successful_modules+=("05-agent-context.sh")
else
  failed_modules+=("05-agent-context.sh")
  warn "Aggiornamento del contesto agenti fallito."
fi

log "Report finale"
printf 'SUCCESS (%d)\n' "${#successful_modules[@]}"
printf '  %s\n' "${successful_modules[@]}"
if ((${#failed_modules[@]})); then
  printf 'FAILED (%d)\n' "${#failed_modules[@]}" >&2
  printf '  %s\n' "${failed_modules[@]}" >&2
else
  printf '%s\n' 'FAILED (0)'
fi

printf '%s\n' \
  "Profilo software: $PROFILE; desktop configurato: $DESKTOP_ENV." \
  "Riavvia la sessione per applicare shell, gruppi e desktop." \
  "Verifica con: $ROOT_DIR/bin/doctor.sh"

((${#failed_modules[@]} == 0)) || exit 1
