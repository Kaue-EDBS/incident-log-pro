begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

select ok(
  (select relrowsecurity from pg_class where oid='public.applications'::regclass),
  'C00 legacy applications keeps RLS enabled'
);

select ok(
  (select relrowsecurity from pg_class where oid='public.incidents'::regclass),
  'C00 legacy incidents keeps RLS enabled'
);

select ok(
  not has_table_privilege('anon','public.applications','SELECT'),
  'anon cannot SELECT applications through Data API'
);

select ok(
  not has_table_privilege('anon','public.incidents','SELECT'),
  'anon cannot SELECT incidents through Data API'
);

select ok(
  not has_table_privilege('anon','public.incidents','INSERT'),
  'anon cannot INSERT incidents through Data API'
);

select ok(
  not has_table_privilege('anon','public.incidents','UPDATE'),
  'anon cannot UPDATE incidents through Data API'
);

select ok(
  not has_table_privilege('anon','public.incidents','DELETE'),
  'anon cannot DELETE incidents through Data API'
);

select ok(
  not has_table_privilege('anon','public.applications','INSERT')
  and not has_table_privilege('anon','public.applications','UPDATE')
  and not has_table_privilege('anon','public.applications','DELETE'),
  'anon has no mutation privilege on applications'
);

select is(
  (select count(*)::bigint
   from pg_policies
   where schemaname='public'
     and tablename='applications'
     and 'anon'=any(roles)),
  0::bigint,
  'applications exposes no anon RLS policy'
);

select is(
  (select count(*)::bigint
   from pg_policies
   where schemaname='public'
     and tablename='incidents'
     and 'anon'=any(roles)),
  0::bigint,
  'incidents exposes no anon RLS policy'
);

select is(
  (select count(*)::bigint
   from pg_policies
   where schemaname='public'
     and tablename in ('applications','incidents')
     and policyname in (
       'Aplicacoes abertas para uso interno',
       'Incidentes abertos para uso interno'
     )),
  0::bigint,
  'old permissive C00 baseline policies stay removed'
);

select ok(
  has_table_privilege('authenticated','public.applications','SELECT')
  and has_table_privilege('authenticated','public.incidents','SELECT'),
  'authenticated access remains intentional and RLS-governed after C04'
);

select * from finish();
rollback;
