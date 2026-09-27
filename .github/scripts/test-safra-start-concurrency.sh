#!/usr/bin/env bash
set -euo pipefail

eval "$(supabase status -o env)"

DB_URL="${DB_URL:-}"
: "${DB_URL:?Supabase local DB_URL was not exported}"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required for the C02 concurrency test."
  exit 1
fi

USER_ID="02020202-1111-4111-8111-111111111111"
SESSION_ID="02020202-1111-4111-8111-111111111112"
IDEMPOTENCY_KEY="02020202-1111-4111-8111-111111111113"
EMAIL="c02.concurrent@editoradobrasil.com.br"
CLAIMS="{\"sub\":\"${USER_ID}\",\"email\":\"${EMAIL}\",\"session_id\":\"${SESSION_ID}\",\"is_anonymous\":false,\"app_metadata\":{\"provider\":\"azure\"},\"exp\":4102444800}"

psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -q <<SQL
insert into auth.users(
  id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at
)
values(
  '${USER_ID}'::uuid,
  '${EMAIL}',
  '{"provider":"azure"}'::jsonb,
  true,false,clock_timestamp(),clock_timestamp()
);

insert into auth.sessions(id,user_id,created_at,updated_at)
values(
  '${SESSION_ID}'::uuid,
  '${USER_ID}'::uuid,
  clock_timestamp(),
  clock_timestamp()
);
SQL

out_one="$(mktemp)"
out_two="$(mktemp)"
cleanup() {
  rm -f "${out_one}" "${out_two}"
}
trap cleanup EXIT

(
  psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt <<SQL >"${out_one}"
begin;
set local request.jwt.claims = '${CLAIMS}';
select public.safra_start_treatment(
  (select id from public.scenarios where code='SAFRA-04'),
  '${IDEMPOTENCY_KEY}'::uuid,
  'C02 concurrent retry',
  '{}'::uuid[]
)->>'treatment_id';
select pg_sleep(2);
commit;
SQL
) &
pid_one=$!

sleep 0.25

(
  psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt <<SQL >"${out_two}"
begin;
set local request.jwt.claims = '${CLAIMS}';
select public.safra_start_treatment(
  (select id from public.scenarios where code='SAFRA-04'),
  '${IDEMPOTENCY_KEY}'::uuid,
  'C02 concurrent retry',
  '{}'::uuid[]
)->>'treatment_id';
commit;
SQL
) &
pid_two=$!

wait "${pid_one}"
wait "${pid_two}"

id_one="$(grep -E '^[0-9a-fA-F-]{36}$' "${out_one}" | head -n1)"
id_two="$(grep -E '^[0-9a-fA-F-]{36}$' "${out_two}" | head -n1)"

if [[ -z "${id_one}" || -z "${id_two}" ]]; then
  echo "Concurrency test did not return treatment ids."
  cat "${out_one}"
  cat "${out_two}"
  exit 1
fi

if [[ "${id_one}" != "${id_two}" ]]; then
  echo "Concurrent retry returned different treatment ids: ${id_one} vs ${id_two}"
  exit 1
fi

treatment_count="$(
  psql "${DB_URL}" -X -qAt -c "select count(*) from public.treatments where start_idempotency_key='${IDEMPOTENCY_KEY}';"
)"
event_count="$(
  psql "${DB_URL}" -X -qAt -c "select count(*) from public.treatment_events e join public.treatments t on t.id=e.treatment_id where t.start_idempotency_key='${IDEMPOTENCY_KEY}' and e.event_type='TREATMENT_OPENED';"
)"

if [[ "${treatment_count}" != "1" ]]; then
  echo "Expected exactly one treatment after concurrent retry; got ${treatment_count}."
  exit 1
fi

if [[ "${event_count}" != "1" ]]; then
  echo "Expected exactly one TREATMENT_OPENED event after concurrent retry; got ${event_count}."
  exit 1
fi

echo "PASS C02 concurrent START retry: same treatment ${id_one}, one treatment row, one opening event."
