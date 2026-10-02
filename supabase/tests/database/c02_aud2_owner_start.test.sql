begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

-- An Auth user with the owner's corporate e-mail is bound to the owner principal by the C04 trigger.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('02a20000-0000-4000-8000-000000000001','daniel.garcia@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());

-- AUD-GERAL A-01: Microsoft identity of the corporate tenant for synthetic azure users.
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text,u.id,jsonb_build_object('sub',u.id::text,'email',u.email,'custom_claims',jsonb_build_object('tid','45ba725f-d260-45c3-ac85-11f433471277')),'azure',clock_timestamp(),clock_timestamp()
from auth.users u
where u.raw_app_meta_data->>'provider'='azure'
  and not exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='azure');

insert into auth.sessions(id,user_id,created_at,updated_at)
values ('02a20000-0000-4000-8000-000000000011','02a20000-0000-4000-8000-000000000001',clock_timestamp(),clock_timestamp());

select is(
  (select p.user_id from private.safra_principals p where p.corporate_email = 'daniel.garcia@editoradobrasil.com.br'),
  '02a20000-0000-4000-8000-000000000001'::uuid,
  'fixture: owner principal is bound to the synthetic Auth user'
);

select set_config('request.jwt.claims', json_build_object(
  'sub','02a20000-0000-4000-8000-000000000001','email','daniel.garcia@editoradobrasil.com.br',
  'session_id','02a20000-0000-4000-8000-000000000011','is_anonymous',false,
  'app_metadata',json_build_object('provider','azure'),
  'exp',extract(epoch from now()+interval '1 hour')::bigint)::text, true);

select throws_ok(
  $$ select public.safra_start_treatment(
       (select id from public.scenarios where code='SAFRA-01'),
       '02a20000-0000-4000-8000-000000000101'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[]) $$,
  'P0001',
  'SAFRA_START_OWNER_OWN_CARD',
  'D-65: the owner cannot open a protocol of their own card'
);

select is(
  (select count(*)::bigint from public.treatments
   where start_idempotency_key = '02a20000-0000-4000-8000-000000000101'),
  0::bigint,
  'D-65: rejected START creates no treatment'
);

select is(
  public.safra_start_treatment(
    (select id from public.scenarios where code='SAFRA-04'),
    '02a20000-0000-4000-8000-000000000102'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[])->>'status',
  'ACTIVE',
  'D-65: the same owner may open a card owned by someone else'
);

select ok(
  exists(select 1 from public.governance_issues
         where issue_key = 'GI-SAFRA-011' and status = 'OPEN' and resolved_at is null),
  'GI-SAFRA-011 (Teams) is mirrored as OPEN (D-53)'
);

select * from finish();
rollback;
