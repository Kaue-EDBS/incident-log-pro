begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

-- C00-AUD2 (D-50): the legacy Reliability Monitor domain is retired, not merely hidden.
select ok(
  to_regclass('public.applications') is null,
  'legacy applications table is retired'
);

select ok(
  to_regclass('public.incidents') is null,
  'legacy incidents table is retired'
);

select ok(
  to_regprocedure('public.validate_incident_timestamps()') is null
  and to_regprocedure('public.set_updated_at()') is null,
  'legacy trigger helpers are retired'
);

-- C00 containment, now asserted over the whole public schema.
select is(
  (select count(*)::bigint
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind in ('r','p')
     and not c.relrowsecurity),
  0::bigint,
  'every public table keeps RLS enabled'
);

select is(
  (select count(*)::bigint
   from information_schema.role_table_grants
   where table_schema = 'public'
     and grantee = 'anon'),
  0::bigint,
  'anon holds no table privilege in public'
);

select is(
  (select count(*)::bigint
   from pg_policies
   where schemaname = 'public'
     and 'anon' = any(roles)),
  0::bigint,
  'no public RLS policy targets anon'
);

select is(
  (select count(*)::bigint
   from pg_policies
   where schemaname = 'public'
     and (coalesce(qual, '') = 'true' or coalesce(with_check, '') = 'true')),
  0::bigint,
  'no public RLS policy is open with USING/WITH CHECK (true)'
);

select is(
  (select count(*)::bigint
   from pg_policies
   where schemaname = 'public'
     and policyname in (
       'Aplicacoes abertas para uso interno',
       'Incidentes abertos para uso interno'
     )),
  0::bigint,
  'old permissive baseline policies stay removed'
);

select * from finish();
rollback;
