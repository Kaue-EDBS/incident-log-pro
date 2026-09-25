#!/usr/bin/env bash
set -euo pipefail

# Read the disposable local stack credentials without persisting them.
eval "$(supabase status -o env)"

API_BASE="${API_URL:-}"
PUBLIC_KEY="${PUBLISHABLE_KEY:-${ANON_KEY:-}}"

: "${API_BASE:?Supabase local API URL was not exported}"
: "${PUBLIC_KEY:?Supabase local public API key was not exported}"

tables=(scenarios treatments governance_issues)

for table in "${tables[@]}"; do
  body_file="$(mktemp)"
  http_code="$(
    curl --silent --show-error       --output "${body_file}"       --write-out "%{http_code}"       --header "apikey: ${PUBLIC_KEY}"       "${API_BASE}/rest/v1/${table}?select=id&limit=1"
  )"

  if [[ "${http_code}" != "401" && "${http_code}" != "403" ]]; then
    echo "Direct API access unexpectedly succeeded for public/anon access on ${table}: HTTP ${http_code}"
    cat "${body_file}"
    rm -f "${body_file}"
    exit 1
  fi

  echo "PASS direct API public/anon denial: ${table} -> HTTP ${http_code}"
  rm -f "${body_file}"
done
