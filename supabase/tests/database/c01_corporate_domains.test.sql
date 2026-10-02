begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users(
  id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at
)
values
(
  '01010101-0000-4000-8000-000000000001'::uuid,
  'c01.primary@editoradobrasil.com.br',
  '{"provider":"azure"}'::jsonb,
  true,false,clock_timestamp(),clock_timestamp()
),
(
  '01010101-0000-4000-8000-000000000002'::uuid,
  'c01.alias@editoradobrasil1.onmicrosoft.com',
  '{"provider":"azure"}'::jsonb,
  true,false,clock_timestamp(),clock_timestamp()
),
(
  '01010101-0000-4000-8000-000000000003'::uuid,
  'c01.outsider@example.com',
  '{"provider":"azure"}'::jsonb,
  true,false,clock_timestamp(),clock_timestamp()
);

-- AUD-GERAL A-01: Microsoft identity of the corporate tenant for synthetic azure users.
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text,u.id,jsonb_build_object('sub',u.id::text,'email',u.email,'custom_claims',jsonb_build_object('tid','45ba725f-d260-45c3-ac85-11f433471277')),'azure',clock_timestamp(),clock_timestamp()
from auth.users u
where u.raw_app_meta_data->>'provider'='azure'
  and not exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='azure');

insert into auth.sessions(id,user_id,created_at,updated_at)
values
('01010101-0000-4000-8000-000000000011'::uuid,'01010101-0000-4000-8000-000000000001'::uuid,clock_timestamp(),clock_timestamp()),
('01010101-0000-4000-8000-000000000012'::uuid,'01010101-0000-4000-8000-000000000002'::uuid,clock_timestamp(),clock_timestamp()),
('01010101-0000-4000-8000-000000000013'::uuid,'01010101-0000-4000-8000-000000000003'::uuid,clock_timestamp(),clock_timestamp());

select ok(
  not has_function_privilege('anon','public.safra_is_corporate_user()','EXECUTE'),
  'anon cannot execute corporate authorization predicate'
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','01010101-0000-4000-8000-000000000001',
    'email','c01.primary@editoradobrasil.com.br',
    'session_id','01010101-0000-4000-8000-000000000011',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,true
);

select ok(public.safra_is_corporate_user(), 'primary corporate domain is accepted');

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','01010101-0000-4000-8000-000000000002',
    'email','c01.alias@editoradobrasil1.onmicrosoft.com',
    'session_id','01010101-0000-4000-8000-000000000012',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,true
);

select ok(public.safra_is_corporate_user(), 'onmicrosoft corporate domain is accepted');

select is(
  jsonb_array_length(public.safra_get_start_catalog()),
  11,
  'approved onmicrosoft identity can call governed START catalog'
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','01010101-0000-4000-8000-000000000003',
    'email','c01.outsider@example.com',
    'session_id','01010101-0000-4000-8000-000000000013',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,true
);

select ok(not public.safra_is_corporate_user(), 'external domain is rejected');

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','01010101-0000-4000-8000-000000000001',
    'email','c01.primary@sub.editoradobrasil.com.br',
    'session_id','01010101-0000-4000-8000-000000000011',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,true
);

select ok(not public.safra_is_corporate_user(), 'unapproved subdomain is rejected');

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','01010101-0000-4000-8000-000000000001',
    'email','C01.PRIMARY@EDITORADOBRASIL.COM.BR',
    'session_id','01010101-0000-4000-8000-000000000011',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,true
);

select ok(public.safra_is_corporate_user(), 'domain matching is case-insensitive');

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','01010101-0000-4000-8000-000000000001',
    'email','c01.primary@editoradobrasil.com.br',
    'session_id','01010101-0000-4000-8000-000000000011',
    'is_anonymous',true,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,true
);

select ok(not public.safra_is_corporate_user(), 'anonymous identity remains rejected');

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','01010101-0000-4000-8000-000000000001',
    'email','c01.primary@editoradobrasil.com.br',
    'session_id','01010101-0000-4000-8000-000000000011',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','email'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,true
);

select ok(not public.safra_is_corporate_user(), 'non-Azure provider remains rejected');

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','01010101-0000-4000-8000-000000000001',
    'email','c01.primary@editoradobrasil.com.br',
    'session_id','01010101-0000-4000-8000-000000000099',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,true
);

select ok(not public.safra_is_corporate_user(), 'missing/revoked server-side session remains rejected');

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','01010101-0000-4000-8000-000000000001',
    'email','c01.primary@editoradobrasil.com.br',
    'session_id','01010101-0000-4000-8000-000000000011',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()-interval '1 minute')::bigint
  )::text,true
);

select ok(not public.safra_is_corporate_user(), 'expired token remains rejected');

select * from finish();
rollback;
