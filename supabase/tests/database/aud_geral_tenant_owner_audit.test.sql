begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

-- Users: A = corporate tenant requester; F = foreign tenant using a corporate-looking e-mail.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('a9e00000-0000-4000-8000-00000000000a','aud.geral.requester@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp()),
  ('a9e00000-0000-4000-8000-00000000000f','aud.geral.foreign@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
values
  ('a9e00000-0000-4000-8000-00000000000a','a9e00000-0000-4000-8000-00000000000a',
   '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}','azure',clock_timestamp(),clock_timestamp()),
  ('a9e00000-0000-4000-8000-00000000000f','a9e00000-0000-4000-8000-00000000000f',
   '{"custom_claims":{"tid":"00000000-0000-4000-8000-0000000000ff"}}','azure',clock_timestamp(),clock_timestamp());

insert into auth.sessions(id,user_id,created_at,updated_at)
values
  ('a9e00000-0000-4000-8000-0000000000a1','a9e00000-0000-4000-8000-00000000000a',clock_timestamp(),clock_timestamp()),
  ('a9e00000-0000-4000-8000-0000000000f1','a9e00000-0000-4000-8000-00000000000f',clock_timestamp(),clock_timestamp());

-- 1. A-01: foreign tenant is rejected even with a corporate e-mail.
select set_config('request.jwt.claims', json_build_object(
  'sub','a9e00000-0000-4000-8000-00000000000f','email','aud.geral.foreign@editoradobrasil.com.br',
  'session_id','a9e00000-0000-4000-8000-0000000000f1','is_anonymous',false,
  'app_metadata',json_build_object('provider','azure'),
  'exp',extract(epoch from now()+interval '1 hour')::bigint)::text, true);

select ok(not public.safra_is_corporate_user(), 'A-01: foreign Microsoft tenant is not a corporate user');

select throws_ok(
  $$ select public.safra_start_treatment((select id from public.scenarios where code='SAFRA-01'),
       'a9e00000-0000-4000-8000-0000000000b1'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[]) $$,
  '42501', 'SAFRA_START_FORBIDDEN',
  'A-01: foreign tenant cannot START'
);

select throws_ok(
  $$ select public.safra_get_start_catalog() $$,
  '42501', 'SAFRA_START_FORBIDDEN',
  'A-01: foreign tenant cannot read the catalog'
);

select set_config('request.jwt.claims', json_build_object(
  'sub','a9e00000-0000-4000-8000-00000000000a','email','aud.geral.requester@editoradobrasil.com.br',
  'session_id','a9e00000-0000-4000-8000-0000000000a1','is_anonymous',false,
  'app_metadata',json_build_object('provider','azure'),
  'exp',extract(epoch from now()+interval '1 hour')::bigint)::text, true);

select ok(public.safra_is_corporate_user(), 'A-01: corporate tenant user is accepted');

select ok(
  has_function_privilege('authenticated','private.safra_session_in_corporate_tenant()','EXECUTE')
  and not has_function_privilege('authenticated','private.safra_user_in_corporate_tenant(uuid)','EXECUTE')
  and not has_function_privilege('anon','private.safra_session_in_corporate_tenant()','EXECUTE'),
  'A-01: only the own-session tenant check is callable; the per-user lookup is not'
);

-- 2. A-01: binding needs the corporate tenant; it happens when the identity arrives.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select 'a9e00000-0000-4000-8000-0000000000b0', corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from private.safra_principals where display_name = 'Bruno Palhao';
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
values ('a9e00000-0000-4000-8000-0000000000b0','a9e00000-0000-4000-8000-0000000000b0',
        '{"custom_claims":{"tid":"00000000-0000-4000-8000-0000000000ff"}}','azure',clock_timestamp(),clock_timestamp());

select ok(
  (select user_id is null from private.safra_principals where display_name = 'Bruno Palhao'),
  'A-01: a foreign-tenant login never claims a corporate principal'
);

insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select 'a9e00000-0000-4000-8000-0000000000c0', corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from private.safra_principals where display_name = 'Joao Jurado';

select ok(
  (select user_id is null from private.safra_principals where display_name = 'Joao Jurado'),
  'A-01: without the Microsoft identity the principal is not bound yet'
);

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
values ('a9e00000-0000-4000-8000-0000000000c0','a9e00000-0000-4000-8000-0000000000c0',
        '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}','azure',clock_timestamp(),clock_timestamp());

select is(
  (select user_id from private.safra_principals where display_name = 'Joao Jurado'),
  'a9e00000-0000-4000-8000-0000000000c0'::uuid,
  'A-01: the corporate-tenant identity binds the principal when it arrives'
);

-- 3. A-05: principal changes are audited.
select ok(
  exists(select 1 from private.safra_rbac_audit_events e
         join private.safra_principals p on p.id = e.target_principal_id
         where p.display_name = 'Joao Jurado' and e.action = 'PRINCIPAL_BOUND'),
  'A-05: binding a login to a principal is audited'
);

update private.safra_principals set is_active = false where display_name = 'Renato de Paulo';

select ok(
  exists(select 1 from private.safra_rbac_audit_events e
         join private.safra_principals p on p.id = e.target_principal_id
         where p.display_name = 'Renato de Paulo' and e.action = 'PRINCIPAL_DEACTIVATED'),
  'A-05: deactivating a principal is audited'
);

-- 4. A-04 / D-78: unavailable owner blocks the card until a new definition.
select ok(
  not exists(select 1 from jsonb_array_elements(public.safra_get_start_catalog()) c where c->>'code' = 'SAFRA-09'),
  'D-78: card of a deactivated owner leaves the catalog'
);

select throws_ok(
  $$ select public.safra_start_treatment((select id from public.scenarios where code='SAFRA-09'),
       'a9e00000-0000-4000-8000-0000000000b2'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[]) $$,
  'P0001', 'SAFRA_SCENARIO_OWNER_UNAVAILABLE',
  'D-78: START of a card with a deactivated owner is blocked'
);

update private.safra_principals set is_active = true where display_name = 'Renato de Paulo';
update private.safra_role_grants rg set revoked_at = clock_timestamp()
from private.safra_principals p
where p.id = rg.principal_id and p.display_name = 'Jiane Rodrigues' and rg.role = 'scenario_owner' and rg.revoked_at is null;

select is(
  (select count(*)::bigint from jsonb_array_elements(public.safra_get_start_catalog()) c
   where c->>'code' in ('SAFRA-04','SAFRA-05','SAFRA-06','SAFRA-08')),
  0::bigint,
  'D-78: cards of an owner without the scenario_owner role leave the catalog'
);

select throws_ok(
  $$ select public.safra_start_treatment((select id from public.scenarios where code='SAFRA-04'),
       'a9e00000-0000-4000-8000-0000000000b3'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[]) $$,
  'P0001', 'SAFRA_SCENARIO_OWNER_UNAVAILABLE',
  'D-78: START of a card whose owner lost the role is blocked'
);

select is(
  (select count(*)::bigint from jsonb_array_elements(public.safra_get_start_catalog())),
  7::bigint,
  'D-78: the other 7 cards stay available'
);

-- 5. A-08: catalog tells the owner which cards are theirs.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select 'a9e00000-0000-4000-8000-0000000000d0', corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from private.safra_principals where display_name = 'Renato de Paulo';
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
values ('a9e00000-0000-4000-8000-0000000000d0','a9e00000-0000-4000-8000-0000000000d0',
        '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}','azure',clock_timestamp(),clock_timestamp());
insert into auth.sessions(id,user_id,created_at,updated_at)
values ('a9e00000-0000-4000-8000-0000000000d1','a9e00000-0000-4000-8000-0000000000d0',clock_timestamp(),clock_timestamp());

select set_config('request.jwt.claims', json_build_object(
  'sub','a9e00000-0000-4000-8000-0000000000d0',
  'email',(select corporate_email from private.safra_principals where display_name = 'Renato de Paulo'),
  'session_id','a9e00000-0000-4000-8000-0000000000d1','is_anonymous',false,
  'app_metadata',json_build_object('provider','azure'),
  'exp',extract(epoch from now()+interval '1 hour')::bigint)::text, true);

select is(
  (select string_agg(c->>'code', ',' order by c->>'code') from jsonb_array_elements(public.safra_get_start_catalog()) c
   where (c->>'is_my_card')::boolean),
  'SAFRA-09',
  'A-08: the owner sees which card is his own'
);

-- 6. A-16: START result carries the server time.
select set_config('request.jwt.claims', json_build_object(
  'sub','a9e00000-0000-4000-8000-00000000000a','email','aud.geral.requester@editoradobrasil.com.br',
  'session_id','a9e00000-0000-4000-8000-0000000000a1','is_anonymous',false,
  'app_metadata',json_build_object('provider','azure'),
  'exp',extract(epoch from now()+interval '1 hour')::bigint)::text, true);

select ok(
  (select (r->>'server_time')::timestamptz >= (r->>'opened_at')::timestamptz
   from (select public.safra_start_treatment((select id from public.scenarios where code='SAFRA-01'),
           'a9e00000-0000-4000-8000-0000000000b4'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[]) r) x),
  'A-16: START result carries the server time'
);

-- 7. A-11 / A-12.
select ok(to_regprocedure('public.safra_log_access_denied(text,text)') is null, 'A-11: unreachable access-denied writer removed');
select ok(to_regclass('public.treatments_scenario_version_idx') is null, 'A-12: redundant index removed');

select ok(
  (select count(*) = 0 from information_schema.columns where table_schema = 'public' and column_name ilike '%tenant%'),
  'tenant is never stored in public tables; it is read from auth.identities'
);

select ok(
  exists(select 1 from public.governance_issues
         where issue_key = 'GI-SAFRA-012' and description like '%D-23%' and description like '%PITR%'
           and ((status = 'OPEN' and resolved_at is null) or (status = 'RESOLVED' and resolution_text like 'D-93%'))),
  'GI-SAFRA-012 (backup x RPO) is OPEN, or RESOLVED only by the owner decision D-93'
);

select * from finish();
rollback;
