begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null),
  11::bigint,
  'all 11 scenarios have an explicit active owner link'
);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_role_grants rg
     on rg.principal_id=so.owner_id
    and rg.role='scenario_owner'
    and rg.revoked_at is null
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null),
  11::bigint,
  'all 11 explicit owners also have active scenario_owner role'
);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_role_grants rg on rg.principal_id=so.owner_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null
     and rg.revoked_at is null
     and rg.role in ('safra_platform_admin','safra_governance_admin','safra_executive_admin')),
  0::bigint,
  'no active owner is derived from an administrative role'
);

select is(
  (select count(*)::bigint
   from private.safra_principals p
   join private.safra_role_grants rg
     on rg.principal_id=p.id
    and rg.revoked_at is null
    and rg.role in ('safra_platform_admin','safra_governance_admin','safra_executive_admin')
   where exists (
     select 1
     from public.scenario_owners so
     where so.owner_id=p.id
       and so.valid_to is null
   )),
  0::bigint,
  'administrative principals own zero scenarios unless explicitly linked'
);

select ok(
  exists(
    select 1
    from pg_indexes
    where schemaname='public'
      and tablename='scenario_owners'
      and indexname='scenario_owners_one_active_per_scenario'
      and indexdef ilike '%UNIQUE INDEX%'
      and indexdef ilike '%WHERE (valid_to IS NULL)%'
  ),
  'database enforces at most one explicit active owner per scenario'
);

select ok(
  position(
    'published scenario requires exactly one active owner'
    in pg_get_functiondef('private.safra_validate_published_scenario()'::regprocedure)
  ) > 0,
  'published scenario validator rejects missing owner instead of falling back'
);

select ok(
  position(
    'published scenario owner must have active scenario_owner role'
    in pg_get_functiondef('private.safra_validate_published_scenario()'::regprocedure)
  ) > 0,
  'published scenario validator rejects ineligible owner instead of falling back'
);

select throws_ok(
  $$
  do $do$
  declare
    v_owner_link uuid;
  begin
    select so.id into v_owner_link
    from public.scenario_owners so
    join public.scenarios sc on sc.id=so.scenario_id
    where sc.code='SAFRA-01'
      and so.valid_to is null;

    update public.scenario_owners
       set valid_to=clock_timestamp()
     where id=v_owner_link;

    set constraints all immediate;
  end
  $do$;
  $$,
  'P0001',
  'published scenario requires exactly one active owner',
  'closing the only owner link is rejected; no silent fallback owner is selected'
);

select throws_ok(
  $$
  do $do$
  declare
    v_scenario uuid;
    v_owner_link uuid;
    v_admin uuid;
  begin
    select sc.id, so.id
      into v_scenario, v_owner_link
    from public.scenarios sc
    join public.scenario_owners so
      on so.scenario_id=sc.id
     and so.valid_to is null
    where sc.code='SAFRA-01';

    select p.id into v_admin
    from private.safra_principals p
    join private.safra_role_grants rg
      on rg.principal_id=p.id
     and rg.role='safra_governance_admin'
     and rg.revoked_at is null
    where p.corporate_email='jair.silva@editoradobrasil.com.br';

    update public.scenario_owners
       set valid_to=clock_timestamp()
     where id=v_owner_link;

    insert into public.scenario_owners(
      scenario_id, owner_id, assignment_reason
    )
    values(
      v_scenario, v_admin, 'C06.1 negative test: admin must not become owner by role'
    );

    set constraints all immediate;
  end
  $do$;
  $$,
  'P0001',
  'published scenario owner must have active scenario_owner role',
  'admin role alone cannot replace explicit eligible scenario owner'
);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   where sc.code='SAFRA-01'
     and so.valid_to is null),
  1::bigint,
  'negative tests leave SAFRA-01 with exactly one original active owner'
);

select * from finish();
rollback;
