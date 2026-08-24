#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

bash "$ROOT_DIR/modules/26-kitty.sh" </dev/null

install_available_packages sway sway-config-fedora waybar fuzzel foot mako swayidle swaylock \
  grim slurp wl-clipboard brightnessctl playerctl pavucontrol \
  network-manager-applet xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  lxqt-policykit wireplumber cascadia-mono-nf-fonts

for command_name in sway waybar; do
  command_exists "$command_name" || die "$command_name non disponibile dopo l'installazione."
done

install -m 0755 "$ROOT_DIR/bin/waybar-cpu-temperature" "$HOME/.local/bin/waybar-cpu-temperature"
install -m 0755 "$ROOT_DIR/bin/sway-shortcuts" "$HOME/.local/bin/sway-shortcuts"
install -m 0755 "$ROOT_DIR/bin/workstation-theme" "$HOME/.local/bin/workstation-theme"
install -m 0755 "$ROOT_DIR/bin/workstation-lock" "$HOME/.local/bin/workstation-lock"
install -m 0755 "$ROOT_DIR/bin/workstation-network-editor" "$HOME/.local/bin/workstation-network-editor"
install -m 0755 "$ROOT_DIR/bin/workstation-policykit-agent" "$HOME/.local/bin/workstation-policykit-agent"
install -d "$HOME/.local/share/workstation-setup/themes/dark"
install -d "$HOME/.local/share/workstation-setup/themes/light"
install -m 0644 "$ROOT_DIR/templates/themes/dark/"* "$HOME/.local/share/workstation-setup/themes/dark/"
install -m 0644 "$ROOT_DIR/templates/themes/light/"* "$HOME/.local/share/workstation-setup/themes/light/"
install -D -m 0644 \
  "$ROOT_DIR/wallpapers/mita.jpg" \
  "$HOME/.local/share/backgrounds/workstation-setup.jpg"
install_managed_config \
  "$ROOT_DIR/templates/sway/sway-shortcuts.desktop" \
  "$HOME/.local/share/applications/sway-shortcuts.desktop" \
  '# workstation-setup: managed Sway shortcuts entry'
install_managed_config \
  "$ROOT_DIR/templates/sway/workstation-theme.desktop" \
  "$HOME/.local/share/applications/workstation-theme.desktop" \
  '# workstation-setup: managed theme switcher entry'
install_managed_config \
  "$ROOT_DIR/templates/sway/config" \
  "$HOME/.config/sway/config" \
  '# workstation-setup: managed sway config'
install_managed_config \
  "$ROOT_DIR/templates/sway/fuzzel.ini" \
  "$HOME/.config/fuzzel/fuzzel.ini" \
  '# workstation-setup: managed Fuzzel config'
install_managed_config \
  "$ROOT_DIR/templates/sway/waybar-config.jsonc" \
  "$HOME/.config/waybar/config" \
  '// workstation-setup: managed waybar config'
install_managed_config \
  "$ROOT_DIR/templates/sway/waybar-style.css" \
  "$HOME/.config/waybar/style.css" \
  '/* workstation-setup: managed waybar style */'

active_theme="$("$HOME/.local/bin/workstation-theme" current)"
"$HOME/.local/bin/workstation-theme" "$active_theme"

install_managed_config \
  "$ROOT_DIR/templates/sway/environment" \
  "$HOME/.config/environment.d/90-sway.conf" \
  '# workstation-setup: managed sway environment'
install_managed_config \
  "$ROOT_DIR/templates/sway/portals.conf" \
  "$HOME/.config/xdg-desktop-portal/sway-portals.conf" \
  '# workstation-setup: managed sway portals'

sudo install -D -m 0644 \
  "$ROOT_DIR/templates/logind-lid.conf" \
  /etc/systemd/logind.conf.d/90-workstation-setup-lid.conf

log "Sway, Waybar e integrazione desktop configurati"
