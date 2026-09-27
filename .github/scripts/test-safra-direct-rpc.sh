#!/usr/bin/env bash
set -euo pipefail

eval "$(supabase status -o env)"

API_BASE="${API_URL:-}"
PUBLIC_KEY="${PUBLISHABLE_KEY:-${ANON_KEY:-}}"

: "${API_BASE:?Supabase local API URL was not exported}"
: "${PUBLIC_KEY:?Supabase local public API key was not exported}"

body_file="$(mktemp)"
http_code="$(
  curl --silent --show-error     --output "${body_file}"     --write-out "%{http_code}"     --request POST     --header "apikey: ${PUBLIC_KEY}"     --header "Content-Type: application/json"     --data '{}'     "${API_BASE}/rest/v1/rpc/safra_is_corporate_user"
)"

if [[ "${http_code}" != "401" && "${http_code}" != "403" ]]; then
  echo "Direct anonymous RPC unexpectedly succeeded: HTTP ${http_code}"
  cat "${body_file}"
  rm -f "${body_file}"
  exit 1
fi

echo "PASS direct anonymous RPC denial: safra_is_corporate_user -> HTTP ${http_code}"
rm -f "${body_file}"
