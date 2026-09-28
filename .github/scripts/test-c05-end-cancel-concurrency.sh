#!/usr/bin/env bash
set -euo pipefail

eval "$(supabase status -o env)"

DB_URL="${DB_URL:-}"
: "${DB_URL:?Supabase local DB_URL was not exported}"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required for the C05 END x CANCEL concurrency test."
  exit 1
fi

USER_ID="05050505-3000-4000-8000-000000000001"
EMAIL="c05.end-cancel.concurrent@example.invalid"
TREATMENT_END_FIRST="05050505-3000-4000-8000-000000000010"
TREATMENT_CANCEL_FIRST="05050505-3000-4000-8000-000000000020"

psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -q <<SQL
insert into auth.users(
  id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at
)
values(
  '${USER_ID}'::uuid,
  '${EMAIL}',
  '{"provider":"email"}'::jsonb,
  false,false,clock_timestamp(),clock_timestamp()
);

insert into public.treatments(
  id,scenario_id,scenario_version_id,status,opened_by,
  owner_id_at_start,responsible_area_id_at_start,
  impact_summary,start_correlation_id,start_idempotency_key
)
select
  '${TREATMENT_END_FIRST}'::uuid,
  sc.id,sc.current_version_id,'ACTIVE','${USER_ID}'::uuid,
  so.owner_id,sc.responsible_area_id,
  'C05 END wins concurrency fixture',
  '05050505-3000-4000-8000-000000000011'::uuid,
  'c05-end-first'
from public.scenarios sc
join public.scenario_owners so on so.scenario_id=sc.id and so.valid_to is null
where sc.code='SAFRA-01';

insert into public.treatments(
  id,scenario_id,scenario_version_id,status,opened_by,
  owner_id_at_start,responsible_area_id_at_start,
  impact_summary,start_correlation_id,start_idempotency_key
)
select
  '${TREATMENT_CANCEL_FIRST}'::uuid,
  sc.id,sc.current_version_id,'ACTIVE','${USER_ID}'::uuid,
  so.owner_id,sc.responsible_area_id,
  'C05 CANCEL wins concurrency fixture',
  '05050505-3000-4000-8000-000000000021'::uuid,
  'c05-cancel-first'
from public.scenarios sc
join public.scenario_owners so on so.scenario_id=sc.id and so.valid_to is null
where sc.code='SAFRA-02';
SQL

run_end_first() {
  local end_out cancel_out
  end_out="$(mktemp)"
  cancel_out="$(mktemp)"

  (
    psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt <<SQL >"${end_out}" 2>&1
begin;
set local statement_timeout = '15s';
update public.treatments
   set status='RESOLVED',
       closed_by='${USER_ID}'::uuid
 where id='${TREATMENT_END_FIRST}'::uuid;
select pg_sleep(2);
commit;
SQL
  ) &
  local end_pid=$!

  sleep 0.25

  (
    psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt <<SQL >"${cancel_out}" 2>&1
begin;
set local statement_timeout = '15s';
update public.treatments
   set status='CANCELLED',
       cancelled_by='${USER_ID}'::uuid,
       cancellation_reason='concurrent cancel must lose'
 where id='${TREATMENT_END_FIRST}'::uuid;
commit;
SQL
  ) &
  local cancel_pid=$!

  set +e
  wait "${end_pid}"; local end_rc=$?
  wait "${cancel_pid}"; local cancel_rc=$?
  set -e

  if [[ "${end_rc}" -ne 0 || "${cancel_rc}" -eq 0 ]]; then
    echo "END-first race failed: expected END success and CANCEL rejection."
    echo "--- END output ---"; cat "${end_out}"
    echo "--- CANCEL output ---"; cat "${cancel_out}"
    rm -f "${end_out}" "${cancel_out}"
    exit 1
  fi

  local state
  state="$(psql "${DB_URL}" -X -qAt -c "
    select status || '|' ||
           (closed_at is not null)::text || '|' ||
           (closed_by='${USER_ID}'::uuid)::text || '|' ||
           (cancelled_at is null)::text || '|' ||
           (cancelled_by is null)::text || '|' ||
           (cancellation_reason is null)::text
    from public.treatments
    where id='${TREATMENT_END_FIRST}'::uuid;
  ")"

  if [[ "${state}" != "RESOLVED|true|true|true|true|true" ]]; then
    echo "END-first race left an invalid terminal state: ${state}"
    rm -f "${end_out}" "${cancel_out}"
    exit 1
  fi

  echo "PASS C05 END-first concurrency: END committed, concurrent CANCEL rejected."
  rm -f "${end_out}" "${cancel_out}"
}

run_cancel_first() {
  local cancel_out end_out
  cancel_out="$(mktemp)"
  end_out="$(mktemp)"

  (
    psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt <<SQL >"${cancel_out}" 2>&1
begin;
set local statement_timeout = '15s';
update public.treatments
   set status='CANCELLED',
       cancelled_by='${USER_ID}'::uuid,
       cancellation_reason='concurrent cancel wins'
 where id='${TREATMENT_CANCEL_FIRST}'::uuid;
select pg_sleep(2);
commit;
SQL
  ) &
  local cancel_pid=$!

  sleep 0.25

  (
    psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt <<SQL >"${end_out}" 2>&1
begin;
set local statement_timeout = '15s';
update public.treatments
   set status='RESOLVED',
       closed_by='${USER_ID}'::uuid
 where id='${TREATMENT_CANCEL_FIRST}'::uuid;
commit;
SQL
  ) &
  local end_pid=$!

  set +e
  wait "${cancel_pid}"; local cancel_rc=$?
  wait "${end_pid}"; local end_rc=$?
  set -e

  if [[ "${cancel_rc}" -ne 0 || "${end_rc}" -eq 0 ]]; then
    echo "CANCEL-first race failed: expected CANCEL success and END rejection."
    echo "--- CANCEL output ---"; cat "${cancel_out}"
    echo "--- END output ---"; cat "${end_out}"
    rm -f "${cancel_out}" "${end_out}"
    exit 1
  fi

  local state
  state="$(psql "${DB_URL}" -X -qAt -c "
    select status || '|' ||
           (cancelled_at is not null)::text || '|' ||
           (cancelled_by='${USER_ID}'::uuid)::text || '|' ||
           (cancellation_reason='concurrent cancel wins')::text || '|' ||
           (closed_at is null)::text || '|' ||
           (closed_by is null)::text
    from public.treatments
    where id='${TREATMENT_CANCEL_FIRST}'::uuid;
  ")"

  if [[ "${state}" != "CANCELLED|true|true|true|true|true" ]]; then
    echo "CANCEL-first race left an invalid terminal state: ${state}"
    rm -f "${cancel_out}" "${end_out}"
    exit 1
  fi

  echo "PASS C05 CANCEL-first concurrency: CANCEL committed, concurrent END rejected."
  rm -f "${cancel_out}" "${end_out}"
}

run_end_first
run_cancel_first

echo "PASS C05 END x CANCEL real concurrency: exactly one terminal transition wins in both lock orders."
