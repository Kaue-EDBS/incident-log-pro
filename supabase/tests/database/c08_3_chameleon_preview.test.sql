begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

-- A = Kaue, V = Vinicius, M = Amanda (platform admin without Chameleon, D-96),
-- R = requester, O = owner of SAFRA-09 (Renato).
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, coalesce(p.corporate_email, v.email), '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values
  ('c0830000-0000-4000-8000-00000000000a', null, 'Kaue Pastrello'),
  ('c0830000-0000-4000-8000-00000000000c', null, 'Vinicius Moraes'),
  ('c0830000-0000-4000-8000-00000000000e', null, 'Amanda Bueno'),
  ('c0830000-0000-4000-8000-00000000000b', 'c083.requester@editoradobrasil.com.br', null),
  ('c0830000-0000-4000-8000-00000000000d', null, 'Renato de Paulo')
) as v(id, email, who)
left join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'c0830000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('c0830000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'c0830000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'c0830000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('c0830000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

create temp table ctx(k text primary key, v text);

select pg_temp.act_as('0b');
insert into ctx
select 't1', r->>'treatment_id'
from (select public.safra_start_treatment((select id from public.scenarios where code = 'SAFRA-09'),
        'c0830000-0000-4000-8000-000000000901'::uuid, 'Camaleão: protocolo de teste', '{}'::uuid[]) r) x;

-- Kaue previews Renato's cards.
select pg_temp.act_as('0a');
select ok(public.safra_can_use_chameleon(), 'D-96: Kaue can use Chameleon');
select is(
  jsonb_array_length(public.safra_admin_get_owner_treatments(
    (select id from private.safra_principals where display_name = 'Renato de Paulo'))),
  1, 'D-92: platform admin sees the protocols of the chosen owner');

select ok(
  (select bool_and(not (x->>'can_close_my_part')::boolean and not (x->>'can_cancel')::boolean and x->>'my_role' is null)
   from jsonb_array_elements(public.safra_admin_get_owner_treatments(
     (select id from private.safra_principals where display_name = 'Renato de Paulo'))) x),
  'D-92: the preview is read-only (no close, no cancel, no role)');

select throws_ok(
  $$ select public.safra_close_my_part((select v::uuid from ctx where k = 't1')) $$,
  '42501', 'SAFRA_CLOSE_FORBIDDEN', 'D-92: the admin cannot act as the owner');

-- Vinicius can too.
select pg_temp.act_as('0c');
select ok(public.safra_can_use_chameleon(), 'D-96: Vinicius can use Chameleon');
select is(
  jsonb_array_length(public.safra_admin_get_owner_treatments(
    (select id from private.safra_principals where display_name = 'Renato de Paulo'))),
  1, 'D-96: Vinicius sees the protocols of the chosen owner');

-- Amanda is platform admin but not in the Chameleon list.
select pg_temp.act_as('0e');
select ok(private.safra_has_role('safra_platform_admin'), 'Amanda is still a platform admin');
select ok(not public.safra_can_use_chameleon(), 'D-96: Amanda cannot use Chameleon');
select throws_ok(
  $$ select public.safra_admin_get_owner_treatments((select id from private.safra_principals where display_name = 'Renato de Paulo')) $$,
  '42501', 'SAFRA_PREVIEW_FORBIDDEN', 'D-96: Amanda cannot read the preview');

-- Requester and owner (not platform admins) cannot preview.
select pg_temp.act_as('0b');
select throws_ok(
  $$ select public.safra_admin_get_owner_treatments((select id from private.safra_principals where display_name = 'Renato de Paulo')) $$,
  '42501', 'SAFRA_PREVIEW_FORBIDDEN', 'a regular user cannot use the preview');
select ok(not public.safra_can_use_chameleon(), 'a regular user does not get the Chameleon selector');

select pg_temp.act_as('0d');
select throws_ok(
  $$ select public.safra_admin_get_owner_treatments((select id from private.safra_principals where display_name = 'Daniel Garcia')) $$,
  '42501', 'SAFRA_PREVIEW_FORBIDDEN', 'an owner cannot peek at another owner');

select ok(
  not has_function_privilege('anon', 'public.safra_admin_get_owner_treatments(uuid)', 'EXECUTE'),
  'anon cannot call the preview');

select ok(
  (select prosecdef from pg_proc where proname = 'safra_admin_get_owner_treatments'),
  'preview is a governed SECURITY DEFINER read');

select * from finish();
rollback;
