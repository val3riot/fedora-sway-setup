#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

context_dir="$HOME/.agent"
context_file="$context_dir/AGENTS.md"
local_notes="$context_dir/LOCAL_NOTES.md"
CODEX_HOME="$HOME/.codex"
CLAUDE_CONFIG_DIR="$TOOLS_DIR/Agents/claude"
COPILOT_HOME="$TOOLS_DIR/Agents/copilot"

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

desktop_name="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-sconosciuto}}"
case "${DESKTOP_ENV:-none}" in
  sway) desktop_name=Sway ;;
  gnome) desktop_name=GNOME ;;
  *) [[ -n "${SWAYSOCK:-}" ]] && desktop_name=Sway ;;
esac

state_command() {
  local command_name=$1
  if command_exists "$command_name"; then
    printf 'presente (%s)' "$(command -v "$command_name")"
  else
    printf 'assente'
  fi
}

state_rpm() {
  local package_name=$1
  if rpm -q "$package_name" >/dev/null 2>&1; then
    printf 'presente (%s)' "$(rpm -q --qf '%{VERSION}-%{RELEASE}' "$package_name")"
  else
    printf 'assente'
  fi
}

state_directory() {
  local directory=$1
  [[ -d "$directory" ]] && printf 'presente (%s)' "$directory" || printf 'assente'
}

state_service() {
  local service=$1
  if systemctl is-active --quiet "$service" 2>/dev/null; then
    printf 'attivo'
  elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
    printf 'installato, non attivo'
  else
    printf 'assente o non attivo'
  fi
}

state_user_service() {
  local service=$1
  if systemctl --user is-active --quiet "$service" 2>/dev/null; then
    printf 'attivo'
  elif systemctl --user is-enabled --quiet "$service" 2>/dev/null; then
    printf 'installato, non attivo'
  else
    printf 'assente o non attivo'
  fi
}

state_flatpak() {
  local app_id=$1
  if command_exists flatpak && flatpak info --user "$app_id" >/dev/null 2>&1; then
    printf 'presente'
  else
    printf 'assente'
  fi
}

state_sdk_candidate() {
  local directory="$TOOLS_DIR/sdkman/candidates/$1"
  if [[ -d "$directory" ]] && find "$directory" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null |
    grep -q .; then
    printf 'presente'
  else
    printf 'assente'
  fi
}

docker_state="$(state_command docker)"
docker_desktop_state="$(state_rpm docker-desktop)"
docker_rootless_state=assente
if command_exists docker && docker info --format '{{json .SecurityOptions}}' 2>/dev/null | grep -q rootless; then
  docker_rootless_state="attivo"
elif [[ -f "$HOME/.config/systemd/user/docker.service" ]]; then
  docker_rootless_state="configurato, daemon non verificato"
fi

java_state="$(state_sdk_candidate java)"
maven_state="$(state_sdk_candidate maven)"
gradle_state="$(state_sdk_candidate gradle)"
node_state=assente
if find "$TOOLS_DIR/nvm/versions/node" -type f -path '*/bin/node' -print -quit 2>/dev/null | grep -q .; then
  node_state=presente
fi
nvm_state=assente
[[ -s "$TOOLS_DIR/nvm/nvm.sh" ]] && nvm_state=presente
conda_state=assente
[[ -x "$TOOLS_DIR/miniconda3/bin/conda" ]] && conda_state=presente

docker_daemon_state="$(state_user_service docker.service)"
tailscale_daemon_state="$(state_service tailscaled.service)"
power_mode_service_state="$(state_service laptop-power-mode.service)"

tmp_context="$(mktemp "$context_dir/.AGENTS.md.XXXXXX")"
trap 'rm -f "$tmp_context"' EXIT
{
  cat <<EOF
# Contesto della workstation per agenti

> File gestito da fedora-sway-setup. Ultimo aggiornamento: $(date --iso-8601=seconds)
> Leggere anche \`$local_notes\`; quel file è riservato alle note dell'utente.

## Sistema

- Sistema operativo: $os_name $os_version
- Architettura: $(uname -m)
- Kernel: $(uname -r)
- Desktop rilevato/configurato: $desktop_name con systemd
- Shell interattiva: Zsh; gli script di automazione del setup sono Bash
- Package manager di sistema: DNF5/RPM

## Percorsi convenzionali

- Repository di questo setup: \`$ROOT_DIR\`
- Strumenti gestiti per l'utente: \`$TOOLS_DIR\`
- Progetti: \`$PROJECTS_DIR\` (sottocartelle: \`personali\`, \`lavoro\`, \`universita\`, \`homelab\`)
- Eseguibili utente: \`$HOME/.local/bin\`
- Configurazioni utente: \`$HOME/.config\`
- Versioni software configurabili: \`$ROOT_DIR/config/versions.env\`
- Contesto agenti: \`$context_dir\`
- Codex: \`$HOME/.codex\`; Claude e Copilot: \`$TOOLS_DIR/Agents\`

## Stato rilevato della macchina

- Docker Engine: $docker_state
- Docker daemon: $docker_daemon_state
- Docker rootless: $docker_rootless_state
- Docker Desktop: $docker_desktop_state
- Podman: $(state_command podman)
- KVM: $( [[ -e /dev/kvm ]] && printf 'presente (/dev/kvm)' || printf 'assente' )
- Virt-manager: $(state_command virt-manager)
- Virsh: $(state_command virsh)
- Vagrant: $(state_command vagrant)
- Tailscale: $(state_command tailscale); servizio tailscaled: $tailscale_daemon_state
- OpenVPN: $(state_command openvpn); OpenConnect: $(state_command openconnect)
- Java SDKMAN/Temurin: $java_state
- Maven SDKMAN: $maven_state
- Gradle SDKMAN: $gradle_state
- NVM: $nvm_state
- Node: $node_state
- Miniconda: $conda_state
- VS Code: $(state_command code)
- LaTeX: $(state_command tex)
- Quickshell: $(state_command quickshell); backend: $(cat "$HOME/.config/workstation-setup/bar" 2>/dev/null || printf 'non selezionato')
- BlueTUI: $(state_command bluetui); launcher: $(state_command workstation-system-tool)
- Kitty: $(state_command kitty)
- tmux: $(state_command tmux)
- DBeaver: $(state_command dbeaver)
- Bruno: $(state_command bruno)
- Thunderbird: $(state_command thunderbird)
- LibreOffice: $(state_command libreoffice)
- Discord Flatpak: $(state_flatpak com.discordapp.Discord)
- Obsidian Flatpak: $(state_flatpak md.obsidian.Obsidian)
- Cliamp (extra opzionale): $(state_command cliamp)
- TuneD: $(state_command tuned-adm); servizio gestione energetica: $power_mode_service_state

## Agenti CLI

- Codex: $(state_command codex); home: $(state_directory "$CODEX_HOME")
- Claude: $(state_command claude); home: $(state_directory "$CLAUDE_CONFIG_DIR")
- Copilot: $(state_command copilot); home: $(state_directory "$COPILOT_HOME")
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
