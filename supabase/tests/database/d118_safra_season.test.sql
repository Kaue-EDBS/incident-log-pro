begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

-- K = Kaue (season manager), A = Amanda (platform admin, not manager), R = requester.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('a0080000-0000-4000-8000-00000000000c','d118.requester@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values
  ('a0080000-0000-4000-8000-00000000000a', 'Kaue Pastrello'),
  ('a0080000-0000-4000-8000-00000000000b', 'Amanda Bueno')
) as v(id, who)
join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0080000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0080000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0080000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0080000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0080000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

create temp table ctx(k text primary key, v text);
create function pg_temp.open(p_k text, p_card text, p_key text) returns void language sql as $$
  insert into ctx
  select p_k, r->>'treatment_id'
  from (select public.safra_start_treatment((select id from public.scenarios where code = p_card), p_key::uuid,
          'D-118: protocolo de teste da Safra', '{}'::uuid[]) r) x;
$$;

-- 1. The current Safra (D-69) ------------------------------------------------------
select pg_temp.act_as('0c');
select is((public.safra_get_season()->>'open')::boolean, true, 'D-69: the current Safra is open');
select is((public.safra_get_season()->>'started_at')::timestamptz, timestamptz '2026-10-01 00:00:00-03',
  'D-69: it started on 01/10/2026 00:00 (São Paulo)');
select is((public.safra_get_season()->>'can_manage')::boolean, false, 'a regular person does not manage the Safra');
select pg_temp.open('before', 'SAFRA-09', 'a0080000-0000-4000-8000-000000000901');

-- 2. Only Kaue ends it, with the confirmation (D-59, D-70) -----------------------------
select pg_temp.act_as('0b');
select is((public.safra_get_season()->>'can_manage')::boolean, false, 'D-59: another platform admin does not manage the Safra');
select throws_ok($$ select public.safra_end_season('ENCERRAR SAFRA') $$,
  '42501', 'SAFRA_SEASON_FORBIDDEN', 'D-59: only Kaue ends the Safra');

select pg_temp.act_as('0a');
select is((public.safra_get_season()->>'can_manage')::boolean, true, 'D-59: Kaue manages the Safra');
select throws_ok($$ select public.safra_end_season('encerrar') $$,
  '22023', 'SAFRA_SEASON_CONFIRM_REQUIRED', 'D-70: ending needs "ENCERRAR SAFRA" typed');
select is((public.safra_end_season('ENCERRAR SAFRA')->>'open')::boolean, false, 'D-70: the Safra ends with the confirmation');
select ok((public.safra_get_season()->>'undo_until') is not null, 'D-70: the end can be undone for 7 days');

-- 3. Closed Safra: no new protocol; open ones continue (D-118) -------------------------
select pg_temp.act_as('0c');
select throws_ok($$ select pg_temp.open('after', 'SAFRA-07', 'a0080000-0000-4000-8000-000000000902') $$,
  'P0001', 'SAFRA_SEASON_CLOSED', 'D-118: no new protocol while the Safra is closed');
select is((public.safra_close_my_part((select v::uuid from ctx where k = 'before')))->>'situation', 'AGUARDANDO_DONO',
  'D-118: a protocol opened before the end can still be concluded');

-- 4. Undo within 7 days (D-70) -------------------------------------------------------
select pg_temp.act_as('0a');
select is((public.safra_undo_end_season()->>'open')::boolean, true, 'D-70: undoing reopens the same Safra');
select is((select count(*)::int from public.safra_seasons), 1, 'D-70: undo does not create a new Safra nor delete data');
select pg_temp.act_as('0c');
select lives_ok($$ select pg_temp.open('after_undo', 'SAFRA-07', 'a0080000-0000-4000-8000-000000000903') $$,
  'after the undo, protocols open again');

-- After 7 days the end can no longer be undone.
select pg_temp.act_as('0a');
select public.safra_end_season('ENCERRAR SAFRA');
update public.safra_seasons set started_at = now() - interval '30 days', ended_at = now() - interval '8 days'
 where ended_at is not null;
select throws_ok($$ select public.safra_undo_end_season() $$,
  'P0001', 'SAFRA_SEASON_UNDO_EXPIRED', 'D-70: after 7 days the end is final');

-- 5. Kaue starts the next Safra (D-119) ------------------------------------------------
select is((public.safra_start_season()->>'open')::boolean, true, 'D-119: Kaue starts the next Safra');
select throws_ok($$ select public.safra_start_season() $$,
  'P0001', 'SAFRA_SEASON_ALREADY_OPEN', 'only one Safra is open at a time');
select ok(private.safra_current_season_start() > now() - interval '1 minute',
  'analytics now count from the new Safra');
select is((select string_agg(event_type, ',' order by occurred_at) from public.safra_season_events),
  'STARTED,ENDED,END_UNDONE,ENDED,STARTED', 'every mark is in the Safra history');

-- 6. Surface -----------------------------------------------------------------------
select throws_ok($$ update public.safra_season_events set note = 'x' $$, null, null, 'the Safra history cannot be rewritten');
select ok(not has_table_privilege('authenticated', 'public.safra_seasons', 'SELECT')
          and not has_table_privilege('authenticated', 'public.safra_season_events', 'SELECT'),
  'nobody reads the Safra tables directly');
select ok(not has_function_privilege('anon', 'public.safra_end_season(text)', 'EXECUTE')
          and not has_function_privilege('anon', 'public.safra_get_season()', 'EXECUTE'),
  'anon cannot read or mark the Safra');

select * from finish();
rollback;
