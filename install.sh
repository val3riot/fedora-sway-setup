#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"

show_info() {
  cat <<'INFO'
Fedora Workstation Setup

USO
  ./install.sh [PROFILO] [OPZIONI]

PROFILI
  --base           Sistema essenziale, shell, rete e strumenti di base.
  --development    Ambiente di sviluppo completo; profilo predefinito.
  --gnome-desktop  Applicazioni desktop e configurazione GNOME.
  --sway-desktop   Desktop tiling Wayland basato su Sway, affiancato a GNOME.
  --desktop        Alias compatibile di --gnome-desktop.
  --all            Alias di --development --gnome-desktop.

I profili desktop sono separati e componibili con --development, per esempio:
  ./install.sh --development --sway-desktop

OPZIONI
  --config-zsh-theme  Installa e configura Starship e i plugin Zsh.
  --set-wallpaper     Sceglie uno sfondo dalla cartella wallpapers/.
  --help, --info, -h  Mostra questa guida.

COMPONENTI PRINCIPALI
  Development   Kitty, tmux, SDKMAN, Node/NVM, Miniconda, TeX Live,
                Docker rootless/Desktop, VS Code, KVM/libvirt e Vagrant.
  Desktop       DBeaver, Bruno, JetBrains Toolbox, Thunderbird,
                LibreOffice, Discord, Obsidian e Dash to Dock.
  Sway          Sway, Waybar, Fuzzel, notifiche, lock screen e guida
                ricercabile delle scorciatoie (Super+G).
  Agenti AI     Codex, Claude Code e Copilot CLI; opt-in con
                INSTALL_AGENTS=true in config/local.env.

CONFIGURAZIONE
  cp config/local.env.example config/local.env
  Versioni, fonti e checksum: config/sources.env

VERIFICA
  ./bin/test.sh                 Suite completa del repository.
  ./bin/doctor.sh               Stato della workstation.
  ./bin/provenance-audit.sh     Provenienza del software installato.
  ./bin/audit-urls.sh --online  Fonti e raggiungibilità degli endpoint.
  I log sono salvati in ~/.local/state/fedora-workstation-setup/.

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

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-workstation-setup"
mkdir -p "$STATE_DIR"
LOG_FILE="$STATE_DIR/install-$(date '+%Y%m%d-%H%M%S')-$$.log"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
printf 'Log installazione: %s\n' "$LOG_FILE"

PROFILE=development
INCLUDE_DESKTOP_APPS=false
INCLUDE_SWAY_DESKTOP=false
CONFIG_ZSH_THEME=false
RUN_CORE_PROFILE=false
core_profile_selected=false
any_profile_selected=false

while (($#)); do
  case "$1" in
    base|--base)
      [[ "$core_profile_selected" == false ]] || die "Specifica un solo profilo tra --base e --development."
      PROFILE=base; RUN_CORE_PROFILE=true; core_profile_selected=true; any_profile_selected=true
      ;;
    development|--develop|--development)
      [[ "$core_profile_selected" == false ]] || die "Specifica un solo profilo tra --base e --development."
      PROFILE=development; RUN_CORE_PROFILE=true; core_profile_selected=true; any_profile_selected=true
      ;;
    --desktop|--gnome-desktop)
      INCLUDE_DESKTOP_APPS=true; any_profile_selected=true
      ;;
    --sway-desktop)
      INCLUDE_SWAY_DESKTOP=true; any_profile_selected=true
      ;;
    --all)
      [[ "$core_profile_selected" == false ]] || die "--all non è combinabile con --base o --development."
      PROFILE=development; RUN_CORE_PROFILE=true; core_profile_selected=true
      INCLUDE_DESKTOP_APPS=true; any_profile_selected=true
      ;;
    --config-zsh-theme) CONFIG_ZSH_THEME=true ;;
    --set-wallpaper)
      (( $# == 1 )) || die "--set-wallpaper non accetta altri argomenti."
      exec "$ROOT_DIR/bin/set-wallpaper.sh"
      ;;
    *) die "Opzione non valida: $1. Usa --help per l'elenco dei comandi." ;;
  esac
  shift
done

if [[ "$any_profile_selected" == false ]]; then
  PROFILE=development
  RUN_CORE_PROFILE=true
fi
if [[ "$PROFILE" == base &&
      ( "$INCLUDE_DESKTOP_APPS" == true || "$INCLUDE_SWAY_DESKTOP" == true ) ]]; then
  die "--base non è combinabile con i profili desktop; usa --development oppure il solo profilo desktop."
fi

export ROOT_DIR PROFILE INCLUDE_DESKTOP_APPS INCLUDE_SWAY_DESKTOP CONFIG_ZSH_THEME RUN_CORE_PROFILE

log "Controllo sintassi degli script"
while IFS= read -r -d '' script; do
  bash -n "$script" || die "Errore di sintassi in: ${script#"$ROOT_DIR"/}"
done < <(find "$ROOT_DIR" -type f -name '*.sh' -print0)
bash -n "$ROOT_DIR/bin/laptop-power-mode"
bash -n "$ROOT_DIR/bin/docker-runtime"

selected_modules=()
for module in "$ROOT_DIR"/modules/*.sh; do
  module_name="$(basename "$module")"
  if [[ "$RUN_CORE_PROFILE" == false ]]; then
    run_standalone_module=false
    [[ "$module_name" == 00-directories.sh || "$module_name" == 05-agent-context.sh ]] &&
      run_standalone_module=true
    [[ "$INCLUDE_DESKTOP_APPS" == true && "$module_name" == 70-desktop-apps.sh ]] &&
      run_standalone_module=true
    [[ "$INCLUDE_SWAY_DESKTOP" == true &&
       ( "$module_name" == 26-kitty.sh || "$module_name" == 75-sway-desktop.sh ) ]] &&
      run_standalone_module=true
    [[ "$CONFIG_ZSH_THEME" == true && "$module_name" == 25-zsh-theme.sh ]] &&
      run_standalone_module=true
    [[ "$run_standalone_module" == true ]] || continue
  fi
  selected_modules+=("$module")
done

module_total=${#selected_modules[@]}
module_index=0
for module in "${selected_modules[@]}"; do
  module_name="$(basename "$module")"
  ((module_index += 1))
  module_percent=$((module_index * 100 / module_total))
  log "[$module_index/$module_total - $module_percent%] Modulo: $module_name"
  if ! bash "$module"; then
    die "Modulo fallito: $module_name. Dettagli nel log: $LOG_FILE"
  fi
done

if [[ "$RUN_CORE_PROFILE" == false && "$INCLUDE_DESKTOP_APPS" == true ]]; then
  log "Profilo GNOME completato"
  printf '%s\n' \
    "Le applicazioni desktop abilitate sono installate." \
    "Verifica con: $ROOT_DIR/bin/doctor.sh"
  if rpm -q gnome-shell-extension-dash-to-dock >/dev/null 2>&1 &&
     ! gnome-extensions list --enabled 2>/dev/null | grep -Fqx dash-to-dock@micxgx.gmail.com; then
    printf '%s\n' "Esegui logout/login per caricare Dash to Dock, quindi rilancia: $0 --gnome-desktop"
  else
    printf '%s\n' "Non è necessario riavviare la sessione."
  fi
fi
if [[ "$INCLUDE_SWAY_DESKTOP" == true ]]; then
  log "Desktop Sway completato"
  printf '%s\n' \
    "Seleziona Sway dalla schermata di login." \
    "Apri il launcher con Super+D e la guida ricercabile con Super+G." \
    "Verifica con: $ROOT_DIR/bin/doctor.sh"
fi
if [[ "$RUN_CORE_PROFILE" == true ]]; then
  log "Setup completato"
  printf '%s\n' \
    "Riavvia la sessione per rendere Zsh la shell predefinita." \
    "Poi esegui: $ROOT_DIR/bin/doctor.sh" \
    "Per aggiungere account Git: $ROOT_DIR/bin/add-git-identity.sh"
fi
