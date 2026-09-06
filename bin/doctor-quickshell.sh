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
  popups/CalendarPopup.qml popups/PowerMenu.qml .workstation-managed; do
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
  if pgrep -u "$(id -u)" -x quickshell >/dev/null; then
    fail 'runtime conflict' 'Waybar e Quickshell attivi'
  else
    printf 'WARN Quickshell runtime: Waybar attiva (login precedente o fallback).\n'
  fi
fi
for executable in python3 sway systemctl flock swaymsg swaylock waybar; do
  command -v "$executable" >/dev/null && ok dependency "$executable" || fail dependency "$executable"
done
/usr/bin/python3 -c 'import gi; gi.require_version("NM", "1.0"); from gi.repository import NM' &&
  ok libnm || fail libnm
bash "$ROOT_DIR/bin/install-bluetui.sh" --check || fail BlueTUI 'provenance o installazione non conforme'
if [[ -x "$HOME/.local/bin/workstation-system-tool" ]] &&
   cmp -s "$ROOT_DIR/bin/workstation-system-tool" "$HOME/.local/bin/workstation-system-tool" &&
   cmp -s "$ROOT_DIR/templates/sway/config.d/62-system-utilities.conf" "$HOME/.config/sway/config.d/62-system-utilities.conf"; then
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
/usr/bin/python3 "$ROOT_DIR/bin/workstation-notifications.py" doctor || fail notifications "ownership o migrazione non conformi"
/usr/bin/python3 "$ROOT_DIR/bin/doctor-quickshell-hardware.py" || fail 'optional hardware'
if rg -n 'https?://' "$config"; then
  fail URLs 'URL runtime non consentiti'
else
  ok URLs 'nessun endpoint esterno'
fi
if command -v quickshell >/dev/null && [[ "$failed" == 0 ]]; then
  python3 "$ROOT_DIR/bin/test-quickshell-runtime.py" --config "$config" || fail 'QML runtime'
else
  printf 'WARN Quickshell QML: test runtime non eseguibile finché i prerequisiti non sono soddisfatti.\n'
fi
exit "$failed"
