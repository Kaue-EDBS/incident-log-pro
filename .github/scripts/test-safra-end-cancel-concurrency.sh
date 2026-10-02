#!/usr/bin/env bash
# C05-AUD2 — END x CANCEL concurrency: two sessions try to close the same ACTIVE treatment at
# the same time, one as RESOLVED and one as CANCELLED. Exactly one terminal state must win;
# the loser must be rejected by the terminal guard and history must not be rewritten.
set -euo pipefail

eval "$(supabase status -o env)"

DB_URL="${DB_URL:-}"
: "${DB_URL:?Supabase local DB_URL was not exported}"

USER_ID="05050505-1111-4111-8111-111111111111"
SESSION_ID="05050505-1111-4111-8111-111111111112"
IDEMPOTENCY_KEY="05050505-1111-4111-8111-111111111113"
EMAIL="c05.endcancel@editoradobrasil.com.br"
CLAIMS="{\"sub\":\"${USER_ID}\",\"email\":\"${EMAIL}\",\"session_id\":\"${SESSION_ID}\",\"is_anonymous\":false,\"app_metadata\":{\"provider\":\"azure\"},\"exp\":4102444800}"

psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -q <<SQL
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values('${USER_ID}'::uuid,'${EMAIL}','{"provider":"azure"}'::jsonb,true,false,clock_timestamp(),clock_timestamp());

-- AUD-GERAL A-01: Microsoft identity of the corporate tenant for synthetic azure users.
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text,u.id,jsonb_build_object('sub',u.id::text,'email',u.email,'custom_claims',jsonb_build_object('tid','45ba725f-d260-45c3-ac85-11f433471277')),'azure',clock_timestamp(),clock_timestamp()
from auth.users u
where u.raw_app_meta_data->>'provider'='azure'
  and not exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='azure');
insert into auth.sessions(id,user_id,created_at,updated_at)
values('${SESSION_ID}'::uuid,'${USER_ID}'::uuid,clock_timestamp(),clock_timestamp());
SQL

TREATMENT_ID="$(
  psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt <<SQL
begin;
set local request.jwt.claims = '${CLAIMS}';
select public.safra_start_treatment(
  (select id from public.scenarios where code='SAFRA-07'),
  '${IDEMPOTENCY_KEY}'::uuid, 'C05 END x CANCEL', '{}'::uuid[]
)->>'treatment_id';
commit;
SQL
)"
TREATMENT_ID="$(echo "${TREATMENT_ID}" | grep -E '^[0-9a-fA-F-]{36}$' | head -n1)"
: "${TREATMENT_ID:?START did not return a treatment id}"

out_end="$(mktemp)"; out_cancel="$(mktemp)"
trap 'rm -f "${out_end}" "${out_cancel}"' EXIT

(
  psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt >"${out_end}" 2>&1 <<SQL
begin;
update public.treatments
   set status='RESOLVED', closed_by='${USER_ID}'::uuid, closed_at=clock_timestamp()
 where id='${TREATMENT_ID}'::uuid;
select pg_sleep(2);
commit;
SQL
) &
pid_end=$!

sleep 0.5

(
  psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt >"${out_cancel}" 2>&1 <<SQL
begin;
update public.treatments
   set status='CANCELLED', cancelled_by='${USER_ID}'::uuid, cancelled_at=clock_timestamp(),
       cancellation_reason='C05 concurrent cancel'
 where id='${TREATMENT_ID}'::uuid;
commit;
SQL
) &
pid_cancel=$!

end_status=0; wait "${pid_end}" || end_status=$?
cancel_status=0; wait "${pid_cancel}" || cancel_status=$?

final="$(psql "${DB_URL}" -X -qAt -c "select status||'|'||coalesce(cancellation_reason,'') from public.treatments where id='${TREATMENT_ID}';")"

echo "END session exit=${end_status}; CANCEL session exit=${cancel_status}; final=${final}"
cat "${out_cancel}"

if [[ "${end_status}" != "0" ]]; then
  echo "The first terminal transition (END) should have committed."
  cat "${out_end}"
  exit 1
fi

if [[ "${cancel_status}" == "0" ]]; then
  echo "The concurrent CANCEL must be rejected after END wins."
  exit 1
fi

if ! grep -q "closed treatment row is immutable" "${out_cancel}"; then
  echo "CANCEL was rejected, but not by the terminal immutability guard."
  exit 1
fi

if [[ "${final}" != "RESOLVED|" ]]; then
  echo "Expected final state RESOLVED without cancellation data; got ${final}."
  exit 1
fi

echo "PASS C05 END x CANCEL concurrency: exactly one terminal transition, loser rejected, history intact."
