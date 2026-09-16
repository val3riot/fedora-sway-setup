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

install_available_packages sway sway-config-fedora waybar fuzzel foot mako swayidle swaylock \
  grim slurp wl-clipboard brightnessctl playerctl pavucontrol \
  network-manager-applet xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  lxqt-policykit wireplumber cascadia-mono-nf-fonts greetd gtkgreet greetd-selinux

for command_name in sway waybar; do
  command_exists "$command_name" || die "$command_name non disponibile dopo l'installazione."
done

install -m 0755 "$ROOT_DIR/bin/waybar-cpu-temperature" "$HOME/.local/bin/waybar-cpu-temperature"
install -m 0755 "$ROOT_DIR/bin/sway-shortcuts" "$HOME/.local/bin/sway-shortcuts"
install -m 0755 "$ROOT_DIR/bin/workstation-app-menu" "$HOME/.local/bin/workstation-app-menu"
install -m 0755 "$ROOT_DIR/bin/workstation-theme" "$HOME/.local/bin/workstation-theme"
install -m 0755 "$ROOT_DIR/bin/workstation-lock" "$HOME/.local/bin/workstation-lock"
install -m 0755 "$ROOT_DIR/bin/workstation-wallpaper" "$HOME/.local/bin/workstation-wallpaper"
install_managed_config "$ROOT_DIR/templates/swaylock/config" "$HOME/.config/swaylock/config" '# workstation-setup: managed swaylock theme'
install -m 0755 "$ROOT_DIR/bin/workstation-network-editor" "$HOME/.local/bin/workstation-network-editor"
install -m 0755 "$ROOT_DIR/bin/workstation-policykit-agent" "$HOME/.local/bin/workstation-policykit-agent"
install -m 0755 "$ROOT_DIR/bin/workstation-power-menu" "$HOME/.local/bin/workstation-power-menu"
install -m 0755 "$ROOT_DIR/bin/workstation-power-profile-menu" "$HOME/.local/bin/workstation-power-profile-menu"
install -m 0755 "$ROOT_DIR/bin/cliamp-widget" "$HOME/.local/bin/cliamp-widget"
install -d "$HOME/.local/share/workstation-setup/themes/dark"
install -d "$HOME/.local/share/workstation-setup/themes/light"
install -m 0644 "$ROOT_DIR/templates/themes/dark/"* "$HOME/.local/share/workstation-setup/themes/dark/"
install -m 0644 "$ROOT_DIR/templates/themes/light/"* "$HOME/.local/share/workstation-setup/themes/light/"
if [[ ! -f "$HOME/.local/share/backgrounds/workstation-setup.jpg" ]]; then
  "$ROOT_DIR/bin/workstation-wallpaper" "$ROOT_DIR/wallpapers/mita.jpg"
fi
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
python3 "$ROOT_DIR/bin/configure-sway-windows.py"
install_managed_config \
  "$ROOT_DIR/templates/sway/config.d/99-theme.conf" \
  "$HOME/.config/sway/config.d/99-theme.conf" \
  '# workstation-setup: managed sway window borders'
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

install -m 0755 "$ROOT_DIR/bin/sway-help" "$HOME/.local/bin/sway-help"
install -m 0644 "$ROOT_DIR/templates/sway/sway-help.desktop" "$HOME/.local/share/applications/workstation-sway-help.desktop"
if [[ "$quickshell_selected" == true ]]; then
  python3 "$ROOT_DIR/bin/configure-quickshell.py"
fi

log "Sway, Waybar e integrazione desktop configurati"

# Standard toolkit preferences, shared with the Quickshell desktop.
python3 "$ROOT_DIR/bin/configure-appearance.py"
