#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"

show_info() {
  cat <<'INFO'
Fedora Sway Setup — Desktop Wayland completo con Sway, Quickshell e GNU Stow

USO
  ./install.sh [OPZIONI]

DEFAULT
  Eseguito senza opzioni, ./install.sh installa e configura l'ambiente desktop
  completo: Sway, Quickshell, Greetd, Kitty, Zsh, dotfiles GNU Stow, audio PipeWire,
  Bluetooth, NetworkManager, portali XDG, tema Adwaita e sfondi.

OPZIONI
  --no-quickshell     Disabilita l'installazione di Quickshell.
  --dry-run           Mostra i moduli pianificati senza apportare modifiche al sistema.
  --doctor            Esegue la diagnostica dello stato desktop al termine dell'installazione.
  --set-wallpaper     Seleziona uno sfondo dalla cartella wallpapers/.
  --help, -h          Mostra questa guida.

VERIFICA
  ./bin/doctor.sh     Diagnostica rapida desktop (< 2 secondi).
  ./bin/test.sh       Suite di test completa del repository.
INFO
}

if [[ "${1:-}" == --info || "${1:-}" == --help || "${1:-}" == -h ]]; then
  show_info
  exit 0
fi

if [[ "${1:-}" == --set-wallpaper ]]; then
  exec "$ROOT_DIR/bin/set-wallpaper.sh"
fi

[[ ${EUID:-$(id -u)} -ne 0 ]] ||
  die "Esegui install.sh come utente normale; lo script richiederà sudo quando necessario."

require_fedora_44
command_exists sudo || die "sudo non è installato."
load_config "$ROOT_DIR"
validate_config

CONFIG_QUICKSHELL=true
RUN_DOCTOR=false
DRY_RUN=false

while (($#)); do
  case "$1" in
    --no-quickshell) CONFIG_QUICKSHELL=false ;;
    --dry-run) DRY_RUN=true ;;
    --doctor) RUN_DOCTOR=true ;;
    *) die "Opzione non valida: $1. Usa --help per l'elenco dei comandi." ;;
  esac
  shift
done

export ROOT_DIR CONFIG_QUICKSHELL

modules=(
  00-directories.sh
  10-system-packages.sh
  15-xdg-user-dirs.sh
  20-shell.sh
  25-zsh-theme.sh
  26-kitty.sh
  75-sway-desktop.sh
)

if [[ "$CONFIG_QUICKSHELL" == true ]]; then
  modules+=(76-quickshell.sh)
fi

modules+=(
  80-git.sh
  90-power-mode.sh
  05-agent-context.sh
)

log "Installazione Fedora Sway Desktop (Quickshell: $CONFIG_QUICKSHELL)"

if [[ "$DRY_RUN" == true ]]; then
  printf '\nModalità --dry-run: moduli pianificati (%d):\n' "${#modules[@]}"
  for mod in "${modules[@]}"; do
    printf '  - %s\n' "$mod"
  done
  exit 0
fi

start_sudo_keepalive
trap stop_sudo_keepalive EXIT

log "Controllo sintassi degli script"
while IFS= read -r -d '' script; do
  bash -n "$script" || die "Errore di sintassi in: ${script#"$ROOT_DIR"/}"
done < <(find "$ROOT_DIR" -type f -name '*.sh' -print0)
bash -n "$ROOT_DIR/bin/laptop-power-mode"
bash -n "$ROOT_DIR/bin/stow-dotfiles"

successful_modules=()
failed_modules=()

for module_name in "${modules[@]}"; do
  module_path="$ROOT_DIR/modules/$module_name"
  log "Modulo: $module_name"
  if bash "$module_path" </dev/null; then
    successful_modules+=("$module_name")
  else
    failed_modules+=("$module_name")
    warn "Modulo fallito, il setup continua: $module_name"
  fi
done

log "Report finale Fedora Sway Setup"
printf 'SUCCESS (%d)\n' "${#successful_modules[@]}"
for m in "${successful_modules[@]}"; do printf '  ✓ %s\n' "$m"; done
if ((${#failed_modules[@]})); then
  printf 'FAILED (%d)\n' "${#failed_modules[@]}" >&2
  for m in "${failed_modules[@]}"; do printf '  ✗ %s\n' "$m" >&2; done
  exit 1
fi

printf '\n%s\n' \
  "Desktop Sway e Quickshell configurati con successo." \
  "Riavvia la sessione grafica per applicare shell, gruppi e Greetd."

if [[ "$RUN_DOCTOR" == true ]]; then
  printf '\nEsecuzione doctor desktop:\n'
  bash "$ROOT_DIR/bin/doctor.sh"
else
  printf 'Verifica con: %s\n' "$ROOT_DIR/bin/doctor.sh"
fi
