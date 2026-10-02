#!/usr/bin/env bash
# C08.1 — RPC-level race: the requester has closed his part; then, at the same time, the card
# owner closes the last part (-> RESOLVED) and the requester cancels. The row lock in the RPCs
# must let exactly one win; the loser gets SAFRA_TREATMENT_NOT_ACTIVE and history stays coherent.
set -euo pipefail

eval "$(supabase status -o env)"

DB_URL="${DB_URL:-}"
: "${DB_URL:?Supabase local DB_URL was not exported}"

REQ_ID="08180818-1111-4111-8111-1111111111aa"
REQ_SESSION="08180818-1111-4111-8111-1111111111ab"
REQ_EMAIL="c081.race.requester@editoradobrasil.com.br"
OWN_ID="08180818-1111-4111-8111-1111111111ba"
OWN_SESSION="08180818-1111-4111-8111-1111111111bb"
IDEMPOTENCY_KEY="08180818-1111-4111-8111-1111111111cc"

OWN_EMAIL="$(psql "${DB_URL}" -X -qAt -c "select corporate_email from private.safra_principals where display_name='Renato de Paulo';")"
: "${OWN_EMAIL:?owner principal of SAFRA-09 not found}"

claims() {
  echo "{\"sub\":\"$1\",\"email\":\"$2\",\"session_id\":\"$3\",\"is_anonymous\":false,\"app_metadata\":{\"provider\":\"azure\"},\"exp\":4102444800}"
}
REQ_CLAIMS="$(claims "${REQ_ID}" "${REQ_EMAIL}" "${REQ_SESSION}")"
OWN_CLAIMS="$(claims "${OWN_ID}" "${OWN_EMAIL}" "${OWN_SESSION}")"

psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -q <<SQL
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('${REQ_ID}'::uuid,'${REQ_EMAIL}','{"provider":"azure"}'::jsonb,true,false,clock_timestamp(),clock_timestamp()),
  ('${OWN_ID}'::uuid,'${OWN_EMAIL}','{"provider":"azure"}'::jsonb,true,false,clock_timestamp(),clock_timestamp());
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
values
  ('${REQ_ID}','${REQ_ID}'::uuid,'{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}','azure',clock_timestamp(),clock_timestamp()),
  ('${OWN_ID}','${OWN_ID}'::uuid,'{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}','azure',clock_timestamp(),clock_timestamp());
insert into auth.sessions(id,user_id,created_at,updated_at)
values
  ('${REQ_SESSION}'::uuid,'${REQ_ID}'::uuid,clock_timestamp(),clock_timestamp()),
  ('${OWN_SESSION}'::uuid,'${OWN_ID}'::uuid,clock_timestamp(),clock_timestamp());
SQL

TREATMENT_ID="$(
  psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt <<SQL
begin;
set local request.jwt.claims = '${REQ_CLAIMS}';
select public.safra_start_treatment(
  (select id from public.scenarios where code='SAFRA-09'),
  '${IDEMPOTENCY_KEY}'::uuid, 'C08.1 corrida encerrar x cancelar', '{}'::uuid[]
)->>'treatment_id';
commit;
SQL
)"
TREATMENT_ID="$(echo "${TREATMENT_ID}" | grep -E '^[0-9a-fA-F-]{36}$' | head -n1)"
: "${TREATMENT_ID:?START did not return a treatment id}"

psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt >/dev/null <<SQL
begin;
set local request.jwt.claims = '${REQ_CLAIMS}';
select public.safra_close_my_part('${TREATMENT_ID}'::uuid);
commit;
SQL

out_close="$(mktemp)"; out_cancel="$(mktemp)"
trap 'rm -f "${out_close}" "${out_cancel}"' EXIT

(
  psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt >"${out_close}" 2>&1 <<SQL
begin;
set local request.jwt.claims = '${OWN_CLAIMS}';
select public.safra_close_my_part('${TREATMENT_ID}'::uuid)->>'situation';
select pg_sleep(2);
commit;
SQL
) &
pid_close=$!

sleep 0.5

(
  psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt >"${out_cancel}" 2>&1 <<SQL
begin;
set local request.jwt.claims = '${REQ_CLAIMS}';
select public.safra_cancel_treatment('${TREATMENT_ID}'::uuid, 'Cancelamento concorrente do teste');
commit;
SQL
) &
pid_cancel=$!

close_status=0; wait "${pid_close}" || close_status=$?
cancel_status=0; wait "${pid_cancel}" || cancel_status=$?

final="$(psql "${DB_URL}" -X -qAt -c "select status||'|'||coalesce(cancellation_reason,'') from public.treatments where id='${TREATMENT_ID}';")"
events="$(psql "${DB_URL}" -X -qAt -c "select string_agg(event_type, ',' order by occurred_at) from public.treatment_events where treatment_id='${TREATMENT_ID}';")"

echo "CLOSE exit=${close_status}; CANCEL exit=${cancel_status}; final=${final}; events=${events}"

if [[ "${close_status}" != "0" ]] || ! grep -q "ENCERRADO" "${out_close}"; then
  echo "The owner closing the last part should have committed as ENCERRADO."
  cat "${out_close}"
  exit 1
fi

if [[ "${cancel_status}" == "0" ]] || ! grep -q "SAFRA_TREATMENT_NOT_ACTIVE" "${out_cancel}"; then
  echo "The concurrent cancel must wait for the row lock and then be refused as not active."
  cat "${out_cancel}"
  exit 1
fi

if [[ "${final}" != "RESOLVED|" ]]; then
  echo "Expected RESOLVED without cancellation data; got ${final}."
  exit 1
fi

if [[ "${events}" != "TREATMENT_OPENED,REQUESTER_PART_CLOSED,OWNER_PART_CLOSED,TREATMENT_RESOLVED" ]]; then
  echo "Unexpected event history: ${events}"
  exit 1
fi

echo "PASS C08.1 close x cancel RPC race: one winner, loser refused, history coherent."
