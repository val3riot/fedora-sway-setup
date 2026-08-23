#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

sudo -v
repo_file=/etc/yum.repos.d/tailscale.repo

if [[ ! -r "$repo_file" ]] ||
   ! grep -Fq 'pkgs.tailscale.com/stable/fedora/' "$repo_file" ||
   ! grep -Eq '^[[:space:]]*gpgcheck[[:space:]]*=[[:space:]]*1[[:space:]]*$' "$repo_file"; then
  log "Configurazione repository RPM ufficiale Tailscale"
  sudo dnf config-manager addrepo --overwrite --save-filename=tailscale \
    --from-repofile="$TAILSCALE_REPO_URL"
fi

log "Installazione Tailscale"
install_available_packages tailscale
sudo systemctl enable --now tailscaled.service

if sudo tailscale status >/dev/null 2>&1; then
  log "Tailscale è già connesso"
else
  warn "Tailscale installato ma non autenticato. Esegui: sudo tailscale up"
fi
