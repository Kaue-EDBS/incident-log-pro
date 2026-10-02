#!/usr/bin/env bash
# C08.3 — stress smoke: many people opening, closing and cancelling at the same time.
# Phase 1: 20 people x 11 cards = 220 STARTs in parallel.
# Phase 2: one person, one card, 30 parallel STARTs with different keys -> exactly 1 opens.
# Phase 3: one person, one card, 30 parallel STARTs with the SAME key -> 1 protocol, 30 replies.
# Phase 4: for the 220 protocols, requester close, owner close and (1 in 3) requester cancel
#          race in parallel.
# Then the database invariants are checked and latency is reported (p50/p95/max).
set -euo pipefail

eval "$(supabase status -o env)"
DB_URL="${DB_URL:-}"
: "${DB_URL:?Supabase local DB_URL was not exported}"

PARALLEL="${STRESS_PARALLEL:-40}"
TENANT="45ba725f-d260-45c3-ac85-11f433471277"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

q() { psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt "$@"; }

# --- people -------------------------------------------------------------------
q <<SQL
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select ('5e000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
       'stress.user' || n || '@editoradobrasil.com.br', '{"provider":"azure"}', true, false, now(), now()
from generate_series(1, 22) n;

insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select ('5e000000-0000-4000-9000-' || lpad(row_number() over (order by p.display_name)::text, 12, '0'))::uuid,
       p.corporate_email, '{"provider":"azure"}', true, false, now(), now()
from private.safra_principals p
where p.display_name in ('Daniel Garcia', 'Jiane Rodrigues', 'Renato de Paulo')
  and p.user_id is null;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, jsonb_build_object('custom_claims', jsonb_build_object('tid', '${TENANT}')), 'azure', now(), now()
from auth.users u where u.id::text like '5e000000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select u.id, u.id, now(), now() from auth.users u where u.id::text like '5e000000-%';

-- Owners may already be bound by earlier CI steps: give their login a session whose id
-- equals the user id, as the stress jobs expect.
insert into auth.sessions(id,user_id,created_at,updated_at)
select p.user_id, p.user_id, now(), now()
from private.safra_principals p
where p.display_name in ('Daniel Garcia', 'Jiane Rodrigues', 'Renato de Paulo')
  and p.user_id is not null
  and not exists (select 1 from auth.sessions s where s.id = p.user_id);
SQL

# user/session ids are equal for synthetic people (session id = user id)
claims_for() {
  local id="$1" email="$2"
  echo "{\"sub\":\"${id}\",\"email\":\"${email}\",\"session_id\":\"${id}\",\"is_anonymous\":false,\"app_metadata\":{\"provider\":\"azure\"},\"exp\":4102444800}"
}
export -f claims_for

# One job = "label|user_id|email|sql". Output: label|status|ms|message
run_job() {
  local line="$1" label id email body start end out rc
  IFS='|' read -r label id email body <<<"${line}"
  start=$(date +%s%N)
  set +e
  out="$(psql "${DB_URL}" -X -qAt -v ON_ERROR_STOP=1 2>&1 <<SQL
begin;
set local request.jwt.claims = '$(claims_for "${id}" "${email}")';
${body};
commit;
SQL
)"
  rc=$?
  set -e
  end=$(date +%s%N)
  local msg
  msg="$(echo "${out}" | grep -o 'SAFRA_[A-Z_]*' | head -n1)"
  if [[ ${rc} -eq 0 ]]; then
    echo "${label}|ok|$(( (end - start) / 1000000 ))|$(echo "${out}" | tail -n1)"
  else
    echo "${label}|err|$(( (end - start) / 1000000 ))|${msg:-$(echo "${out}" | tail -n1)}"
  fi
}
export -f run_job
export DB_URL

run_parallel() { tr '\n' '\0' < "$1" | xargs -0 -P "${PARALLEL}" -I{} bash -c 'run_job "$@"' _ {} > "$2"; }

