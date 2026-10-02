begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

-- R1, R2 = requesters; O = owner of SAFRA-09 (Renato); G = Jair (governance); M = Amanda (admin).
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('a0030000-0000-4000-8000-00000000000a','m03.requester1@editoradobrasil.com.br','{"provider":"azure"}','{"full_name":"Pessoa Um"}',true,false,clock_timestamp(),clock_timestamp()),
  ('a0030000-0000-4000-8000-00000000000b','m03.requester2@editoradobrasil.com.br','{"provider":"azure"}','{}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values
  ('a0030000-0000-4000-8000-00000000000d', 'Renato de Paulo'),
  ('a0030000-0000-4000-8000-00000000000e', 'Jair Silva'),
  ('a0030000-0000-4000-8000-00000000000f', 'Amanda Bueno')
) as v(id, who)
join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0030000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0030000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0030000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0030000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0030000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

create temp table ctx(k text primary key, v text);
create function pg_temp.t(p_k text) returns uuid language sql as $$ select v::uuid from ctx where k = p_k $$;
create function pg_temp.card(p_code text) returns uuid language sql as $$ select id from public.scenarios where code = p_code $$;
create function pg_temp.open(p_k text, p_card text, p_key text) returns void language sql as $$
  insert into ctx
  select p_k, r->>'treatment_id'
  from (select public.safra_start_treatment(pg_temp.card(p_card), p_key::uuid,
          'M03: protocolo de teste da lista geral', '{}'::uuid[]) r) x;
$$;
create function pg_temp.has(p_list jsonb, p_k text) returns boolean language sql as $$
  select exists (select 1 from jsonb_array_elements(p_list->'items') x where x->>'treatment_id' = pg_temp.t(p_k)::text);
$$;

select pg_temp.act_as('0a');
select pg_temp.open('a1', 'SAFRA-09', 'a0030000-0000-4000-8000-000000000901');
select pg_temp.act_as('0b');
select pg_temp.open('b1', 'SAFRA-07', 'a0030000-0000-4000-8000-000000000902');
select public.safra_cancel_treatment(pg_temp.t('b1'), 'M03: cancelado para o filtro');

-- Governance and admins see everyone's protocols (D-104).
select pg_temp.act_as('0e');
select ok(pg_temp.has(public.safra_get_all_treatments(), 'a1') and pg_temp.has(public.safra_get_all_treatments(), 'b1'),
  'D-104: governance (Jair) sees protocols of every person and card');
select ok((public.safra_get_all_treatments()->>'total')::int >= 2, 'the list says how many protocols exist');

select ok(pg_temp.has(public.safra_get_all_treatments('ACTIVE'), 'a1') and not pg_temp.has(public.safra_get_all_treatments('ACTIVE'), 'b1'),
  'M03: filter by situation (in progress)');
select ok(pg_temp.has(public.safra_get_all_treatments('CANCELLED'), 'b1') and not pg_temp.has(public.safra_get_all_treatments('CANCELLED'), 'a1'),
  'M03: filter by situation (cancelled)');
select ok(pg_temp.has(public.safra_get_all_treatments(null, pg_temp.card('SAFRA-07')), 'b1')
          and not pg_temp.has(public.safra_get_all_treatments(null, pg_temp.card('SAFRA-07')), 'a1'),
  'M03: filter by card');

select is(
  (select x->>'requester_name' from jsonb_array_elements(public.safra_get_all_treatments()->'items') x
   where x->>'treatment_id' = pg_temp.t('a1')::text),
  'Pessoa Um', 'D-105: the list shows who opened by name');

select ok(
  (select not (x->>'can_close_my_part')::boolean and not (x->>'can_cancel')::boolean
   from jsonb_array_elements(public.safra_get_all_treatments()->'items') x
   where x->>'treatment_id' = pg_temp.t('a1')::text),
  'M03: the general list is read-only for governance');

select throws_ok($$ select public.safra_get_all_treatments('OPEN') $$,
  '22023', 'SAFRA_INVALID_FILTER', 'an unknown situation filter is refused');

-- D-120: the "now" strip for governance and admins.
select is((public.safra_get_all_treatments()->'summary'->>'active')::int, 1, 'D-120: protocols in progress right now');
select is((public.safra_get_all_treatments()->'summary'->>'nobody_closed')::int, 1, 'D-120: in progress with no part closed');
select is(public.safra_get_all_treatments()->'summary'->>'oldest_protocol_number',
  (select protocol_number from public.treatments where id = pg_temp.t('a1')), 'D-120: the oldest protocol in progress');
select is((public.safra_get_all_treatments('CANCELLED')->'summary'->>'active')::int, 1,
  'D-120: the strip always shows every card, whatever the filter');

select pg_temp.act_as('0f');
select ok(pg_temp.has(public.safra_get_all_treatments(), 'a1'), 'D-104: a platform admin sees the general list');

-- Owners and regular people do not.
select pg_temp.act_as('0d');
select throws_ok($$ select public.safra_get_all_treatments() $$,
  '42501', 'SAFRA_READ_FORBIDDEN', 'a card owner does not see the general list');

select ok(not has_function_privilege('anon', 'public.safra_get_all_treatments(text, uuid, integer)', 'EXECUTE'),
  'anon cannot read the general list');

select * from finish();
rollback;
