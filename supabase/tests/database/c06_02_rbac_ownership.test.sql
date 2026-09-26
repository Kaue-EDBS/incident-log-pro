begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

select is(
  (select array_agg(sc.code order by sc.code)::text
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_principals p on p.id=so.owner_id
   where so.valid_to is null and p.display_name='Daniel Garcia'),
  '{SAFRA-01,SAFRA-02,SAFRA-03,SAFRA-07,SAFRA-10,SAFRA-11}'::text,
  'Daniel owns exactly scenarios 1,2,3,7,10,11'
);

select is(
  (select array_agg(sc.code order by sc.code)::text
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_principals p on p.id=so.owner_id
   where so.valid_to is null and p.display_name='Jiane Rodrigues'),
  '{SAFRA-04,SAFRA-05,SAFRA-06,SAFRA-08}'::text,
  'Jiane owns exactly scenarios 4,5,6,8'
);

select is(
  (select array_agg(sc.code order by sc.code)::text
   from public.scenario_owners so
   join public.scenarios sc on sc.id=so.scenario_id
   join private.safra_principals p on p.id=so.owner_id
   where so.valid_to is null and p.display_name='Renato de Paulo'),
  '{SAFRA-09}'::text,
  'Renato owns exactly scenario 9'
);

select is(
  (select count(*)::bigint from public.scenario_owners so
   join private.safra_principals p on p.id=so.owner_id
   where so.valid_to is null and p.display_name='Jair Silva'),
  0::bigint,
  'Jair governance admin has no ownership'
);

select is(
  (select count(*)::bigint from public.scenario_owners so
   join private.safra_principals p on p.id=so.owner_id
   where so.valid_to is null and p.display_name='Bruno Palhao'),
  0::bigint,
  'Bruno executive admin has no ownership'
);

select is(
  (select count(*)::bigint from public.scenario_owners so
   join private.safra_principals p on p.id=so.owner_id
   where so.valid_to is null
     and p.display_name in ('Kaue Pastrello','Amanda Bueno','Vinicius Moraes','Joao Jurado')),
  0::bigint,
  'platform admins do not inherit ownership'
);

select is(
  (select count(*)::bigint
   from private.safra_role_grants g1
   join private.safra_role_grants g2 on g2.principal_id=g1.principal_id
   where g1.revoked_at is null and g2.revoked_at is null
     and g1.role in ('safra_platform_admin','safra_governance_admin','safra_executive_admin')
     and g2.role='scenario_owner'),
  0::bigint,
  'no admin principal inherits scenario_owner role'
);

select ok(
  not has_table_privilege('authenticated','public.scenario_owners','INSERT'),
  'authenticated cannot self-assign owner with INSERT'
);

select ok(
  not has_table_privilege('authenticated','public.scenario_owners','UPDATE'),
  'authenticated cannot change owner with UPDATE'
);

select ok(
  not has_table_privilege('authenticated','public.scenario_owners','DELETE'),
  'authenticated cannot delete ownership history'
);

select ok(
  (select relrowsecurity from pg_class where oid='public.scenario_owners'::regclass),
  'scenario_owners keeps RLS enabled'
);

select is(
  (select count(*)::bigint from pg_policies where schemaname='public' and tablename='scenario_owners'),
  0::bigint,
  'scenario_owners has no direct authenticated RLS mutation policy'
);

select * from finish();
rollback;