# --- phase 1: 220 STARTs --------------------------------------------------------
q > "${WORK}/p1.jobs" <<'SQL'
select 'p1:' || n || ':' || sc.code || '|' || u.id || '|' || u.email || '|'
       || 'select public.safra_start_treatment(''' || sc.id || '''::uuid, gen_random_uuid(), ''Stress: problema ' || n || ' em ' || sc.code || ''', ''{}''::uuid[])->>''protocol_number'''
from generate_series(1, 20) n
join auth.users u on u.id = ('5e000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
cross join public.scenarios sc
where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
order by random();
SQL
t0=$(date +%s)
run_parallel "${WORK}/p1.jobs" "${WORK}/p1.out"
echo "Phase 1: $(grep -c '|ok|' "${WORK}/p1.out") ok / $(wc -l < "${WORK}/p1.jobs") jobs in $(( $(date +%s) - t0 ))s"

# --- phase 2: same person + card, 30 different keys -----------------------------
U21="5e000000-0000-4000-8000-000000000021"
for i in $(seq 1 30); do
  echo "p2:${i}|${U21}|stress.user21@editoradobrasil.com.br|select public.safra_start_treatment((select id from public.scenarios where code='SAFRA-01'), gen_random_uuid(), 'Stress: mesma pessoa e card', '{}'::uuid[])->>'protocol_number'"
done > "${WORK}/p2.jobs"
run_parallel "${WORK}/p2.jobs" "${WORK}/p2.out"

# --- phase 3: same key x30 --------------------------------------------------------
U22="5e000000-0000-4000-8000-000000000022"
KEY="5e000000-0000-4000-a000-000000000001"
for i in $(seq 1 30); do
  echo "p3:${i}|${U22}|stress.user22@editoradobrasil.com.br|select public.safra_start_treatment((select id from public.scenarios where code='SAFRA-02'), '${KEY}'::uuid, 'Stress: mesma chave', '{}'::uuid[])->>'treatment_id'"
done > "${WORK}/p3.jobs"
run_parallel "${WORK}/p3.jobs" "${WORK}/p3.out"

# --- phase 4: close / close / cancel storm ---------------------------------------
q > "${WORK}/p4.jobs" <<'SQL'
with t as (
  select t.id, t.opened_by, ru.email as req_email, ou.id as owner_id, ou.email as owner_email,
         row_number() over (order by t.id) as rn
  from public.treatments t
  join auth.users ru on ru.id = t.opened_by
  join public.scenario_owners so on so.scenario_id = t.scenario_id and so.valid_to is null
  join private.safra_principals p on p.id = so.owner_id
  join auth.users ou on ou.id = p.user_id
  where ru.email like 'stress.user%' and t.status = 'ACTIVE'
    and t.opened_by <> '5e000000-0000-4000-8000-000000000022'::uuid
)
select line from (
  select random() r, 'p4:req:' || id || '|' || opened_by || '|' || req_email || '|select public.safra_close_my_part(''' || id || '''::uuid)->>''situation''' as line from t
  union all
  select random(), 'p4:own:' || id || '|' || owner_id || '|' || owner_email || '|select public.safra_close_my_part(''' || id || '''::uuid)->>''situation''' from t
  union all
  select random(), 'p4:can:' || id || '|' || opened_by || '|' || req_email || '|select public.safra_cancel_treatment(''' || id || '''::uuid, ''Stress: cancelamento concorrente'')->>''situation''' from t where rn % 3 = 0
  union all
  -- M01 (D-99): desfazer no meio da tempestade
  select random(), 'p4:undo:' || id || '|' || opened_by || '|' || req_email || '|select public.safra_undo_my_part(''' || id || '''::uuid)->>''situation''' from t where rn % 4 = 1
) x order by r;
SQL
t0=$(date +%s)
run_parallel "${WORK}/p4.jobs" "${WORK}/p4.out"
echo "Phase 4: $(wc -l < "${WORK}/p4.jobs") jobs in $(( $(date +%s) - t0 ))s, $(grep '^p4:undo:' "${WORK}/p4.out" | grep -c '|ok|' || true) undos succeeded"

# --- phase 5: whoever had the part undone concludes again --------------------------
q > "${WORK}/p5.jobs" <<'SQL'
select 'p5:req:' || t.id || '|' || t.opened_by || '|' || ru.email || '|select public.safra_close_my_part(''' || t.id || '''::uuid)->>''situation'''
from public.treatments t join auth.users ru on ru.id = t.opened_by
where ru.email like 'stress.user%' and t.status = 'ACTIVE' and t.requester_closed_at is null
  and t.opened_by not in ('5e000000-0000-4000-8000-000000000021'::uuid, '5e000000-0000-4000-8000-000000000022'::uuid);
SQL
if [[ -s "${WORK}/p5.jobs" ]]; then run_parallel "${WORK}/p5.jobs" "${WORK}/p5.out"; else : > "${WORK}/p5.out"; fi

# --- checks -------------------------------------------------------------------------
fail=0
check() { if [[ "$2" != "$3" ]]; then echo "FAIL $1: expected $3, got $2"; fail=1; else echo "PASS $1 ($2)"; fi; }

check "phase 1 all STARTs succeeded" "$(grep -c '|ok|' "${WORK}/p1.out")" "220"
check "phase 1 protocol numbers per card are 20 consecutive numbers, no gaps or duplicates" "$(q -c "
  select count(*) from (
    select scenario_id, count(*) c, count(distinct protocol_seq) d, min(protocol_seq) mi, max(protocol_seq) ma
    from public.treatments t join auth.users u on u.id = t.opened_by
    where u.email like 'stress.user%' and u.email not in ('stress.user21@editoradobrasil.com.br','stress.user22@editoradobrasil.com.br')
    group by scenario_id) x
  where c = 20 and d = 20 and ma - mi = 19;")" "11"
