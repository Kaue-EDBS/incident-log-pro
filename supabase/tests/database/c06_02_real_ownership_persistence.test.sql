begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select is(
  (select count(*)::bigint
   from public.scenarios
   where code ~ '^SAFRA-(0[1-9]|1[01])$'),
  11::bigint,
  'exactly 11 canonical scenarios exist'
);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null),
  11::bigint,
  'exactly 11 active persisted ownership links exist'
);

select is(
  (select count(*)::bigint
   from (
     select sc.id
     from public.scenarios sc
     left join public.scenario_owners so
       on so.scenario_id=sc.id
      and so.valid_to is null
     where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     group by sc.id
     having count(so.id) <> 1
   ) x),
  0::bigint,
  'every canonical scenario has exactly one active persisted owner'
);

select is(
  (select count(distinct so.owner_id)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null),
  3::bigint,
  'the 11 real links resolve to exactly three owner principals'
);

select is(
  (select array_agg(sc.code order by sc.code)::text
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_principals p on p.id=so.owner_id
   where so.valid_to is null
     and p.corporate_email='daniel.garcia@editoradobrasil.com.br'),
  '{SAFRA-01,SAFRA-02,SAFRA-03,SAFRA-07,SAFRA-10,SAFRA-11}'::text,
  'Daniel real persisted ownership is exactly 1,2,3,7,10,11'
);

select is(
  (select array_agg(sc.code order by sc.code)::text
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_principals p on p.id=so.owner_id
   where so.valid_to is null
     and p.corporate_email='jiane.rodrigues@editoradobrasil.com.br'),
  '{SAFRA-04,SAFRA-05,SAFRA-06,SAFRA-08}'::text,
  'Jiane real persisted ownership is exactly 4,5,6,8'
);

select is(
  (select array_agg(sc.code order by sc.code)::text
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_principals p on p.id=so.owner_id
   where so.valid_to is null
     and p.corporate_email='renato.paulo@editoradobrasil.com.br'),
  '{SAFRA-09}'::text,
  'Renato real persisted ownership is exactly scenario 9'
);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_principals p on p.id=so.owner_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null
     and not exists (
       select 1
       from private.safra_role_grants g
       where g.principal_id=p.id
         and g.role='scenario_owner'
         and g.revoked_at is null
     )),
  0::bigint,
  'every persisted active owner has active scenario_owner role'
);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_role_grants g on g.principal_id=so.owner_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null
     and g.revoked_at is null
     and g.role in ('safra_platform_admin','safra_governance_admin','safra_executive_admin')),
  0::bigint,
  'no active persisted scenario owner inherits an admin role'
);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null
     and (so.valid_from is null or so.valid_from > clock_timestamp())),
  0::bigint,
  'all active persisted ownership links have valid temporal start'
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
  'database enforces at most one active owner per scenario'
);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   left join private.safra_principals p on p.id=so.owner_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null
     and p.id is null),
  0::bigint,
  'no active ownership link points to a missing principal'
);

select is(
  (select count(*)::bigint
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and so.valid_to is null
     and btrim(coalesce(so.assignment_reason,''))=''),
  0::bigint,
  'every active persisted ownership link has assignment reason'
);

select * from finish();
rollback;
