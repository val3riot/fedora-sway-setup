#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

bash "$ROOT_DIR/modules/26-kitty.sh" </dev/null

install_available_packages sway sway-config-fedora swayidle swaylock stow \
  grim slurp wl-clipboard brightnessctl playerctl pavucontrol \
  NetworkManager-tui xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  lxqt-policykit wireplumber cascadia-mono-nf-fonts greetd gtkgreet greetd-selinux

command_exists sway || die "sway non disponibile dopo l'installazione."

"$ROOT_DIR/bin/stow-dotfiles" apply sway swaylock scripts desktop-theme

install -d "$HOME/.local/share/workstation-setup/themes/dark"
install -m 0644 "$ROOT_DIR/templates/themes/dark/"* "$HOME/.local/share/workstation-setup/themes/dark/"
"$ROOT_DIR/bin/workstation-wallpaper" --ensure

bash "$ROOT_DIR/bin/configure-sway-windows.sh"

active_theme="$("$HOME/.local/bin/workstation-theme" current)"
"$HOME/.local/bin/workstation-theme" "$active_theme"

sudo install -D -m 0644 \
  "$ROOT_DIR/templates/logind-lid.conf" \
  /etc/systemd/logind.conf.d/90-workstation-setup-lid.conf

# Configurazione display manager greetd + gtkgreet
sudo install -d -m 0755 /etc/greetd
sudo install -m 0644 "$ROOT_DIR/templates/greetd/config.toml" /etc/greetd/config.toml
sudo install -m 0644 "$ROOT_DIR/templates/greetd/sway-config" /etc/greetd/sway-config
sudo install -m 0644 "$ROOT_DIR/templates/greetd/gtkgreet.css" /etc/greetd/gtkgreet.css
sudo install -m 0644 "$ROOT_DIR/templates/greetd/environments" /etc/greetd/environments
if [[ -f "$HOME/.local/share/backgrounds/workstation-setup.jpg" ]]; then
  sudo install -m 0664 -g wheel "$HOME/.local/share/backgrounds/workstation-setup.jpg" /etc/greetd/wallpaper.jpg
fi
if id -u greetd >/dev/null 2>&1; then
  sudo usermod -a -G video greetd 2>/dev/null || true
fi
if systemctl list-unit-files greetd.service >/dev/null 2>&1; then
  sudo systemctl disable sddm.service 2>/dev/null || true
  sudo systemctl enable greetd.service 2>/dev/null || true
fi

log "Sway e integrazione desktop configurati"

# Standard toolkit preferences, shared with the Quickshell desktop.
python3 "$ROOT_DIR/bin/configure-appearance.py"
