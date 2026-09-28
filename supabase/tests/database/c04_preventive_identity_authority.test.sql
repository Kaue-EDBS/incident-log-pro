begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

-- PREV-01 — binding principal -> auth.user must only bind identity.
insert into private.safra_principals(
  id, corporate_email, display_name, is_active
)
values(
  '04040404-4000-4000-8000-000000000001'::uuid,
  'c04.binding.synthetic@editoradobrasil.com.br',
  'C04 Binding Synthetic',
  true
);

insert into private.safra_role_grants(
  principal_id, role, source
)
values(
  '04040404-4000-4000-8000-000000000001'::uuid,
  'scenario_owner',
  'C04_PREV_01_TEST'
);

create temporary table c04_binding_snapshot as
select
  (select count(*) from private.safra_role_grants where revoked_at is null) as role_count,
  (select count(*) from public.scenario_owners where valid_to is null) as owner_count;

insert into auth.users(
  id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at
)
values(
  '04040404-4000-4000-8000-000000000002'::uuid,
  'c04.binding.synthetic@editoradobrasil.com.br',
  '{"provider":"azure"}'::jsonb,
  true,
  false,
  clock_timestamp(),
  clock_timestamp()
);

select is(
  (
    select user_id
    from private.safra_principals
    where corporate_email='c04.binding.synthetic@editoradobrasil.com.br'
  ),
  '04040404-4000-4000-8000-000000000002'::uuid,
  'PREV-01: first auth user with matching corporate email binds to the pre-provisioned principal'
);

select is(
  (
    select array_agg(role order by role)
    from private.safra_role_grants
    where principal_id='04040404-4000-4000-8000-000000000001'::uuid
      and revoked_at is null
  ),
  array['scenario_owner']::text[],
  'PREV-01: identity binding does not change the pre-provisioned role'
);

select is(
  (select count(*)::bigint from public.scenario_owners where valid_to is null),
  (select owner_count::bigint from c04_binding_snapshot),
  'PREV-01: identity binding does not create or rewrite scenario ownership'
);

select is(
  (select count(*)::bigint from private.safra_role_grants where revoked_at is null),
  (select role_count::bigint from c04_binding_snapshot),
  'PREV-01: identity binding does not create extra active role grants'
);

select ok(
  exists(
    select 1
    from pg_trigger
    where tgrelid='auth.users'::regclass
      and tgname='trg_bind_safra_principal_from_auth_user'
      and not tgisinternal
  ),
  'PREV-01: auth.users binding trigger remains installed'
);

-- PREV-02 — exact governed role matrix.
with expected(email,role) as (
  values
    ('kaue.pastrello@editoradobrasil.com.br','safra_platform_admin'),
    ('amanda.bueno@editoradobrasil.com.br','safra_platform_admin'),
    ('vinicius.moraes@editoradobrasil.com.br','safra_platform_admin'),
    ('joao.jurado@editoradobrasil.com.br','safra_platform_admin'),
    ('jair.silva@editoradobrasil.com.br','safra_governance_admin'),
    ('bruno.palhao@editoradobrasil.com.br','safra_executive_admin'),
    ('daniel.garcia@editoradobrasil.com.br','scenario_owner'),
    ('jiane.rodrigues@editoradobrasil.com.br','scenario_owner'),
    ('renato.paulo@editoradobrasil.com.br','scenario_owner')
)
select is(
  (
    select count(*)::bigint
    from expected e
    join private.safra_principals p
      on p.corporate_email=e.email
     and p.is_active
    join private.safra_role_grants rg
      on rg.principal_id=p.id
     and rg.role=e.role
     and rg.revoked_at is null
  ),
  9::bigint,
  'PREV-02: all nine governed principals have their intended active role'
);

select is(
  (
    select count(*)::bigint
    from private.safra_role_grants rg
    join private.safra_principals p on p.id=rg.principal_id
    where rg.revoked_at is null
      and p.corporate_email in (
        'kaue.pastrello@editoradobrasil.com.br',
        'amanda.bueno@editoradobrasil.com.br',
        'vinicius.moraes@editoradobrasil.com.br',
        'joao.jurado@editoradobrasil.com.br',
        'jair.silva@editoradobrasil.com.br',
        'bruno.palhao@editoradobrasil.com.br',
        'daniel.garcia@editoradobrasil.com.br',
        'jiane.rodrigues@editoradobrasil.com.br',
        'renato.paulo@editoradobrasil.com.br'
      )
  ),
  9::bigint,
  'PREV-02: governed principals have no extra active role beyond the approved matrix'
);

select is(
  (
    select array_agg(role order by role)
    from private.safra_role_grants rg
    join private.safra_principals p on p.id=rg.principal_id
    where p.corporate_email='bruno.palhao@editoradobrasil.com.br'
      and rg.revoked_at is null
  ),
  array['safra_executive_admin']::text[],
  'PREV-02: Bruno is executive only, with no platform/governance/owner role'
);

select is(
  (
    select array_agg(role order by role)
    from private.safra_role_grants rg
    join private.safra_principals p on p.id=rg.principal_id
    where p.corporate_email='jair.silva@editoradobrasil.com.br'
      and rg.revoked_at is null
  ),
  array['safra_governance_admin']::text[],
  'PREV-02: Jair is governance only'
);