check "phase 2 exactly one START for the same person and card" "$(grep -c '|ok|' "${WORK}/p2.out")" "1"
check "phase 2 the others were refused by the lock" "$(grep -c 'SAFRA_START_ACTIVE_EXISTS' "${WORK}/p2.out")" "29"
check "phase 3 same key -> one protocol" "$(q -c "select count(*) from public.treatments where start_idempotency_key = '${KEY}';")" "1"
check "phase 3 all 30 replies point to the same protocol" "$(cut -d'|' -f4 "${WORK}/p3.out" | sort -u | wc -l | tr -d ' ')" "1"
check "phase 3 one TREATMENT_OPENED event" "$(q -c "select count(*) from public.treatment_events e join public.treatments t on t.id = e.treatment_id where t.start_idempotency_key = '${KEY}' and e.event_type = 'TREATMENT_OPENED';")" "1"
check "phase 4 no unexpected errors" "$(grep '|err|' "${WORK}/p4.out" | grep -v -E -c 'SAFRA_TREATMENT_NOT_ACTIVE|SAFRA_UNDO_NOTHING_TO_UNDO' || true)" "0"
check "phase 5 no errors when concluding again" "$(grep -c '|err|' "${WORK}/p5.out" || true)" "0"
check "phase 4 no protocol left ACTIVE with both parts closed" "$(q -c "select count(*) from public.treatments where status = 'ACTIVE' and requester_closed_at is not null and owner_closed_at is not null;")" "0"
check "phase 4 every stress protocol ended RESOLVED or CANCELLED" "$(q -c "
  select count(*) from public.treatments t join auth.users u on u.id = t.opened_by
  where u.email like 'stress.user%' and u.id <> '5e000000-0000-4000-8000-000000000022'::uuid and u.id <> '5e000000-0000-4000-8000-000000000021'::uuid
    and t.status = 'ACTIVE';")" "0"
check "phase 4 no protocol both resolved and cancelled" "$(q -c "
  select count(*) from public.treatments t
  where exists (select 1 from public.treatment_events e where e.treatment_id = t.id and e.event_type = 'TREATMENT_RESOLVED')
    and exists (select 1 from public.treatment_events e where e.treatment_id = t.id and e.event_type = 'TREATMENT_CANCELLED');")" "0"
check "phase 4 part events add up (closed - undone is 0 or 1; one terminal event at most)" "$(q -c "
  select count(*) from (
    select treatment_id,
      count(*) filter (where event_type = 'REQUESTER_PART_CLOSED') - count(*) filter (where event_type = 'REQUESTER_PART_UNDONE') rq,
      count(*) filter (where event_type = 'OWNER_PART_CLOSED') - count(*) filter (where event_type = 'OWNER_PART_UNDONE') ow,
      count(*) filter (where event_type = 'TREATMENT_RESOLVED') rs,
      count(*) filter (where event_type = 'TREATMENT_CANCELLED') cn
    from public.treatment_events group by 1) x
  where rq not in (0, 1) or ow not in (0, 1) or rs > 1 or cn > 1;")" "0"
check "phase 4 closed parts match their events" "$(q -c "
  select count(*) from public.treatments t join auth.users u on u.id = t.opened_by
  where u.email like 'stress.user%'
    and ((t.requester_closed_at is not null) <> ((select count(*) filter (where e.event_type = 'REQUESTER_PART_CLOSED') - count(*) filter (where e.event_type = 'REQUESTER_PART_UNDONE') from public.treatment_events e where e.treatment_id = t.id) = 1)
      or (t.owner_closed_at is not null) <> ((select count(*) filter (where e.event_type = 'OWNER_PART_CLOSED') - count(*) filter (where e.event_type = 'OWNER_PART_UNDONE') from public.treatment_events e where e.treatment_id = t.id) = 1));")" "0"
check "phase 4 RESOLVED status matches its event" "$(q -c "
  select count(*) from public.treatments t join auth.users u on u.id = t.opened_by
  where u.email like 'stress.user%'
    and (t.status = 'RESOLVED') <> exists (select 1 from public.treatment_events e where e.treatment_id = t.id and e.event_type = 'TREATMENT_RESOLVED');")" "0"
check "M02 the history rebuilds every status (cancel and open events present)" "$(q -c "
  select count(*) from public.treatments t join auth.users u on u.id = t.opened_by
  where u.email like 'stress.user%'
    and ((t.status = 'CANCELLED') <> exists (select 1 from public.treatment_events e where e.treatment_id = t.id and e.event_type = 'TREATMENT_CANCELLED')
      or not exists (select 1 from public.treatment_events e where e.treatment_id = t.id and e.event_type = 'TREATMENT_OPENED'));")" "0"

# --- latency --------------------------------------------------------------------
cat "${WORK}"/p*.out | cut -d'|' -f3 | sort -n > "${WORK}/lat"
n=$(wc -l < "${WORK}/lat")
p50=$(sed -n "$(( (n * 50 + 99) / 100 ))p" "${WORK}/lat")
p95=$(sed -n "$(( (n * 95 + 99) / 100 ))p" "${WORK}/lat")
max=$(tail -n1 "${WORK}/lat")
echo "Latency over ${n} calls (ms, includes psql connection): p50=${p50} p95=${p95} max=${max}"
if (( p95 > 5000 )); then echo "FAIL latency p95 above 5000 ms"; fail=1; fi

if [[ ${fail} -ne 0 ]]; then
  echo "--- sample of errors ---"; grep -h '|err|' "${WORK}"/p*.out | sed -n '1,20p' || true
  exit 1
fi
echo "PASS C08.3 stress smoke"
