begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

-- R = requester (name from Microsoft), O = owner of SAFRA-09 (Renato), T = third party,
-- G = Jair (governance), M = Amanda (platform admin).
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('a0020000-0000-4000-8000-00000000000a','m02.requester@editoradobrasil.com.br','{"provider":"azure"}','{"full_name":"Maria Solicitante"}',true,false,clock_timestamp(),clock_timestamp()),
  ('a0020000-0000-4000-8000-00000000000c','m02.third@editoradobrasil.com.br','{"provider":"azure"}','{}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values
  ('a0020000-0000-4000-8000-00000000000d', 'Renato de Paulo'),
  ('a0020000-0000-4000-8000-00000000000e', 'Jair Silva'),
  ('a0020000-0000-4000-8000-00000000000f', 'Amanda Bueno')
) as v(id, who)
join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0020000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0020000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0020000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0020000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0020000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

create temp table ctx(k text primary key, v text);
create function pg_temp.t(p_k text) returns uuid language sql as $$ select v::uuid from ctx where k = p_k $$;
create function pg_temp.open(p_k text, p_card text, p_key text) returns void language sql as $$
  insert into ctx
  select p_k, r->>'treatment_id'
  from (select public.safra_start_treatment((select id from public.scenarios where code = p_card), p_key::uuid,
          'M02: protocolo de teste do histórico', '{}'::uuid[]) r) x;
$$;
create function pg_temp.age(p_k text, p_open interval) returns void language plpgsql as $$
begin
  execute 'alter table public.treatments disable trigger user';
  update public.treatments
     set opened_at = opened_at - p_open, problem_started_at = problem_started_at - p_open,
         created_at = created_at - p_open
   where id = pg_temp.t(p_k);
  execute 'alter table public.treatments enable trigger user';
end;
$$;
create function pg_temp.types(p_k text) returns text[] language sql as $$
  select array_agg(e->>'event_type' order by ord)
  from jsonb_array_elements(public.safra_get_treatment_timeline(pg_temp.t(p_k))->'events') with ordinality x(e, ord);
$$;

-- 1. Full life: open, close, undo, close, owner closes ------------------------------
select pg_temp.act_as('0a');
select pg_temp.open('t1', 'SAFRA-09', 'a0020000-0000-4000-8000-000000000901');
select public.safra_close_my_part(pg_temp.t('t1'));
select public.safra_undo_my_part(pg_temp.t('t1'));
select public.safra_close_my_part(pg_temp.t('t1'));
select pg_temp.act_as('0d');
select public.safra_close_my_part(pg_temp.t('t1'));

-- D-108: the history is read by governance (Jair) from here on.
select pg_temp.act_as('0e');
select is(pg_temp.types('t1'),
  array['TREATMENT_OPENED','REQUESTER_PART_CLOSED','REQUESTER_PART_UNDONE','REQUESTER_PART_CLOSED','OWNER_PART_CLOSED','TREATMENT_RESOLVED'],
  'M02: every relevant step is in the history, in order');

select is(
  (select array_agg(e->>'actor_role' order by ord)
   from jsonb_array_elements(public.safra_get_treatment_timeline(pg_temp.t('t1'))->'events') with ordinality x(e, ord)),
  array['REQUESTER','REQUESTER','REQUESTER','REQUESTER','OWNER','OWNER'],
  'D-105: each step says who did it (requester or owner)');

select is(public.safra_get_treatment_timeline(pg_temp.t('t1'))->'events'->0->>'actor_name', 'Maria Solicitante',
  'D-105: the requester appears by the Microsoft name');
select is(public.safra_get_treatment_timeline(pg_temp.t('t1'))->'events'->4->>'actor_name', 'Renato de Paulo',
  'D-105: the owner appears by the registered name');
select is(public.safra_get_treatment_timeline(pg_temp.t('t1'))->>'opened_by_name', 'Maria Solicitante',
  'M03: the history says who opened');
select ok((public.safra_get_treatment_timeline(pg_temp.t('t1'))->>'scenario_version_no') is not null,
  'M03: the history says which card version was used');
