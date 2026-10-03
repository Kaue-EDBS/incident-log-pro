begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- K = Kaue (platform admin), J = Jair (governance), X = a regular person.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values ('a0500000-0000-4000-8000-00000000000c', 'Kaue Pastrello'),
             ('a0500000-0000-4000-8000-00000000000d', 'Jair Silva')) as v(id, who)
join private.safra_principals p on p.display_name = v.who;
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('a0500000-0000-4000-8000-00000000000b','d140.regular@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0500000-%';
insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0500000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0500000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0500000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0500000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

select ok((select count(*) from auth.users where id::text like 'a0500000-%') = 3, 'setup: the three people exist');
select ok(not has_function_privilege('anon', 'public.safra_get_weekly_governance(date)', 'execute')
          and not has_function_privilege('anon', 'public.safra_register_governance_action(date,uuid,text,text)', 'execute')
          and has_function_privilege('authenticated', 'public.safra_get_weekly_governance(date)', 'execute'),
  'D-140: governance RPCs are closed to anon and open to logged-in people (the database checks the role)');

-- F05: only governance, executive and platform admins ------------------------------------
select pg_temp.act_as('0b');
select throws_ok('select public.safra_get_weekly_governance(null)', '42501', 'SAFRA_GOVERNANCE_FORBIDDEN',
  'F05: a regular person does not see the weekly governance');
select throws_ok($$ select public.safra_register_governance_action(null, null, 'TRAINING', 'Treinar a equipe da expedição.') $$,
  '42501', 'SAFRA_GOVERNANCE_FORBIDDEN', 'F05: a regular person does not register actions');

select pg_temp.act_as('0d');
select throws_ok($$ select public.safra_register_governance_action(null, null, 'OUTRA', 'Ação com tipo inválido.') $$,
  '22023', 'SAFRA_GOVERNANCE_INVALID_TYPE', 'F05: only the listed action types');
select throws_ok($$ select public.safra_register_governance_action(null, null, 'TRAINING', 'curto') $$,
  '22023', 'SAFRA_GOVERNANCE_DESCRIPTION_REQUIRED', 'F05: the action needs a description');
select lives_ok($$ select public.safra_register_governance_action('2026-10-08', (select id from public.scenarios where code = 'SAFRA-06'),
  'SYSTEM_CHANGE', 'Pedir ao TI janela de manutenção do ERP fora do pico.') $$,
  'F05: Jair registers an action for a card');
select is((select week_start from public.governance_actions where description like 'Pedir ao TI janela%'), '2026-10-05'::date,
  'F05: the action is filed under the Monday of its week');

select pg_temp.act_as('0c');
select ok((select jsonb_array_length(public.safra_get_weekly_governance('2026-10-07')->'actions') = 1
           and (public.safra_get_weekly_governance('2026-10-07')->>'week_start')::date = '2026-10-05'),
  'F05: Kaue (admin) sees the week summary with the registered action');

select throws_ok($$ update public.governance_actions set description = 'Texto trocado depois.' $$,
  'P0001', 'governance actions are append-only', 'F05: registered actions are never changed');

-- F04: counts and times in the indicators -----------------------------------------------
select ok((select v ? 'consolidated' and v ? 'cards' and v ? 'areas'
                  and (v->'consolidated') ?& array['opened','resolved','cancelled','active','median_secs','p90_secs','peak_simultaneous']
           from (select public.safra_get_reliability_metrics(null)->'volume' as v) x),
  'F04: the indicators bring counts, times, peak and impacted areas');
select ok((select jsonb_array_length(public.safra_get_reliability_metrics(null)->'volume'->'cards') = (select count(*)::int from public.scenarios)),
  'F04: one line per card for governance and admins');

select * from finish();
rollback;
