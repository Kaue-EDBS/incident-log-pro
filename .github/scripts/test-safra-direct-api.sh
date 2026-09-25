#!/usr/bin/env bash
set -euo pipefail

# Export local API_URL and legacy ANON_KEY from the disposable Supabase stack.
eval "$(supabase status -o env)"

: "${API_URL:?API_URL not exported by supabase status}"
: "${ANON_KEY:?ANON_KEY not exported by supabase status}"

tables=(scenarios treatments governance_issues)

for table in "${tables[@]}"; do
  body_file="$(mktemp)"
  http_code="$(
    curl --silent --show-error       --output "${body_file}"       --write-out "%{http_code}"       --header "apikey: ${ANON_KEY}"       --header "Authorization: Bearer ${ANON_KEY}"       "${API_URL}/rest/v1/${table}?select=id&limit=1"
  )"

  if [[ "${http_code}" != "401" && "${http_code}" != "403" ]]; then
    echo "Direct API access unexpectedly succeeded for anon on ${table}: HTTP ${http_code}"
    cat "${body_file}"
    rm -f "${body_file}"
    exit 1
  fi

  echo "PASS direct API anon denial: ${table} -> HTTP ${http_code}"
  rm -f "${body_file}"
done
