#!/usr/bin/env bash
# C09 — restore drill (cronometrado). Simula a perda total do banco e a recuperação:
#   1. fotografia dos dados (contagens e assinatura dos protocolos);
#   2. cópia de segurança lógica (pg_dump dos dados do Painel e dos logins);
#   3. "desastre": banco apagado e recriado só a partir de supabase/migrations;
#   4. restauração da cópia;
#   5. conferência: mesmos números, mesma assinatura, Painel funcionando (abrir protocolo).
# Mede o tempo de cada etapa (referência para o RTO do runbook).
set -euo pipefail

eval "$(supabase status -o env)"
DB_URL="${DB_URL:-}"
: "${DB_URL:?Supabase local DB_URL was not exported}"
PROJECT_ID="$(sed -n 's/^project_id = "\(.*\)"/\1/p' supabase/config.toml)"
CONTAINER="supabase_db_${PROJECT_ID}"
BACKUP="$(mktemp)"
trap 'rm -f "${BACKUP}"' EXIT

q() { psql "${DB_URL}" -X -v ON_ERROR_STOP=1 -qAt "$@"; }
admin_psql() { docker exec -i "${CONTAINER}" psql -U supabase_admin -d postgres -X -v ON_ERROR_STOP=1 -qAt "$@"; }

SNAPSHOT_SQL="
select json_build_object(
  'treatments', (select count(*) from public.treatments),
  'events', (select count(*) from public.treatment_events),
  'resolved', (select count(*) from public.treatments where status = 'RESOLVED'),
  'cancelled', (select count(*) from public.treatments where status = 'CANCELLED'),
  'principals_bound', (select count(*) from private.safra_principals where user_id is not null),
  'role_grants', (select count(*) from private.safra_role_grants),
  'audit_events', (select count(*) from private.safra_rbac_audit_events),
  'ops_events', (select count(*) from public.ops_events),
  'auth_users', (select count(*) from auth.users),
  'protocols_md5', (select md5(coalesce(string_agg(protocol_number || ':' || status || ':' || opened_at::text, ',' order by protocol_number), '')) from public.treatments)
)::text;"

before="$(q -c "${SNAPSHOT_SQL}")"
echo "Before: ${before}"

t0=$(date +%s)
docker exec "${CONTAINER}" pg_dump -U supabase_admin -d postgres --data-only --disable-triggers --no-owner \
  -t 'public.*' -t 'private.*' -t 'auth.users' -t 'auth.identities' -t 'auth.sessions' > "${BACKUP}"
t1=$(date +%s)
echo "Backup size: $(wc -c < "${BACKUP}") bytes"

# Desastre: o banco volta ao estado das migrations (o que se reconstrói sozinho).
supabase db reset --local
t2=$(date +%s)
echo "After rebuild (migrations only): $(q -c "${SNAPSHOT_SQL}")"

# Restauração: limpa o que as migrations semearam e carrega a cópia.
{
  echo "begin;"
  echo "set session_replication_role = replica;"
  echo "truncate table auth.users cascade;"
  q -c "select 'truncate table ' || string_agg(format('%I.%I', schemaname, tablename), ', ') || ' cascade;'
        from pg_tables where schemaname in ('public', 'private');"
  cat "${BACKUP}"
  echo "commit;"
} | admin_psql > /dev/null
t3=$(date +%s)

after="$(q -c "${SNAPSHOT_SQL}")"
echo "After restore: ${after}"

if [[ "${before}" != "${after}" ]]; then
  echo "FAIL restore drill: data after restore differs from before"
  exit 1
fi
echo "PASS restore drill: counts and protocol signature identical"

# O Painel funciona depois da restauração: um usuário restaurado abre um protocolo.
user_row="$(q -c "select u.id || '|' || u.email from auth.users u
                  join auth.identities i on i.user_id = u.id and i.provider = 'azure'
                  where u.email like 'load.user%' order by u.email limit 1;")"
uid="${user_row%%|*}"; email="${user_row#*|}"
sid="$(q -c "insert into auth.sessions(id,user_id,created_at,updated_at) values (gen_random_uuid(), '${uid}', now(), now()) returning id;")"
claims="{\"sub\":\"${uid}\",\"email\":\"${email}\",\"session_id\":\"${sid}\",\"is_anonymous\":false,\"app_metadata\":{\"provider\":\"azure\"},\"exp\":4102444800}"
max_before="$(q -c "select coalesce(max(protocol_seq), 0) from public.treatments t join public.scenarios s on s.id = t.scenario_id where s.code = 'SAFRA-06';")"
number="$(q <<SQL | tail -n1
begin;
set local request.jwt.claims = '${claims}';
select public.safra_start_treatment((select id from public.scenarios where code = 'SAFRA-06'), gen_random_uuid(),
  'Ensaio de restauração: Painel funcionando', '{}'::uuid[])->>'protocol_number';
commit;
SQL
)"
expected="06-$(printf '%04d' $(( max_before + 1 )))"
if [[ "${number}" != "${expected}" ]]; then
  echo "FAIL restore drill: START after restore returned ${number}, expected ${expected}"
  exit 1
fi
t4=$(date +%s)
echo "PASS restore drill: Painel works after restore (new protocol ${number} continues the sequence)"
echo "Timing: backup $(( t1 - t0 ))s, rebuild $(( t2 - t1 ))s, restore $(( t3 - t2 ))s, check $(( t4 - t3 ))s, total $(( t4 - t0 ))s"