-- PREV-03 — role never implies ownership.
select is(
  (
    select count(*)::bigint
    from public.scenario_owners so
    join private.safra_principals p on p.id=so.owner_id
    where so.valid_to is null
      and p.corporate_email in (
        'kaue.pastrello@editoradobrasil.com.br',
        'amanda.bueno@editoradobrasil.com.br',
        'vinicius.moraes@editoradobrasil.com.br',
        'joao.jurado@editoradobrasil.com.br',
        'jair.silva@editoradobrasil.com.br',
        'bruno.palhao@editoradobrasil.com.br'
      )
  ),
  0::bigint,
  'PREV-03: platform/governance/executive principals own zero scenarios without explicit eligible ownership'
);

select is(
  (
    select count(*)::bigint
    from private.safra_role_grants admin_rg
    join private.safra_role_grants owner_rg
      on owner_rg.principal_id=admin_rg.principal_id
    where admin_rg.revoked_at is null
      and owner_rg.revoked_at is null
      and admin_rg.role in ('safra_platform_admin','safra_governance_admin','safra_executive_admin')
      and owner_rg.role='scenario_owner'
  ),
  0::bigint,
  'PREV-03: no administrative principal silently inherits scenario_owner role'
);

select is(
  (
    select count(*)::bigint
    from public.scenario_owners so
    join public.scenarios sc on sc.id=so.scenario_id
    where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
      and so.valid_to is null
  ),
  11::bigint,
  'PREV-03: all 11 canonical scenarios keep one explicit active ownership link'
);

select is(
  (
    select count(*)::bigint
    from public.scenario_owners so
    join public.scenarios sc on sc.id=so.scenario_id
    join private.safra_role_grants rg
      on rg.principal_id=so.owner_id
     and rg.role='scenario_owner'
     and rg.revoked_at is null
    where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
      and so.valid_to is null
  ),
  11::bigint,
  'PREV-03: all 11 explicit owners are independently eligible through scenario_owner'
);

select is(
  (
    select count(*)::bigint
    from public.scenario_owners so
    join private.safra_principals p on p.id=so.owner_id
    where so.valid_to is null
      and p.corporate_email='daniel.garcia@editoradobrasil.com.br'
  ),
  6::bigint,
  'PREV-03: Daniel retains exactly 6 cards'
);

select is(
  (
    select count(*)::bigint
    from public.scenario_owners so
    join private.safra_principals p on p.id=so.owner_id
    where so.valid_to is null
      and p.corporate_email='jiane.rodrigues@editoradobrasil.com.br'
  ),
  4::bigint,
  'PREV-03: Jiane retains exactly 4 cards'
);

select is(
  (
    select count(*)::bigint
    from public.scenario_owners so
    join private.safra_principals p on p.id=so.owner_id
    where so.valid_to is null
      and p.corporate_email='renato.paulo@editoradobrasil.com.br'
  ),
  1::bigint,
  'PREV-03: Renato retains exactly 1 card'
);

-- PREV-04 — privilege escalation must not exist in the browser/RPC contract.
select is(
  pg_get_function_identity_arguments(
    'public.safra_start_treatment(uuid,uuid,text,uuid[])'::regprocedure
  ),
  'p_scenario_id uuid, p_idempotency_key uuid, p_impact_summary text, p_impacted_area_ids uuid[]',
  'PREV-04: START exposes no owner, role, version, actor, criticality or timestamp override parameter'
);

select is(
  (
    select count(*)::bigint
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='safra_start_treatment'
  ),
  1::bigint,
  'PREV-04: START has a single governed overload'
);

select ok(
  not has_table_privilege('authenticated','private.safra_principals','UPDATE')
  and not has_table_privilege('authenticated','private.safra_role_grants','INSERT')
  and not has_table_privilege('authenticated','private.safra_role_grants','UPDATE'),
  'PREV-04: browser role cannot mutate principals or role grants directly'
);

select ok(
  not has_table_privilege('authenticated','public.scenario_owners','INSERT')
  and not has_table_privilege('authenticated','public.scenario_owners','UPDATE')
  and not has_table_privilege('authenticated','public.scenario_versions','UPDATE'),
  'PREV-04: browser role cannot override owner or scenario version through direct table writes'
);

select ok(
  position(
    'v_actor uuid := (select auth.uid())'
    in pg_get_functiondef('public.safra_start_treatment(uuid,uuid,text,uuid[])'::regprocedure)
  ) > 0,
  'PREV-04: START actor remains derived from auth.uid() inside the server command'
);

select ok(
  position(
    'so.owner_id'
    in pg_get_functiondef('public.safra_start_treatment(uuid,uuid,text,uuid[])'::regprocedure)
  ) > 0
  and position(
    'v_scenario_version_id'
    in pg_get_functiondef('public.safra_start_treatment(uuid,uuid,text,uuid[])'::regprocedure)
  ) > 0,
  'PREV-04: START owner/version remain resolved from server-side scenario state'
);

select * from finish();
rollback;
