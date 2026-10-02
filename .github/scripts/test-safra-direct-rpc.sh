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


# C08: START RPCs are authenticated-only. Anonymous calls remain denied.
declare -a start_rpcs=(
  "safra_get_start_catalog|{}"
  "safra_start_treatment|{\"p_scenario_id\":\"00000000-0000-0000-0000-000000000001\",\"p_idempotency_key\":\"00000000-0000-4000-8000-000000000002\",\"p_impact_summary\":null,\"p_impacted_area_ids\":[]}"
)

for entry in "${start_rpcs[@]}"; do
  rpc_name="${entry%%|*}"
  data="${entry#*|}"
  body_file="$(mktemp)"
  http_code="$(
    curl --silent --show-error \
      --output "${body_file}" \
      --write-out "%{http_code}" \
      --request POST \
      --header "apikey: ${PUBLIC_KEY}" \
      --header "Content-Type: application/json" \
      --data "${data}" \
      "${API_BASE}/rest/v1/rpc/${rpc_name}"
  )"

  if [[ "${http_code}" != "401" && "${http_code}" != "403" ]]; then
    echo "Direct anonymous RPC unexpectedly succeeded: ${rpc_name} -> HTTP ${http_code}"
    cat "${body_file}"
    rm -f "${body_file}"
    exit 1
  fi

  echo "PASS direct anonymous RPC denial: ${rpc_name} -> HTTP ${http_code}"
  rm -f "${body_file}"
done


# C02: every public browser-facing Safra/RBAC RPC must reject anonymous callers.
declare -a c02_rpcs=(
  "safra_session_is_live|{}"
  "get_my_safra_roles|{}"
  "safra_has_role|{\"requested_role\":\"safra_platform_admin\"}"
  "get_safra_rbac_audit_events|{\"p_limit\":5}"
  "safra_get_my_treatments|{}"
  "safra_get_owner_treatments|{}"
  "safra_log_ops_event|{\"p_kind\":\"CLIENT_ERROR\"}"
  "safra_admin_get_ops_summary|{}"
  "safra_can_use_chameleon|{}"
  "safra_admin_get_owner_treatments|{\"p_owner_principal_id\":\"00000000-0000-4000-8000-000000000000\"}"
  "safra_close_my_part|{\"p_treatment_id\":\"00000000-0000-4000-8000-000000000000\"}"
  "safra_cancel_treatment|{\"p_treatment_id\":\"00000000-0000-4000-8000-000000000000\",\"p_reason\":\"anonymous smoke\"}"
)

for entry in "${c02_rpcs[@]}"; do
  rpc_name="${entry%%|*}"
  data="${entry#*|}"
  body_file="$(mktemp)"
  http_code="$(
    curl --silent --show-error \
      --output "${body_file}" \
      --write-out "%{http_code}" \
      --request POST \
      --header "apikey: ${PUBLIC_KEY}" \
      --header "Content-Type: application/json" \
      --data "${data}" \
      "${API_BASE}/rest/v1/rpc/${rpc_name}"
  )"

  if [[ "${http_code}" != "401" && "${http_code}" != "403" && "${http_code}" != "404" ]]; then
    echo "Direct anonymous RPC unexpectedly succeeded: ${rpc_name} -> HTTP ${http_code}"
    cat "${body_file}"
    rm -f "${body_file}"
    exit 1
  fi

  echo "PASS direct anonymous RPC denial: ${rpc_name} -> HTTP ${http_code}"
  rm -f "${body_file}"
done
