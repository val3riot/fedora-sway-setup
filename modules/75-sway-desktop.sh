#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

bash "$ROOT_DIR/modules/26-kitty.sh" </dev/null

install_available_packages sway sway-config-fedora waybar fuzzel foot mako swayidle swaylock \
  grim slurp wl-clipboard brightnessctl playerctl pavucontrol \
  network-manager-applet xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  lxqt-policykit wireplumber

for command_name in sway waybar; do
  command_exists "$command_name" || die "$command_name non disponibile dopo l'installazione."
done

install -m 0755 "$ROOT_DIR/bin/waybar-cpu-temperature" "$HOME/.local/bin/waybar-cpu-temperature"
install -D -m 0644 \
  "$ROOT_DIR/wallpapers/mita.jpg" \
  "$HOME/.local/share/backgrounds/workstation-setup.jpg"
install_managed_config \
  "$ROOT_DIR/templates/sway/config" \
  "$HOME/.config/sway/config" \
  '# workstation-setup: managed sway config'
install_managed_config \
  "$ROOT_DIR/templates/sway/waybar-config.jsonc" \
  "$HOME/.config/waybar/config" \
  '// workstation-setup: managed waybar config'
install_managed_config \
  "$ROOT_DIR/templates/sway/waybar-style.css" \
  "$HOME/.config/waybar/style.css" \
  '/* workstation-setup: managed waybar style */'

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
