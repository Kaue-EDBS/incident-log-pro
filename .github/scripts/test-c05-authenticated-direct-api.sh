#!/usr/bin/env bash
set -euo pipefail

eval "$(supabase status -o env)"

API_BASE="${API_URL:-}"
PUBLIC_KEY="${PUBLISHABLE_KEY:-${ANON_KEY:-}}"
ADMIN_KEY="${SERVICE_ROLE_KEY:-${SECRET_KEY:-}}"

: "${API_BASE:?Supabase local API URL was not exported}"
: "${PUBLIC_KEY:?Supabase local public API key was not exported}"
: "${ADMIN_KEY:?Supabase local service/secret key was not exported}"

EMAIL="c05.authenticated.direct.api@example.invalid"
PASSWORD="C05-Disposable-Only-9f2d7a!"

create_body="$(mktemp)"
signin_body="$(mktemp)"
user_body="$(mktemp)"
USER_ID=""

cleanup() {
  if [[ -n "${USER_ID}" ]]; then
    curl --silent --show-error       --request DELETE       --header "apikey: ${ADMIN_KEY}"       --header "Authorization: Bearer ${ADMIN_KEY}"       "${API_BASE}/auth/v1/admin/users/${USER_ID}" >/dev/null 2>&1 || true
  fi
  rm -f "${create_body}" "${signin_body}" "${user_body}"
}
trap cleanup EXIT

create_code="$(
  curl --silent --show-error     --output "${create_body}"     --write-out "%{http_code}"     --request POST     --header "apikey: ${ADMIN_KEY}"     --header "Authorization: Bearer ${ADMIN_KEY}"     --header "Content-Type: application/json"     --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"email_confirm\":true}"     "${API_BASE}/auth/v1/admin/users"
)"

if [[ "${create_code}" != "200" && "${create_code}" != "201" ]]; then
  echo "Failed to create disposable authenticated user: HTTP ${create_code}"
  cat "${create_body}"
  exit 1
fi

USER_ID="$(
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))' < "${create_body}"
)"

if [[ -z "${USER_ID}" ]]; then
  echo "Disposable user creation did not return an id."
  cat "${create_body}"
  exit 1
fi

signin_code="$(
  curl --silent --show-error     --output "${signin_body}"     --write-out "%{http_code}"     --request POST     --header "apikey: ${PUBLIC_KEY}"     --header "Content-Type: application/json"     --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"     "${API_BASE}/auth/v1/token?grant_type=password"
)"

if [[ "${signin_code}" != "200" ]]; then
  echo "Failed to sign in disposable authenticated user: HTTP ${signin_code}"
  cat "${signin_body}"
  exit 1
fi

ACCESS_TOKEN="$(
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))' < "${signin_body}"
)"

if [[ -z "${ACCESS_TOKEN}" ]]; then
  echo "Password sign-in did not return an access token."
  cat "${signin_body}"
  exit 1
fi

user_code="$(
  curl --silent --show-error     --output "${user_body}"     --write-out "%{http_code}"     --header "apikey: ${PUBLIC_KEY}"     --header "Authorization: Bearer ${ACCESS_TOKEN}"     "${API_BASE}/auth/v1/user"
)"

if [[ "${user_code}" != "200" ]]; then
  echo "Authenticated control failed: /auth/v1/user -> HTTP ${user_code}"
  cat "${user_body}"
  exit 1
fi

echo "PASS authenticated control: disposable user token is valid."

tables=(
  operational_areas systems scenarios scenario_versions scenario_owners
  scenario_version_impacted_areas scenario_version_systems scenario_slas
  treatments treatment_impacted_areas treatment_impact_measurements
  treatment_events treatment_escalations scenario_proposals
  scenario_proposal_owner_responses notifications_log governance_issues
)

for table in "${tables[@]}"; do
  body_file="$(mktemp)"
  http_code="$(
    curl --silent --show-error       --output "${body_file}"       --write-out "%{http_code}"       --header "apikey: ${PUBLIC_KEY}"       --header "Authorization: Bearer ${ACCESS_TOKEN}"       "${API_BASE}/rest/v1/${table}?select=*&limit=1"
  )"

  if [[ "${http_code}" != "401" && "${http_code}" != "403" ]]; then
    echo "Authenticated direct table read unexpectedly reached ${table}: HTTP ${http_code}"
    cat "${body_file}"
    rm -f "${body_file}"
    exit 1
  fi

  echo "PASS authenticated direct Data API denial: ${table} -> HTTP ${http_code}"
  rm -f "${body_file}"
done

declare -a mutations=(
  "POST|treatments|{\"scenario_id\":\"00000000-0000-0000-0000-000000000001\"}"
  "POST|scenario_owners|{\"scenario_id\":\"00000000-0000-0000-0000-000000000001\",\"owner_id\":\"00000000-0000-0000-0000-000000000002\"}"
  "PATCH|treatments?id=eq.00000000-0000-0000-0000-000000000001|{\"impact_summary\":\"unauthorized direct API audit\"}"
)

for entry in "${mutations[@]}"; do
  method="${entry%%|*}"
  rest="${entry#*|}"
  resource="${rest%%|*}"
  data="${rest#*|}"
  body_file="$(mktemp)"

  http_code="$(
    curl --silent --show-error       --output "${body_file}"       --write-out "%{http_code}"       --request "${method}"       --header "apikey: ${PUBLIC_KEY}"       --header "Authorization: Bearer ${ACCESS_TOKEN}"       --header "Content-Type: application/json"       --data "${data}"       "${API_BASE}/rest/v1/${resource}"
  )"

  if [[ "${http_code}" != "401" && "${http_code}" != "403" ]]; then
    echo "Authenticated direct mutation unexpectedly reached ${resource}: ${method} -> HTTP ${http_code}"
    cat "${body_file}"
    rm -f "${body_file}"
    exit 1
  fi

  echo "PASS authenticated direct mutation denial: ${resource} ${method} -> HTTP ${http_code}"
  rm -f "${body_file}"
done

echo "PASS C05 authenticated direct API smoke: valid authenticated token, zero direct table surface."
