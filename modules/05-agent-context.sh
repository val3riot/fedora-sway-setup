#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

context_dir="$HOME/.agent"
context_file="$context_dir/AGENTS.md"
local_notes="$context_dir/LOCAL_NOTES.md"

[[ ! -e "$context_dir" || -d "$context_dir" ]] ||
  die "$context_dir esiste ma non è una directory."
mkdir -p "$context_dir"
chmod 700 "$context_dir"

# Aggiornato a ogni setup senza includere credenziali, indirizzi di rete,
# seriali hardware o altri dati sensibili.
os_name=Fedora
os_version=sconosciuta
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  os_name="${NAME:-Fedora}"
  os_version="${VERSION_ID:-sconosciuta}"
fi

tmp_context="$(mktemp "$context_dir/.AGENTS.md.XXXXXX")"
trap 'rm -f "$tmp_context"' EXIT
{
  cat <<EOF
# Contesto della workstation per agenti

> File gestito da fedora-workstation-setup. Ultimo aggiornamento: $(date --iso-8601=seconds)
> Leggere anche \`$local_notes\`; quel file è riservato alle note dell'utente.

## Sistema

- Sistema operativo: $os_name $os_version
- Architettura: $(uname -m)
- Kernel: $(uname -r)
- Desktop previsto: Fedora Workstation con GNOME e systemd
- Shell interattiva: Zsh; gli script di automazione del setup sono Bash
- Package manager di sistema: DNF5/RPM

## Percorsi convenzionali

- Repository di questo setup: \`$ROOT_DIR\`
- Strumenti gestiti per l'utente: \`$TOOLS_DIR\`
- Progetti: \`$PROJECTS_DIR\` (sottocartelle: \`personali\`, \`lavoro\`, \`universita\`, \`homelab\`)
- Eseguibili utente: \`$HOME/.local/bin\`
- Configurazioni utente: \`$HOME/.config\`
- Configurazione locale del setup: \`$ROOT_DIR/config/local.env\`
- Contesto agenti: \`$context_dir\`
- Codex: \`$HOME/.codex\`; Claude e Copilot: \`$TOOLS_DIR/Agents\`

## Caratteristiche configurate

- Docker: $INSTALL_DOCKER; Docker Desktop: $INSTALL_DOCKER_DESKTOP; rootless: $DOCKER_ROOTLESS
- Podman: $INSTALL_PODMAN
- KVM/libvirt/virt-manager: $INSTALL_VIRTUALIZATION; VM guest opzionali: $CREATE_OPTIONAL_VMS
- Tailscale: installazione fondamentale, servizio \`tailscaled\` abilitato; autenticazione manuale con \`sudo tailscale up\`
- VPN tradizionali OpenVPN/OpenConnect: $INSTALL_VPN_SUPPORT
- SDK: SDKMAN=$INSTALL_SDKMAN, NVM=$INSTALL_NVM, Miniconda=$INSTALL_MINICONDA
- Agenti CLI Codex/Claude/Copilot: $INSTALL_AGENTS (opt-in)
EOF
  cat "$ROOT_DIR/templates/agent-conventions.md"
} >"$tmp_context"
chmod 600 "$tmp_context"
mv -f "$tmp_context" "$context_file"
trap - EXIT

if [[ ! -e "$local_notes" ]]; then
  cat >"$local_notes" <<'EOF'
# Note locali per gli agenti

Inserire qui preferenze, vincoli e dettagli specifici della macchina che non
devono essere sovrascritti dai successivi aggiornamenti del setup.
EOF
  chmod 600 "$local_notes"
fi

log "Contesto macchina per agenti aggiornato: $context_file"
