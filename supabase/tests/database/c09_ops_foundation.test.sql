begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

-- U = corporate user; A = platform admin (Vinicius); X = non-corporate Microsoft account.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, coalesce(p.corporate_email, v.email), '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values
  ('c0900000-0000-4000-8000-00000000000a', 'c09.user@editoradobrasil.com.br', null),
  ('c0900000-0000-4000-8000-00000000000b', null, 'Vinicius Moraes'),
  ('c0900000-0000-4000-8000-00000000000c', 'outsider@example.com', null)
) as v(id, email, who)
left join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'c0900000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('c0900000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'c0900000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'c0900000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('c0900000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

-- 1. Logging --------------------------------------------------------------------------
select pg_temp.act_as('0a');
select lives_ok($$ select public.safra_log_ops_event('SLOW_RESPONSE', '/', 'safra_get_start_catalog', 2500, '{}') $$,
  'D-95: a corporate user logs a slow response');
select is((select count(*)::int from public.ops_events where actor_user_id = 'c0900000-0000-4000-8000-00000000000a'), 1,
  'the event is stored with the user id only');

select throws_ok($$ select public.safra_log_ops_event('WHATEVER', '/', null, null, '{}') $$,
  '22023', 'SAFRA_OPS_EVENT_INVALID_KIND', 'unknown event kinds are refused');

select public.safra_log_ops_event('CLIENT_ERROR', '/', 'TypeError',
  null, '{"message":"token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 leaked"}');
select is((select detail from public.ops_events where code = 'TypeError'), '{"redacted": true}'::jsonb,
  'D-95: anything that looks like a token or key is never stored');

select public.safra_log_ops_event('ACTION_FAILED', '/x', 'HTTP_500', null, '{}') from generate_series(1, 40);
select ok((select count(*) from public.ops_events where actor_user_id = 'c0900000-0000-4000-8000-00000000000a') <= 30,
  'volume limit: at most 30 events per person per minute');

-- Non-corporate session can record a refused login.
select pg_temp.act_as('0c');
select lives_ok($$ select public.safra_log_ops_event('LOGIN_DENIED', '/auth', 'NOT_CORPORATE', null, '{}') $$,
  'a refused (non-corporate) session can record LOGIN_DENIED');

-- 2. Retention ---------------------------------------------------------------------------
alter table public.ops_events disable trigger trg_00_ops_events_server_clock;
insert into public.ops_events(kind, occurred_at, code) values ('CLIENT_ERROR', now() - interval '91 days', 'OLD_EVENT');
alter table public.ops_events enable trigger trg_00_ops_events_server_clock;
select pg_temp.act_as('0a');
select public.safra_log_ops_event('CLIENT_ERROR', '/', 'NEW_EVENT', null, '{}');
select is((select count(*)::int from public.ops_events where code = 'OLD_EVENT'), 0,
  'D-95: events older than 90 days are purged');

-- 3. Reading ------------------------------------------------------------------------------
select throws_ok($$ select public.safra_admin_get_ops_summary(24) $$, '42501', 'SAFRA_OPS_FORBIDDEN',
  'a regular user cannot read the technical log');

select pg_temp.act_as('0b');
select ok((public.safra_admin_get_ops_summary(24)->'events_by_kind'->>'SLOW_RESPONSE')::int >= 1,
  'a platform admin reads the summary');
select ok(jsonb_typeof(public.safra_admin_get_ops_summary(24)->'protocols') = 'object',
  'the summary includes protocol health');

-- 4. Surface -------------------------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.ops_events', 'SELECT')
          and not has_table_privilege('anon', 'public.ops_events', 'INSERT'),
  'the technical log table is not directly readable or writable');
select ok(not has_function_privilege('anon', 'public.safra_log_ops_event(text,text,text,integer,jsonb)', 'EXECUTE')
          and not has_function_privilege('anon', 'public.safra_admin_get_ops_summary(integer)', 'EXECUTE'),
  'anon cannot log or read');
select ok((select relrowsecurity from pg_class where oid = 'public.ops_events'::regclass), 'RLS enabled on ops_events');

select is(
  (select count(*)::int from public.governance_issues
   where issue_key in ('GI-SAFRA-013','GI-SAFRA-014','GI-SAFRA-015')
     and status = 'OPEN' and description like 'OPEN — DEFERRED_TO_ACCESS_RELEASE%'),
  3, 'GI-SAFRA-013..015 (Lovable answers) are OPEN until the owner decides');

select * from finish();
rollback;
