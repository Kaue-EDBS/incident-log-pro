-- SAFRA-C04-AUD2 — identity, RBAC and authorization regressions that were only
-- covered by the PRIMARY self-test harness (private.safra_c04_selftest) or not at all.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

-- ---------------------------------------------------------------------------
-- Fixtures: bind Auth users to seeded principals (C04 binding trigger) and one
-- plain corporate user with its own principal and no role.
-- ---------------------------------------------------------------------------
insert into private.safra_principals(corporate_email, display_name, is_active)
values ('c04aud2.plain@editoradobrasil.com.br', 'C04 AUD2 Plain', true);

insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('04a20000-0000-4000-8000-000000000001','c04aud2.plain@editoradobrasil.com.br','{"provider":"azure"}','{"role":"safra_platform_admin"}',true,false,clock_timestamp(),clock_timestamp()),
  ('04a20000-0000-4000-8000-000000000002','jair.silva@editoradobrasil.com.br','{"provider":"azure"}','{}',true,false,clock_timestamp(),clock_timestamp()),
  ('04a20000-0000-4000-8000-000000000003','bruno.palhao@editoradobrasil.com.br','{"provider":"azure"}','{}',true,false,clock_timestamp(),clock_timestamp()),
  ('04a20000-0000-4000-8000-000000000004','jiane.rodrigues@editoradobrasil.com.br','{"provider":"azure"}','{}',true,false,clock_timestamp(),clock_timestamp());

insert into auth.sessions(id,user_id,created_at,updated_at)
values
  ('04a20000-0000-4000-8000-000000000011','04a20000-0000-4000-8000-000000000001',clock_timestamp(),clock_timestamp()),
  ('04a20000-0000-4000-8000-000000000012','04a20000-0000-4000-8000-000000000002',clock_timestamp(),clock_timestamp()),
  ('04a20000-0000-4000-8000-000000000013','04a20000-0000-4000-8000-000000000003',clock_timestamp(),clock_timestamp()),
  ('04a20000-0000-4000-8000-000000000014','04a20000-0000-4000-8000-000000000004',clock_timestamp(),clock_timestamp());

create temporary table c04_claims(who text primary key, claims text) on commit drop;
insert into c04_claims values
  ('plain', json_build_object('sub','04a20000-0000-4000-8000-000000000001','email','c04aud2.plain@editoradobrasil.com.br',
     'session_id','04a20000-0000-4000-8000-000000000011','is_anonymous',false,
     'app_metadata',json_build_object('provider','azure'),'exp',extract(epoch from now()+interval '1 hour')::bigint)::text),
  ('plain_expired', json_build_object('sub','04a20000-0000-4000-8000-000000000001','email','c04aud2.plain@editoradobrasil.com.br',
     'session_id','04a20000-0000-4000-8000-000000000011','is_anonymous',false,
     'app_metadata',json_build_object('provider','azure'),'exp',extract(epoch from now()-interval '1 minute')::bigint)::text),
  ('plain_revoked', json_build_object('sub','04a20000-0000-4000-8000-000000000001','email','c04aud2.plain@editoradobrasil.com.br',
     'session_id','04a20000-0000-4000-8000-000000000099','is_anonymous',false,
     'app_metadata',json_build_object('provider','azure'),'exp',extract(epoch from now()+interval '1 hour')::bigint)::text),
  ('plain_forged', json_build_object('sub','04a20000-0000-4000-8000-000000000001','email','c04aud2.plain@editoradobrasil.com.br',
     'session_id','04a20000-0000-4000-8000-000000000011','is_anonymous',false,
     'role','service_role',
     'user_metadata',json_build_object('role','safra_platform_admin','roles',json_build_array('safra_governance_admin')),
     'app_metadata',json_build_object('provider','azure','role','safra_platform_admin','safra_access',true),
     'exp',extract(epoch from now()+interval '1 hour')::bigint)::text),
  ('jair', json_build_object('sub','04a20000-0000-4000-8000-000000000002','email','jair.silva@editoradobrasil.com.br',
     'session_id','04a20000-0000-4000-8000-000000000012','is_anonymous',false,
     'app_metadata',json_build_object('provider','azure'),'exp',extract(epoch from now()+interval '1 hour')::bigint)::text),
  ('bruno', json_build_object('sub','04a20000-0000-4000-8000-000000000003','email','bruno.palhao@editoradobrasil.com.br',
     'session_id','04a20000-0000-4000-8000-000000000013','is_anonymous',false,
     'app_metadata',json_build_object('provider','azure'),'exp',extract(epoch from now()+interval '1 hour')::bigint)::text),
  ('jiane', json_build_object('sub','04a20000-0000-4000-8000-000000000004','email','jiane.rodrigues@editoradobrasil.com.br',
     'session_id','04a20000-0000-4000-8000-000000000014','is_anonymous',false,
     'app_metadata',json_build_object('provider','azure'),'exp',extract(epoch from now()+interval '1 hour')::bigint)::text);

-- ---------------------------------------------------------------------------
-- Item 2 — expired or revoked session cannot mutate anything.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select claims from c04_claims where who='plain_expired'), true);

