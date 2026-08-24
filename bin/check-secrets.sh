#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failed=0
if git grep -n -I -E -- \
  '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}' \
  -- ':!bin/check-secrets.sh'; then
  printf '%s\n' 'FAIL possibile segreto nel repository' >&2
  failed=1
else
  printf '%s\n' 'OK   secret guardrail'
fi

if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  printf '%s\n' 'FAIL file locale tracciato: .env' >&2
  failed=1
fi

exit "$failed"
