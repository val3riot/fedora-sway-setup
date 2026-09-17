#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
selection="$HOME/.config/workstation-setup/bar"
[[ -r "$selection" && "$(cat "$selection")" == quickshell ]] || exit 0
config="$HOME/.config/quickshell/workstation"
failed=0
ok() { printf 'OK   Quickshell %-18s %s\n' "$1" "${2:-}"; }
fail() { printf 'FAIL Quickshell %-18s %s\n' "$1" "${2:-}"; failed=1; }
bash "$ROOT_DIR/bin/check-quickshell-runtime.sh" || fail runtime-loadable 'ABI Qt o provenance librerie: vedere diagnostica sopra'
if [[ "$(rpm -q --qf '%{VENDOR}' quickshell 2>/dev/null || true)" == 'Fedora Project' ]] &&
   [[ "$(rpm -qf --qf '%{NAME}' "$(readlink -f "$(command -v quickshell || true)")" 2>/dev/null || true)" == quickshell ]] &&
   rpm -V quickshell >/dev/null 2>&1; then
  ok provenance 'Fedora official, RPM integro'
else
  fail provenance 'eseguibile/vendor/integrità RPM non conformi'
fi
for file in shell.qml Theme.qml qmldir bar/Bar.qml bar/BarButton.qml bar/Workspaces.qml \
  bar/Notifications.qml notifications/Markup.js notifications/NotificationEntry.qml notifications/NotificationItem.qml notifications/NotificationToastStack.qml \
  popups/NotificationCenter.qml services/Notifications.qml services/notification-bus.py \
  bar/SystemStats.qml services/SystemData.qml services/AudioService.qml services/BluetoothService.qml \
  services/stats.py services/network.py services/wifi.py services/desktop-settings.py services/occupancy.py services/power.sh \
  popups/BluetoothPopup.qml popups/BluetoothDeviceRow.qml popups/DeviceButton.qml popups/ActionButton.qml popups/BarPopup.qml popups/AudioPopup.qml popups/NetworkPopup.qml \
  popups/CalendarPopup.qml popups/PowerMenu.qml popups/QuickSettings.qml desktop/DesktopTools.qml shortcuts/ShortcutsPopup.qml shortcuts/ShortcutsData.js; do
  [[ -r "$config/$file" ]] && ok config "$file" || fail config "$file"
done
if python3 "$ROOT_DIR/bin/configure-quickshell.py" --check >/dev/null 2>&1 &&
   grep -Fqx 'exec_always --no-startup-id systemctl --user start workstation-bar.service' "$HOME/.config/sway/config.d/90-bar.conf" &&
   [[ -x "$HOME/.local/bin/workstation-bar.sh" && -r "$HOME/.config/systemd/user/workstation-bar.service" ]]; then
  ok 'Sway integration'
else
  fail 'Sway integration' 'conflitto, modifica personale o file managed mancante'
fi
if pgrep -u "$(id -u)" -x waybar >/dev/null; then
  fail 'runtime conflict' 'Waybar attiva in sessione'
fi
for executable in python3 sway systemctl flock swaymsg swaylock; do
  command -v "$executable" >/dev/null && ok dependency "$executable" || fail dependency "$executable"
done
/usr/bin/python3 -c 'import gi; gi.require_version("NM", "1.0"); from gi.repository import NM' &&
  ok libnm || fail libnm
bash "$ROOT_DIR/bin/install-bluetui.sh" --check || fail BlueTUI 'provenance o installazione non conforme'
rule_62="$ROOT_DIR/dotfiles/sway/.config/sway/config.d/62-system-utilities.conf"
[[ -f "$rule_62" ]] || rule_62="$ROOT_DIR/templates/sway/config.d/62-system-utilities.conf"
if [[ -x "$HOME/.local/bin/workstation-system-tool" ]] &&
   cmp -s "$ROOT_DIR/bin/workstation-system-tool" "$HOME/.local/bin/workstation-system-tool" &&
   cmp -s "$rule_62" "$HOME/.config/sway/config.d/62-system-utilities.conf"; then
  ok 'system utilities' 'helper e app_id Sway dedicati; Kitty normale tiled'
else
  fail 'system utilities' 'helper/regola assente o modificata'
fi
if grep -Fq 'bodyMarkupSupported: true' "$config/services/Notifications.qml" &&
   grep -Fq 'Text.StyledText' "$config/notifications/NotificationItem.qml" &&
   grep -Fq 'Markup.normalize(' "$config/notifications/NotificationItem.qml" &&
   grep -Fq 'WlrLayer.Overlay' "$config/notifications/NotificationToastStack.qml" &&
   grep -Fq 'WlrLayer.Top' "$config/popups/BarPopup.qml"; then
  ok 'notification UX' 'body-markup sanitizzato, toast Overlay, popup Top'
else
  fail 'notification UX' 'capability, sanitizer o layer incoerenti'
fi
for executable in grim slurp wl-copy wl-paste brightnessctl notify-send; do
  command -v "$executable" >/dev/null && ok dependency "$executable" || fail dependency "$executable"
done
for helper in workstation-shell workstation-screenshot workstation-lock workstation-network; do
  if [[ -x "$HOME/.local/bin/$helper" ]] && cmp -s "$ROOT_DIR/bin/$helper" "$HOME/.local/bin/$helper"; then
    ok 'desktop helper' "$helper"
  else
    fail 'desktop helper' "$helper assente/modificato"
  fi
done
rule_92="$ROOT_DIR/dotfiles/sway/.config/sway/config.d/92-desktop-tools.conf"
[[ -f "$rule_92" ]] || rule_92="$ROOT_DIR/templates/sway/config.d/92-desktop-tools.conf"
if cmp -s "$rule_92" "$HOME/.config/sway/config.d/92-desktop-tools.conf"; then
  ok 'desktop keys' 'launcher, clipboard, screenshot e OSD'
else
  fail 'desktop keys' 'drop-in assente/modificato'
fi
"$HOME/.local/bin/workstation-lock" --check || fail swaylock 'configurazione non supportata'
if python3 -c '
import json, subprocess, sys
res = subprocess.check_output([sys.executable, "'"$config"'/services/notification-bus.py", "--once"], text=True).strip()
data = json.loads(res)
if not data.get("known"):
    sys.exit(1)
if data.get("executable") and data["executable"] != "/usr/bin/quickshell":
    sys.exit(1)
'; then
  ok notifications 'Quickshell DBus owner verificato'
else
  fail notifications 'ownership notifiche non conforme'
fi
bash "$ROOT_DIR/bin/doctor-quickshell-hardware.sh" || fail 'optional hardware'
if rg -n 'https?://' "$config"; then
  fail URLs 'URL runtime non consentiti'
else
  ok URLs 'nessun endpoint esterno'
fi
if [[ "${1:-}" == "--test-runtime" ]]; then
  if command -v quickshell >/dev/null && [[ "$failed" == 0 ]]; then
    python3 "$ROOT_DIR/bin/test-quickshell-runtime.py" --config "$config" || fail 'QML runtime'
  fi
fi
python3 "$ROOT_DIR/bin/configure-appearance.py" --check || fail appearance
if [[ -r "$config/popups/QuickSettings.qml" ]] && grep -Fq 'text: "QS"' "$config/bar/Bar.qml"; then
  ok 'Quick Settings' 'composizione servizi esistenti'
else
  fail 'Quick Settings' 'pannello/entrypoint assente'
fi
exit "$failed"
