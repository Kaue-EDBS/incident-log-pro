#!/usr/bin/env bash
set -euo pipefail

# Read the disposable local stack credentials without persisting them.
eval "$(supabase status -o env)"

API_BASE="${API_URL:-}"
PUBLIC_KEY="${PUBLISHABLE_KEY:-${ANON_KEY:-}}"

: "${API_BASE:?Supabase local API URL was not exported}"
: "${PUBLIC_KEY:?Supabase local public API key was not exported}"

tables=(operational_areas systems scenarios scenario_versions scenario_owners scenario_version_impacted_areas scenario_version_systems scenario_slas treatments treatment_impacted_areas treatment_impact_measurements treatment_events scenario_proposals scenario_proposal_owner_responses notifications_log governance_issues)

for table in "${tables[@]}"; do
  body_file="$(mktemp)"
  http_code="$(
    curl --silent --show-error       --output "${body_file}"       --write-out "%{http_code}"       --header "apikey: ${PUBLIC_KEY}"       "${API_BASE}/rest/v1/${table}?select=*&limit=1"
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


# C06.1 Action 4: ownership cannot be self-assigned or rewritten through the public Data API.
for method in POST PATCH; do
  body_file="$(mktemp)"
  if [[ "${method}" == "POST" ]]; then
    url="${API_BASE}/rest/v1/scenario_owners"
    data='{"scenario_id":"00000000-0000-0000-0000-000000000001","owner_id":"00000000-0000-0000-0000-000000000002","assignment_reason":"unauthorized direct API audit"}'
  else
    url="${API_BASE}/rest/v1/scenario_owners?id=eq.00000000-0000-0000-0000-000000000001"
    data='{"assignment_reason":"unauthorized direct API audit"}'
  fi

  http_code="$(
    curl --silent --show-error \
      --output "${body_file}" \
      --write-out "%{http_code}" \
      --request "${method}" \
      --header "apikey: ${PUBLIC_KEY}" \
      --header "Content-Type: application/json" \
      --data "${data}" \
      "${url}"
  )"

  if [[ "${http_code}" != "401" && "${http_code}" != "403" ]]; then
    echo "Direct ownership mutation unexpectedly reached scenario_owners: ${method} -> HTTP ${http_code}"
    cat "${body_file}"
    rm -f "${body_file}"
    exit 1
  fi

  echo "PASS direct ownership mutation denial: scenario_owners ${method} -> HTTP ${http_code}"
  rm -f "${body_file}"
done
