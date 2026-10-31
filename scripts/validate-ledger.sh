#!/usr/bin/env bash
set -euo pipefail

LEDGER="${1:?Usage: validate-ledger.sh <ledger-file>}"
if [[ ! -f "$LEDGER" ]]; then
  echo "ERROR: Ledger file not found: $LEDGER" >&2
  exit 1
fi

INVALID="$(grep -vE '^(#|$|[A-Za-z0-9_-]+[[:space:]]*\|.*\|.*\|.*\|[[:space:]]*(OPEN|FIXED|ASKED|DEFERRED-[^|[:space:]]+|REJECTED-[^|[:space:]]+)[[:space:]]*$)' "$LEDGER" || true)"
if [[ -n "$INVALID" ]]; then
  echo "ERROR: Malformed or indisposed ledger rows (every row needs ID | Lenses | Statement | file:line | FIXED|DEFERRED-<ticket>|ASKED|REJECTED-<citation>|OPEN):" >&2
  printf '%s\n' "$INVALID" >&2
  exit 1
fi

UNRESOLVED="$(grep -E '\|[[:space:]]*(OPEN|ASKED)[[:space:]]*$' "$LEDGER" || true)"
if [[ -n "$UNRESOLVED" ]]; then
  echo "UNRESOLVED_ROWS:"
  printf '%s\n' "$UNRESOLVED"
  exit 2
fi

echo "OK: All ledger rows resolved ($(grep -c '|' "$LEDGER") rows)."
