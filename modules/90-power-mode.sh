#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


log "Configurazione gestione energetica"

if rpm -q power-profiles-daemon >/dev/null 2>&1; then
  log "Sostituzione power-profiles-daemon con TuneD/tuned-ppd"
  sudo dnf swap -y power-profiles-daemon tuned-ppd
fi

install_available_packages tuned tuned-ppd
command_exists tuned-adm || die "tuned-adm non disponibile dopo l’installazione di TuneD."

sudo systemctl enable --now tuned.service

power_source_dir="$TOOLS_DIR/laptop-power-mode"
mkdir -p "$power_source_dir"
install -m 0755 "$ROOT_DIR/bin/laptop-power-mode" "$power_source_dir/laptop-power-mode.sh"

# The system service must execute a root-owned system file, not a script from $HOME.
sudo install -D -m 0755 "$ROOT_DIR/bin/laptop-power-mode" /usr/local/bin/laptop-power-mode
if command_exists restorecon; then
  sudo restorecon -F /usr/local/bin/laptop-power-mode
fi

# ~/.local/bin precedes /usr/local/bin in this setup. Replace any legacy link
# so interactive commands and the systemd service execute the same root-owned file.
mkdir -p "$HOME/.local/bin"
ln -sfn /usr/local/bin/laptop-power-mode "$HOME/.local/bin/laptop-power-mode"

sudo tee /etc/laptop-power-mode.conf >/dev/null <<EOF_CONFIG
# Managed by fedora-workstation-setup.
LPM_DEFAULT_MODE="dev"
LPM_DEV_MAX=60
LPM_QUIET_MAX=45
LPM_MIN_PERF=10
EOF_CONFIG
sudo chmod 0644 /etc/laptop-power-mode.conf

sudo tee /etc/systemd/system/laptop-power-mode.service >/dev/null <<'EOF_SERVICE'
[Unit]
Description=Apply the configured laptop power mode
Documentation=file:/etc/laptop-power-mode.conf
After=tuned.service
Wants=tuned.service
ConditionPathExists=/sys/devices/system/cpu/intel_pstate/max_perf_pct

[Service]
Type=oneshot
Environment=LPM_SHOW_STATUS_AFTER_SET=false
ExecStart=/usr/local/bin/laptop-power-mode default
RemainAfterExit=yes
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
EOF_SERVICE

sudo systemctl daemon-reload
sudo systemctl reset-failed laptop-power-mode.service 2>/dev/null || true

if [[ -e /sys/devices/system/cpu/intel_pstate/max_perf_pct ]]; then
  if ! sudo systemctl enable --now laptop-power-mode.service; then
    sudo journalctl -u laptop-power-mode.service -b --no-pager -n 50 >&2 || true
    die "Avvio di laptop-power-mode.service non riuscito."
  fi
else
  sudo systemctl enable laptop-power-mode.service
  warn "intel_pstate non rilevato: servizio abilitato ma non applicato su questo hardware."
fi
