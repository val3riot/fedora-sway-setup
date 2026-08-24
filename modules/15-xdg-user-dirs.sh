#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

command_exists xdg-user-dir || {
  warn "xdg-user-dir non disponibile; rinomina delle cartelle standard saltata."
  exit 0
}
command_exists xdg-user-dirs-update || {
  warn "xdg-user-dirs-update non disponibile; rinomina delle cartelle standard saltata."
  exit 0
}

set_xdg_dir() {
  local type=$1 english_name=$2 current target
  target="$HOME/$english_name"
  current="$(xdg-user-dir "$type" 2>/dev/null || true)"

  if [[ -z "$current" || "$current" == "$HOME" ]]; then
    mkdir -p "$target"
    xdg-user-dirs-update --set "$type" "$target"
    printf '  %s -> %s\n' "$type" "$target"
    return
  fi

  if [[ "$current" == "$target" ]]; then
    mkdir -p "$target"
    return
  fi

  if [[ -e "$target" ]]; then
    if [[ -d "$current" && -z "$(find "$current" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
      rmdir "$current" 2>/dev/null || true
    elif [[ -d "$current" ]]; then
      warn "Non unisco automaticamente '$current' in '$target': entrambe esistono. Gestisci i file manualmente."
      return
    fi
  elif [[ -d "$current" ]]; then
    mv -- "$current" "$target"
  else
    mkdir -p "$target"
  fi

  xdg-user-dirs-update --set "$type" "$target"
  printf '  %s -> %s\n' "$type" "$target"
}

log "Configurazione cartelle XDG in inglese"
set_xdg_dir DESKTOP Desktop
set_xdg_dir DOWNLOAD Downloads
set_xdg_dir DOCUMENTS Documents
set_xdg_dir MUSIC Music
set_xdg_dir PICTURES Pictures
set_xdg_dir VIDEOS Videos
set_xdg_dir TEMPLATES Templates
set_xdg_dir PUBLICSHARE Public