select throws_ok(
  $$ select public.safra_start_treatment((select id from public.scenarios where code='SAFRA-02'),
       '04a20000-0000-4000-8000-000000000101'::uuid, null, '{}'::uuid[]) $$,
  '42501', 'SAFRA_START_FORBIDDEN',
  'C04 item 2: expired token cannot open a protocol'
);

select set_config('request.jwt.claims', (select claims from c04_claims where who='plain_revoked'), true);

select throws_ok(
  $$ select public.safra_start_treatment((select id from public.scenarios where code='SAFRA-02'),
       '04a20000-0000-4000-8000-000000000102'::uuid, null, '{}'::uuid[]) $$,
  '42501', 'SAFRA_START_FORBIDDEN',
  'C04 item 2: revoked/missing session cannot open a protocol'
);

select is(
  (select count(*)::bigint from public.treatments
   where start_idempotency_key in ('04a20000-0000-4000-8000-000000000101','04a20000-0000-4000-8000-000000000102'))
  + (select count(*)::bigint from public.treatment_events
     where idempotency_key in ('04a20000-0000-4000-8000-000000000101','04a20000-0000-4000-8000-000000000102')),
  0::bigint,
  'C04 item 2: rejected sessions leave no treatment and no event'
);

-- ---------------------------------------------------------------------------
-- Item 4 — role claims forged in the token or in user metadata grant nothing.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select claims from c04_claims where who='plain_forged'), true);

select ok(
  not public.safra_has_role('safra_platform_admin')
  and not public.safra_has_role('safra_governance_admin'),
  'C04 item 4: forged role in JWT, app_metadata or user_metadata does not grant a governed role'
);

select is(
  coalesce(cardinality(public.get_my_safra_roles()), 0),
  0,
  'C04 item 4: forged claims do not add roles to the governed role lookup'
);

select is(
  (select count(*)::bigint from public.get_safra_rbac_audit_events(100)),
  0::bigint,
  'C04 item 4: forged claims cannot read the RBAC audit trail'
);

-- ---------------------------------------------------------------------------
-- C04 self-test brought into CI — role change and revocation take effect
-- immediately in the same session (no token refresh).
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select claims from c04_claims where who='plain'), true);

insert into private.safra_role_grants(principal_id, role, source)
select id, 'safra_executive_admin', 'C04_AUD2_ROLE_CHANGE_TEST'
from private.safra_principals where corporate_email = 'c04aud2.plain@editoradobrasil.com.br';

select ok(
  public.safra_has_role('safra_executive_admin'),
  'C04 role change: granted role is recognised immediately'
);

update private.safra_role_grants set revoked_at = clock_timestamp()
where source = 'C04_AUD2_ROLE_CHANGE_TEST';

select ok(
  not public.safra_has_role('safra_executive_admin'),
  'C04 role revocation: revoked role stops working immediately in the same session'
);

-- ---------------------------------------------------------------------------
-- Item 5 — business role separation (Jair, Bruno, Jiane).
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(p.corporate_email order by p.corporate_email)::text
   from private.safra_role_grants g join private.safra_principals p on p.id = g.principal_id
   where g.role = 'safra_governance_admin' and g.revoked_at is null),
  '{jair.silva@editoradobrasil.com.br}',
  'C04 item 5: Jair is the only active governance admin'
);

select set_config('request.jwt.claims', (select claims from c04_claims where who='jair'), true);

select ok(
  public.safra_has_role('safra_governance_admin') and not public.safra_has_role('safra_platform_admin'),
  'C04 item 5: Jair holds governance and no technical platform role'
);

select ok(
  (select count(*) from public.get_safra_rbac_audit_events(100)) >= 1,
  'C04 item 5: Jair (global governance) can read the RBAC audit trail'
);

select set_config('request.jwt.claims', (select claims from c04_claims where who='bruno'), true);

select is(
  public.get_my_safra_roles()::text,
  '{safra_executive_admin}',
  'C04 item 5: Bruno holds only the executive (analytics) role'
);

select ok(
  not public.safra_has_role('safra_platform_admin') and not public.safra_has_role('safra_governance_admin'),
  'C04 item 5: Bruno has no technical nor governance authority'
);

select is(
  (select count(*)::bigint from public.get_safra_rbac_audit_events(100)),
  0::bigint,
  'C04 item 5: Bruno cannot read the RBAC audit trail'
);

select set_config('request.jwt.claims', (select claims from c04_claims where who='jiane'), true);

select is(
  public.get_my_safra_roles()::text,
  '{scenario_owner}',
  'C04 item 5: Jiane holds only the card-owner role'
);

select is(
  (select count(*)::bigint from public.get_safra_rbac_audit_events(100)),
  0::bigint,
  'C04 item 5: Jiane has no global governance (cannot read the RBAC audit trail)'
);

-- ---------------------------------------------------------------------------
-- Item 3 — END/CANCEL: until F01/F02 exist there must be no hidden path.
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::bigint
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname ~* '(end|cancel|close|resolve|finish)'
     and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  0::bigint,
  'C04 item 3: no browser-callable END/CANCEL function exists before F01/F02'
);

select ok(
  not has_table_privilege('authenticated', 'public.treatments', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.treatment_events', 'INSERT'),
  'C04 item 3: browser roles cannot close or cancel by writing treatments/events directly'
);

select * from finish();
rollback;
