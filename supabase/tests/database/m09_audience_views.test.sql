begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

-- G = Jair (governance), B = Bruno (executive), M = Amanda (platform admin), O = Renato (owner), R = requester.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('a0090000-0000-4000-8000-00000000000c','m09.requester@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values
  ('a0090000-0000-4000-8000-00000000000a', 'Jair Silva'),
  ('a0090000-0000-4000-8000-00000000000b', 'Bruno Palhao'),
  ('a0090000-0000-4000-8000-00000000000e', 'Amanda Bueno'),
  ('a0090000-0000-4000-8000-00000000000d', 'Renato de Paulo')
) as v(id, who)
join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, jsonb_build_object('custom_claims', jsonb_build_object('tid', '45ba725f-d260-45c3-ac85-11f433471277'), 'full_name', u.raw_user_meta_data->>'full_name'), 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0090000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0090000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0090000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0090000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0090000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

select pg_temp.act_as('0c');
select public.safra_start_treatment((select id from public.scenarios where code = 'SAFRA-09'),
  'a0090000-0000-4000-8000-000000000901'::uuid, 'M09: protocolo de teste das visões', '{}'::uuid[]);

-- 1. Cards e donos (D-121) --------------------------------------------------------------
select pg_temp.act_as('0a');
select is(jsonb_array_length(public.safra_get_cards_overview()), (select count(*)::int from public.scenarios),
  'D-121: governance sees every card');
select ok((select c->>'owner_name' = 'Renato de Paulo' and (c->>'active_now')::int = 1 and (c->>'season_protocols')::int = 1
           and c->>'responsible_area' is not null
           from jsonb_array_elements(public.safra_get_cards_overview()) c where c->>'code' = 'SAFRA-09'),
  'D-121: each card shows its owner, area and protocols');
select pg_temp.act_as('0b');
select ok(jsonb_array_length(public.safra_get_cards_overview()) > 0, 'D-121: Bruno sees the cards too (same as Jair)');
select pg_temp.act_as('0d');
select throws_ok($$ select public.safra_get_cards_overview() $$, '42501', 'SAFRA_READ_FORBIDDEN',
  'D-121: a card owner does not see the overview');

-- 2. Painel de cadastrados (D-123) -------------------------------------------------------
select pg_temp.act_as('0e');
select ok((select p->'roles' ? 'scenario_owner' and (p->>'has_logged_in')::boolean and p->'cards' ? 'SAFRA-09'
           from jsonb_array_elements(public.safra_admin_get_people()->'people') p where p->>'name' = 'Renato de Paulo'),
  'D-123: the people panel shows roles, cards and who already logged in');
select ok((public.safra_admin_get_people()->>'logins_without_registration')::int >= 1,
  'D-123: logins of regular people (not registered) are counted, not listed');
select lives_ok($$ select * from public.get_safra_rbac_audit_events(50) $$, 'D-123: platform admins read the role trail');
select pg_temp.act_as('0a');
select throws_ok($$ select public.safra_admin_get_people() $$, '42501', 'SAFRA_ADMIN_FORBIDDEN',
  'D-123: governance does not see the people panel (platform admins only)');

-- 3. Uso das telas, anônimo (D-124) ------------------------------------------------------
select pg_temp.act_as('0c');
select public.safra_log_screen_view('/');
select public.safra_log_screen_view('/');
select public.safra_log_screen_view('/meus-protocolos');
select public.safra_log_screen_view('/rota-inventada');
select is((select views from public.screen_views_daily where route = '/' and day = (now() at time zone 'America/Sao_Paulo')::date), 2,
  'D-124: each opening of a screen is counted');
select is((select count(*)::int from public.screen_views_daily where route not in ('/', '/meus-protocolos')), 0,
  'D-124: unknown screens are ignored');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name = 'screen_views_daily'
             and column_name ~* '(user|actor|email|session|ip)'), 0,
  'D-124/D-90: the counter stores no person');
select pg_temp.act_as('0e');
select ok((select (r->>'views')::int = 2 from jsonb_array_elements(public.safra_admin_get_screen_usage(7)->'routes') r where r->>'route' = '/'),
  'D-124: platform admins read the usage');
select pg_temp.act_as('0a');
select throws_ok($$ select public.safra_admin_get_screen_usage(7) $$, '42501', 'SAFRA_ADMIN_FORBIDDEN',
  'D-124: only platform admins read the usage');

-- 4. Surface -----------------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.screen_views_daily', 'SELECT'),
  'nobody reads the counter table directly');
select ok(not has_function_privilege('anon', 'public.safra_log_screen_view(text)', 'EXECUTE')
          and not has_function_privilege('anon', 'public.safra_get_cards_overview()', 'EXECUTE')
          and not has_function_privilege('anon', 'public.safra_admin_get_people()', 'EXECUTE'),
  'anon reaches none of the M09 reads');

select * from finish();
rollback;
