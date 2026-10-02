begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

select ok((select relrowsecurity from pg_class where oid = 'public.treatment_analytics_exclusions'::regclass),
  'D-115: the exclusion list has RLS on');
select ok(not has_table_privilege('authenticated', 'public.treatment_analytics_exclusions', 'SELECT')
          and not has_table_privilege('anon', 'public.treatment_analytics_exclusions', 'SELECT'),
  'D-115: nobody reads or writes the list directly');

-- A protocol to exclude.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('a0060000-0000-4000-8000-00000000000a','d115.requester@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
values ('a0060000-0000-4000-8000-00000000000a','a0060000-0000-4000-8000-00000000000a','{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}','azure',clock_timestamp(),clock_timestamp());
insert into auth.sessions(id,user_id,created_at,updated_at)
values ('a0060000-0000-4000-8000-00000000010a','a0060000-0000-4000-8000-00000000000a',clock_timestamp(),clock_timestamp());
select set_config('request.jwt.claims', json_build_object(
  'sub', 'a0060000-0000-4000-8000-00000000000a', 'email', 'd115.requester@editoradobrasil.com.br',
  'session_id', 'a0060000-0000-4000-8000-00000000010a', 'is_anonymous', false,
  'app_metadata', json_build_object('provider','azure'),
  'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true);
create temp table ctx as
select (public.safra_start_treatment((select id from public.scenarios where code = 'SAFRA-03'),
          'a0060000-0000-4000-8000-000000000901'::uuid, 'D-115: protocolo de demonstração', '{}'::uuid[]))->>'treatment_id' as id;

insert into public.treatment_analytics_exclusions(treatment_id, reason, excluded_by)
values ((select id::uuid from ctx), 'Demonstração do Painel', 'a0060000-0000-4000-8000-00000000000a');
select is((select count(*)::int from public.treatment_analytics_exclusions where treatment_id = (select id::uuid from ctx)), 1,
  'D-115: a protocol can be left out of analytics');
select is((select status from public.treatments where id = (select id::uuid from ctx)), 'ACTIVE',
  'D-115: the protocol itself is not changed');
select throws_ok(
  $$ insert into public.treatment_analytics_exclusions(treatment_id, reason) values ((select id::uuid from ctx), 'curto') $$,
  '23514', null, 'D-115: the exclusion needs a reason');

select * from finish();
rollback;
