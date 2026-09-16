#!/usr/bin/env bash
set -Eeuo pipefail

# Controllo Wi-Fi rapido tramite NetworkManager
if command -v nmcli >/dev/null 2>&1; then
  wifi_devs="$(nmcli -t -f TYPE device 2>/dev/null | grep -c '^wifi$' || true)"
  if (( wifi_devs > 0 )); then
    printf 'OK   Wi-Fi                  %d dispositivo/i\n' "$wifi_devs"
  else
    printf 'OK   Wi-Fi                  optional absent\n'
  fi
else
  printf 'OK   Wi-Fi                  optional absent\n'
fi

# Controllo Bluetooth rapido tramite sysfs e BlueZ
shopt -s nullglob
bt_adapters=(/sys/class/bluetooth/hci*)
shopt -u nullglob

if ((${#bt_adapters[@]} > 0)); then
  if command -v bluetoothctl >/dev/null 2>&1 && bluetoothctl show >/dev/null 2>&1; then
    printf 'OK   Bluetooth              %d adapter BlueZ\n' "${#bt_adapters[@]}"
  else
    printf 'WARN Bluetooth              hardware presente ma BlueZ non attivo\n'
  fi
else
  printf 'OK   Bluetooth              optional absent\n'
fi
