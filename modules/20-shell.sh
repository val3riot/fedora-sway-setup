#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  installer="$TOOLS_DIR/tmp/install-oh-my-zsh.sh"
  download_verified "$OH_MY_ZSH_INSTALL_URL" "$installer" "$OH_MY_ZSH_INSTALL_SHA256"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$installer" --unattended
fi

if [[ ! -f "$HOME/.zshrc" ]]; then
  cp "$ROOT_DIR/templates/zshrc" "$HOME/.zshrc"
else
  append_line_once '# workstation-setup: personal development environment' "$HOME/.zshrc"
  append_line_once '[[ -f "$HOME/.config/workstation-setup/env.zsh" ]] && source "$HOME/.config/workstation-setup/env.zsh"' "$HOME/.zshrc"
fi

mkdir -p "$HOME/.config/workstation-setup"
env_file="$HOME/.config/workstation-setup/env.zsh"
legacy_kitty_ssh_override=false
if grep -Fq 'command kitten ssh "$@"' "$env_file" 2>/dev/null; then
  legacy_kitty_ssh_override=true
fi

cat > "$env_file" <<ENV
export TOOLS_DIR="$TOOLS_DIR"
export PROJECTS_DIR="$PROJECTS_DIR"
export AGENTS_ROOT="$TOOLS_DIR/Agents"
export CODEX_HOME="$HOME/.codex"
export CLAUDE_CONFIG_DIR="\$AGENTS_ROOT/claude"
export COPILOT_HOME="\$AGENTS_ROOT/copilot"
export NVM_DIR="$TOOLS_DIR/nvm"
export SDKMAN_DIR="$TOOLS_DIR/sdkman"
export VAGRANT_HOME="$TOOLS_DIR/vagrant"
export VAGRANT_DEFAULT_PROVIDER="libvirt"
export PATH="\$HOME/.local/bin:\$PATH"

alias ll='ls -alF'
alias gst='git status'
alias ..='cd ..'
alias update-a='sudo dnf upgrade --refresh -y && flatpak update -y'

[[ -s "\$NVM_DIR/nvm.sh" ]] && source "\$NVM_DIR/nvm.sh"
[[ -s "\$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "\$SDKMAN_DIR/bin/sdkman-init.sh"
[[ -f "$TOOLS_DIR/miniconda3/etc/profile.d/conda.sh" ]] && source "$TOOLS_DIR/miniconda3/etc/profile.d/conda.sh"
ENV

if [[ "$legacy_kitty_ssh_override" == true ]]; then
  log "Rimosso il precedente override di ssh verso kitten ssh da $env_file"
fi

current_shell="$(getent passwd "$USER" | cut -d: -f7)"
zsh_path="$(command -v zsh || true)"
if [[ -n "$zsh_path" && "$current_shell" != "$zsh_path" ]]; then
  sudo -n chsh -s "$zsh_path" "$USER" </dev/null ||
    warn "Cambio shell non riuscito; esegui manualmente: chsh -s $zsh_path"
fi
