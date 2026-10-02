begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

-- 1. Principal binding only for Microsoft (azure) Auth users.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('04b20000-0000-4000-8000-000000000001','amanda.bueno@editoradobrasil.com.br','{"provider":"email","providers":["email"]}',false,false,clock_timestamp(),clock_timestamp());

-- AUD-GERAL A-01: Microsoft identity of the corporate tenant for synthetic azure users.
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text,u.id,jsonb_build_object('sub',u.id::text,'email',u.email,'custom_claims',jsonb_build_object('tid','45ba725f-d260-45c3-ac85-11f433471277')),'azure',clock_timestamp(),clock_timestamp()
from auth.users u
where u.raw_app_meta_data->>'provider'='azure'
  and not exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='azure');

select ok(
  (select user_id is null from private.safra_principals where corporate_email = 'amanda.bueno@editoradobrasil.com.br'),
  'e-mail/password Auth user cannot claim a corporate principal'
);

insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('04b20000-0000-4000-8000-000000000002','vinicius.moraes@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());

-- AUD-GERAL A-01: Microsoft identity of the corporate tenant for synthetic azure users.
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text,u.id,jsonb_build_object('sub',u.id::text,'email',u.email,'custom_claims',jsonb_build_object('tid','45ba725f-d260-45c3-ac85-11f433471277')),'azure',clock_timestamp(),clock_timestamp()
from auth.users u
where u.raw_app_meta_data->>'provider'='azure'
  and not exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='azure');

select is(
  (select user_id from private.safra_principals where corporate_email = 'vinicius.moraes@editoradobrasil.com.br'),
  '04b20000-0000-4000-8000-000000000002'::uuid,
  'Microsoft (azure) Auth user is bound to its corporate principal'
);

insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('04b20000-0000-4000-8000-000000000003','vinicius.moraes@editoradobrasil.com.br.squat','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());

-- AUD-GERAL A-01: Microsoft identity of the corporate tenant for synthetic azure users.
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text,u.id,jsonb_build_object('sub',u.id::text,'email',u.email,'custom_claims',jsonb_build_object('tid','45ba725f-d260-45c3-ac85-11f433471277')),'azure',clock_timestamp(),clock_timestamp()
from auth.users u
where u.raw_app_meta_data->>'provider'='azure'
  and not exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='azure');
update auth.users set email = 'vinicius.moraes@editoradobrasil.com.br' where id = '04b20000-0000-4000-8000-000000000003';

select is(
  (select user_id from private.safra_principals where corporate_email = 'vinicius.moraes@editoradobrasil.com.br'),
  '04b20000-0000-4000-8000-000000000002'::uuid,
  'an already bound principal is never re-bound to another Auth user'
);

-- 2. New public objects are born closed.
create table public.c04aud2_default_acl_probe(id int);
create function public.c04aud2_default_acl_probe_fn() returns int language sql as $$ select 1 $$;
create sequence public.c04aud2_default_acl_probe_seq;

select ok(
  not has_table_privilege('anon', 'public.c04aud2_default_acl_probe', 'SELECT')
  and not has_table_privilege('authenticated', 'public.c04aud2_default_acl_probe', 'SELECT')
  and not has_table_privilege('authenticated', 'public.c04aud2_default_acl_probe', 'INSERT'),
  'new public table grants nothing to anon/authenticated by default'
);

select ok(
  not has_function_privilege('anon', 'public.c04aud2_default_acl_probe_fn()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.c04aud2_default_acl_probe_fn()', 'EXECUTE'),
  'new public function is not executable by anon/authenticated by default'
);

select ok(
  not has_sequence_privilege('anon', 'public.c04aud2_default_acl_probe_seq', 'USAGE')
  and not has_sequence_privilege('authenticated', 'public.c04aud2_default_acl_probe_seq', 'USAGE'),
  'new public sequence grants nothing to anon/authenticated by default'
);

-- 3. PRIMARY-only self-test harness is gone (its checks live in CI).
select ok(
  to_regprocedure('private.safra_c04_selftest(text)') is null,
  'C04 self-test function is removed'
);

select ok(
  to_regclass('private.safra_c04_test_runs') is null,
  'C04 self-test results table is removed'
);

select * from finish();
rollback;
