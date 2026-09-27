begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

select is(
  (select count(*)::bigint
   from pg_class c
   where c.relnamespace='public'::regnamespace
     and c.relname in ('scenarios','scenario_versions','scenario_owners','operational_areas','systems')
     and c.relrowsecurity),
  5::bigint,
  'all Safra catalog/ownership tables keep RLS enabled'
);

select is(
  (select count(*)::bigint
   from information_schema.role_table_grants
   where table_schema='public'
     and grantee='anon'
     and privilege_type='SELECT'
     and table_name in ('scenarios','scenario_versions','scenario_owners','operational_areas','systems')),
  0::bigint,
  'anon has no direct Safra catalog SELECT'
);

select is(
  (select count(*)::bigint
   from information_schema.role_table_grants
   where table_schema='public'
     and grantee='authenticated'
     and privilege_type='SELECT'
     and table_name in ('scenarios','scenario_versions','scenario_owners','operational_areas','systems')),
  0::bigint,
  'authenticated has no direct Safra catalog SELECT before governed read API exists'
);

select is(
  (select count(*)::bigint
   from pg_policies
   where schemaname='public'
     and tablename in ('scenarios','scenario_versions','scenario_owners','operational_areas','systems')),
  0::bigint,
  'no direct Data API read policy silently exposes Safra catalog'
);

select ok(
  not has_function_privilege('anon','public.safra_is_corporate_user()','EXECUTE'),
  'anon cannot execute corporate authorization predicate'
);

select ok(
  has_function_privilege('authenticated','public.safra_is_corporate_user()','EXECUTE'),
  'authenticated can execute corporate authorization predicate'
);

select ok(
  not has_function_privilege('anon','public.get_my_safra_roles()','EXECUTE'),
  'anon cannot execute governed role lookup'
);

select ok(
  has_function_privilege('authenticated','public.get_my_safra_roles()','EXECUTE'),
  'authenticated can execute governed role lookup'
);

select ok(
  not has_function_privilege('anon','public.safra_has_role(text)','EXECUTE'),
  'anon cannot execute role predicate'
);

select ok(
  has_function_privilege('authenticated','public.safra_has_role(text)','EXECUTE'),
  'authenticated can execute role predicate'
);

select is(
  (select count(*)::bigint
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public'
     and p.prokind='f'
     and (lower(p.proname) like '%scenario%' or lower(p.proname) like '%owner%')),
  0::bigint,
  'no public scenario read RPC exists yet; UI cannot bypass deny-by-default through RPC'
);

select is(
  (select count(*)::bigint
   from information_schema.role_table_grants
   where table_schema='private'
     and grantee in ('anon','authenticated')
     and table_name in ('safra_principals','safra_role_grants')),
  0::bigint,
  'browser roles cannot read or mutate private RBAC source tables directly'
);

select * from finish();
rollback;
