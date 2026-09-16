#!/usr/bin/env bash
set +u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$HOME/.config/workstation-setup/env.zsh" ]] && source "$HOME/.config/workstation-setup/env.zsh"

failed=0

ok()   { printf 'OK   %-22s %s\n' "$1" "${2:-}"; }
warn() { printf 'WARN %-22s %s\n' "$1" "${2:-}"; }
fail() { printf 'FAIL %-22s %s\n' "$1" "${2:-}"; failed=1; }

check() {
  local label=$1 command_name=$2
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$label" "$(command -v "$command_name")"
  else
    fail "$label" "comando assente"
  fi
}

printf '=== Fedora Sway Desktop Doctor ===\n\n'

# 1. Dotfiles e GNU Stow
printf 'Dotfiles & GNU Stow:\n'
check 'GNU Stow' stow
if [[ -d "$ROOT_DIR/dotfiles" ]]; then
  ok 'Dotfiles repo tree' "$ROOT_DIR/dotfiles"
else
  fail 'Dotfiles repo tree' "$ROOT_DIR/dotfiles"
fi

if [[ -x "$ROOT_DIR/bin/stow-dotfiles" ]]; then
  if "$ROOT_DIR/bin/stow-dotfiles" check >/dev/null 2>&1; then
    ok 'Stow dotfiles' 'tutti i symlink e pacchetti verificati'
  else
    warn 'Stow dotfiles' 'discrepanze rilevate; esegui: bin/stow-dotfiles check'
  fi
fi

# 2. Shell e Terminale
printf '\nShell & Terminale:\n'
check Zsh zsh
check Starship starship
check Kitty kitty
if rpm -q kitty-terminfo >/dev/null 2>&1; then
  ok 'Kitty terminfo' "$(rpm -q kitty-terminfo)"
else
  warn 'Kitty terminfo' 'pacchetto kitty-terminfo non rilevato'
fi
if command -v infocmp >/dev/null 2>&1 && infocmp -x xterm-kitty >/dev/null 2>&1; then
  ok 'xterm-kitty' 'infocmp riuscito'
else
  warn 'xterm-kitty' 'infocmp non riuscito'
fi

# 3. Compositor Sway & Sessione
printf '\nSway Compositor:\n'
check Sway sway
check Swaylock swaylock
check Swayidle swayidle
check 'Sway help' sway-help

sway_config="$HOME/.config/sway/config"
if [[ -r "$sway_config" ]]; then
  ok 'Sway config' "$sway_config"
else
  fail 'Sway config' 'file mancante'
fi

for dropin in 60-policykit-window.conf 61-desktop-app-windows.conf 62-system-utilities.conf 90-bar.conf 92-desktop-tools.conf 93-appearance.conf 95-notifications.conf 99-theme.conf; do
  dropin_path="$HOME/.config/sway/config.d/$dropin"
  if [[ -r "$dropin_path" ]]; then
    ok "Sway drop-in" "$dropin"
  else
    warn "Sway drop-in" "$dropin assente"
  fi
done

# 4. Sfondo e Lockscreen
printf '\nWallpaper & Lockscreen:\n'
check 'Wallpaper helper' workstation-wallpaper
if [[ -r "$HOME/.local/share/backgrounds/workstation-setup.jpg" ]]; then
  ok 'Wallpaper canonico' "$HOME/.local/share/backgrounds/workstation-setup.jpg"
else
  warn 'Wallpaper canonico' 'sfondo predefinito non trovato'
fi

check 'Lock helper' workstation-lock
if [[ -x "$HOME/.local/bin/workstation-lock" ]]; then
  "$HOME/.local/bin/workstation-lock" --check >/dev/null 2>&1 &&
    ok 'Swaylock config' 'supportata e verificata' ||
    warn 'Swaylock config' 'non conforme'
fi

# 5. Display Manager & Greeter
printf '\nDisplay Manager & Greeter:\n'
check 'Greetd daemon' greetd
check 'Gtkgreet' gtkgreet
for greetd_conf in /etc/greetd/config.toml /etc/greetd/sway-config /etc/greetd/gtkgreet.css; do
  if [[ -r "$greetd_conf" ]]; then
    ok 'Greeter config' "$greetd_conf"
  else
    warn 'Greeter config' "$greetd_conf assente o non leggibile"
  fi
done

dm_target="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
if [[ -n "$dm_target" ]]; then
  ok 'Display manager' "$(basename "$dm_target")"
else
  warn 'Display manager' 'nessun display-manager.service configurato'
fi

# 6. Audio e Rete (PipeWire & NetworkManager)
printf '\nAudio & Networking:\n'
check WirePlumber wireplumber
check Pavucontrol pavucontrol
check 'Network editor' nm-connection-editor

if systemctl --user is-active --quiet wireplumber 2>/dev/null; then
  ok 'WirePlumber service' 'attivo'
else
  warn 'WirePlumber service' 'non attivo nella sessione corrente'
fi

# Hardware e radio tramite helper veloce Bash
if [[ -x "$ROOT_DIR/bin/doctor-quickshell-hardware.sh" ]]; then
  "$ROOT_DIR/bin/doctor-quickshell-hardware.sh"
fi

# 7. Portali XDG e Polkit
printf '\nDesktop Portals & Polkit:\n'
check 'Portal GTK' /usr/libexec/xdg-desktop-portal-gtk
check 'Portal WLR' /usr/libexec/xdg-desktop-portal-wlr
check 'Polkit agent' /usr/libexec/lxqt-policykit-agent

# 8. Helper e Utility Desktop
printf '\nDesktop Helpers:\n'
for helper in workstation-screenshot workstation-shell workstation-system-tool workstation-theme workstation-bar.sh; do
  check "$helper" "$helper"
done

# 9. Quickshell Desktop Environment
printf '\nQuickshell & Barra Desktop:\n'
quickshell_status=0
"$ROOT_DIR/bin/doctor-quickshell.sh" || quickshell_status=1
if (( quickshell_status != 0 )); then
  failed=1
fi

# 10. Gestione energetica (se presente)
if command -v laptop-power-mode >/dev/null 2>&1; then
  printf '\nConfigurazione energetica:\n'
  laptop-power-mode status 2>/dev/null || true
fi

printf '\n====================================\n'
if (( failed == 0 )); then
  printf 'Esito finale: \033[1;32mOK (desktop sano e coerente)\033[0m\n'
else
  printf 'Esito finale: \033[1;31mFAIL (anomalie desktop rilevate)\033[0m\n'
fi
exit "$failed"
