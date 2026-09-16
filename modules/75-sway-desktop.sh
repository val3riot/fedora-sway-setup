#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

# Preserve an already selected Quickshell backend across a normal Sway setup.
quickshell_selected=false
if [[ "$(cat "$HOME/.config/workstation-setup/bar" 2>/dev/null || true)" == quickshell ]]; then
  python3 "$ROOT_DIR/bin/configure-quickshell.py" --check
  quickshell_selected=true
fi
bash "$ROOT_DIR/modules/26-kitty.sh" </dev/null

install_available_packages sway sway-config-fedora waybar fuzzel foot mako swayidle swaylock stow \
  grim slurp wl-clipboard brightnessctl playerctl pavucontrol \
  network-manager-applet xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  lxqt-policykit wireplumber cascadia-mono-nf-fonts greetd gtkgreet greetd-selinux

for command_name in sway waybar; do
  command_exists "$command_name" || die "$command_name non disponibile dopo l'installazione."
done

"$ROOT_DIR/bin/stow-dotfiles" apply sway swaylock waybar scripts desktop-theme

install -d "$HOME/.local/share/workstation-setup/themes/dark"
install -d "$HOME/.local/share/workstation-setup/themes/light"
install -m 0644 "$ROOT_DIR/templates/themes/dark/"* "$HOME/.local/share/workstation-setup/themes/dark/"
install -m 0644 "$ROOT_DIR/templates/themes/light/"* "$HOME/.local/share/workstation-setup/themes/light/"
if [[ ! -f "$HOME/.local/share/backgrounds/workstation-setup.jpg" ]]; then
  "$ROOT_DIR/bin/workstation-wallpaper" "$ROOT_DIR/wallpapers/mita.jpg"
fi

python3 "$ROOT_DIR/bin/configure-sway-windows.py"

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

if [[ "$quickshell_selected" == true ]]; then
  python3 "$ROOT_DIR/bin/configure-quickshell.py"
fi

log "Sway, Waybar e integrazione desktop configurati"

# Standard toolkit preferences, shared with the Quickshell desktop.
python3 "$ROOT_DIR/bin/configure-appearance.py"