select is(public.safra_get_treatment_timeline(pg_temp.t('t1'))->'treatment'->>'situation', 'ENCERRADO',
  'M03: the history carries the current situation');

select is(public.safra_get_treatment_timeline(pg_temp.t('t1'))->'events',
          public.safra_get_treatment_timeline(pg_temp.t('t1'))->'events',
  'M02: the history is the same on every read (refresh or another device)');

-- 2. Who can see (D-108, revises D-104) --------------------------------------------
select pg_temp.act_as('0a');
select throws_ok($$ select public.safra_get_treatment_timeline(pg_temp.t('t1')) $$,
  '42501', 'SAFRA_TIMELINE_FORBIDDEN', 'D-108: the requester no longer sees the history');
select pg_temp.act_as('0d');
select throws_ok($$ select public.safra_get_treatment_timeline(pg_temp.t('t1')) $$,
  '42501', 'SAFRA_TIMELINE_FORBIDDEN', 'D-108: the card owner no longer sees the history');
select pg_temp.act_as('0e');
select ok(jsonb_array_length(public.safra_get_treatment_timeline(pg_temp.t('t1'))->'events') = 6, 'D-104: governance (Jair) sees the history');
select pg_temp.act_as('0f');
select ok(jsonb_array_length(public.safra_get_treatment_timeline(pg_temp.t('t1'))->'events') = 6, 'D-104: a platform admin sees the history');
select pg_temp.act_as('0c');
select throws_ok($$ select public.safra_get_treatment_timeline(pg_temp.t('t1')) $$,
  '42501', 'SAFRA_TIMELINE_FORBIDDEN', 'D-104: a third party cannot see the history');
select ok(not has_function_privilege('anon', 'public.safra_get_treatment_timeline(uuid)', 'EXECUTE'),
  'anon cannot read any history');

-- 3. Automatic cancel shows as "Sistema" -------------------------------------------
select pg_temp.act_as('0a');
select pg_temp.open('t2', 'SAFRA-07', 'a0020000-0000-4000-8000-000000000902');
select pg_temp.age('t2', interval '73 hours');

-- D-102: no area can be added after the opening transaction.
select throws_ok(
  $$ insert into public.treatment_impacted_areas(treatment_id, operational_area_id, added_by)
     values (pg_temp.t('t2'), (select id from public.operational_areas limit 1), 'a0020000-0000-4000-8000-00000000000a') $$,
  'P0001', 'impacted areas are fixed after opening (D-102)', 'D-102: impacted areas do not change after opening');

select private.safra_auto_cancel_stale();
select pg_temp.act_as('0e');
select is(
  (select e->>'actor_name' || '/' || (e->>'actor_role')
   from jsonb_array_elements(public.safra_get_treatment_timeline(pg_temp.t('t2'))->'events') e
   where e->>'event_type' = 'TREATMENT_CANCELLED'),
  'Sistema/SYSTEM', 'D-105: the automatic cancel appears as Sistema');

-- 4. Only real events, append-only (M02) -------------------------------------------
select throws_ok(
  $$ insert into public.treatment_events(treatment_id, event_type, correlation_id) values (pg_temp.t('t1'), 'NOTE_ADDED', gen_random_uuid()) $$,
  '23514', null, 'D-103: there are no notes');
select throws_ok(
  $$ insert into public.treatment_events(treatment_id, event_type, correlation_id) values (pg_temp.t('t1'), 'ESCALATION_CHANGED', gen_random_uuid()) $$,
  '23514', null, 'M02: only events that exist in the product can be recorded');
select throws_ok(
  $$ update public.treatment_events set event_type = 'TREATMENT_CANCELLED' where treatment_id = pg_temp.t('t1') $$,
  null, null, 'M02: history events cannot be rewritten');
select throws_ok(
  $$ delete from public.treatment_events where treatment_id = pg_temp.t('t1') $$,
  null, null, 'M02: history events cannot be deleted');

select is((select status from public.governance_issues where issue_key = 'GI-SAFRA-016'), 'OPEN',
  'GI-SAFRA-016 (notice before the 72 h cancel) is OPEN until M05');

select * from finish();
rollback;
