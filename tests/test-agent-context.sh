#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

export ROOT_DIR PROFILE=base INCLUDE_SWAY_DESKTOP=true HOME="$test_dir/home"
mkdir -p "$HOME"
bash "$ROOT_DIR/modules/05-agent-context.sh" >/dev/null

context="$HOME/.agent/AGENTS.md"
notes="$HOME/.agent/LOCAL_NOTES.md"
grep -Fq '# Contesto della workstation per agenti' "$context"
grep -Fq 'Package manager di sistema: DNF5/RPM' "$context"
grep -Fq "Repository di questo setup: \`$ROOT_DIR\`" "$context"
grep -Fq 'repository RPM ufficiale del vendor con verifica GPG' "$context"
grep -Fq 'Tailscale: installazione fondamentale' "$context"
grep -Fq 'Guida ricercabile: `Super+G` oppure `sway-help`' "$context"

printf '%s\n' 'nota da preservare' >"$notes"
bash "$ROOT_DIR/modules/05-agent-context.sh" >/dev/null
grep -Fqx 'nota da preservare' "$notes"

printf '%s\n' 'OK   contesto agenti creato e note locali preservate'
