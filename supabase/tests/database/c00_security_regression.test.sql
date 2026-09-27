begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

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

select ok(
  has_column_privilege('authenticated','public.incidents','application_id','INSERT')
  and has_column_privilege('authenticated','public.incidents','status','INSERT')
  and has_column_privilege('authenticated','public.incidents','detected_at','INSERT')
  and has_column_privilege('authenticated','public.incidents','type','INSERT')
  and has_column_privilege('authenticated','public.incidents','category','INSERT'),
  'authenticated keeps only the intended legacy incident INSERT path'
);

select ok(
  not has_column_privilege('authenticated','public.incidents','id','INSERT')
  and not has_column_privilege('authenticated','public.incidents','failure_started_at','INSERT')
  and not has_column_privilege('authenticated','public.incidents','response_started_at','INSERT')
  and not has_column_privilege('authenticated','public.incidents','recovered_at','INSERT')
  and not has_column_privilege('authenticated','public.incidents','responsible','INSERT')
  and not has_column_privilege('authenticated','public.incidents','cause','INSERT')
  and not has_column_privilege('authenticated','public.incidents','resolution','INSERT')
  and not has_column_privilege('authenticated','public.incidents','notes','INSERT')
  and not has_column_privilege('authenticated','public.incidents','created_at','INSERT')
  and not has_column_privilege('authenticated','public.incidents','updated_at','INSERT'),
  'authenticated cannot INSERT protected legacy incident columns'
);

select ok(
  has_column_privilege('authenticated','public.incidents','failure_started_at','UPDATE')
  and has_column_privilege('authenticated','public.incidents','response_started_at','UPDATE')
  and has_column_privilege('authenticated','public.incidents','recovered_at','UPDATE')
  and has_column_privilege('authenticated','public.incidents','status','UPDATE')
  and has_column_privilege('authenticated','public.incidents','type','UPDATE')
  and has_column_privilege('authenticated','public.incidents','category','UPDATE')
  and has_column_privilege('authenticated','public.incidents','responsible','UPDATE')
  and has_column_privilege('authenticated','public.incidents','cause','UPDATE')
  and has_column_privilege('authenticated','public.incidents','resolution','UPDATE')
  and has_column_privilege('authenticated','public.incidents','notes','UPDATE'),
  'authenticated keeps only the intended legacy incident UPDATE path'
);

select ok(
  not has_column_privilege('authenticated','public.incidents','id','UPDATE')
  and not has_column_privilege('authenticated','public.incidents','application_id','UPDATE')
  and not has_column_privilege('authenticated','public.incidents','detected_at','UPDATE')
  and not has_column_privilege('authenticated','public.incidents','created_at','UPDATE')
  and not has_column_privilege('authenticated','public.incidents','updated_at','UPDATE'),
  'authenticated cannot UPDATE legacy incident identity and source columns'
);

select ok(
  not has_table_privilege('authenticated','public.incidents','DELETE'),
  'authenticated cannot DELETE legacy incidents'
);

select ok(
  not has_table_privilege('authenticated','public.applications','INSERT')
  and not has_table_privilege('authenticated','public.applications','UPDATE')
  and not has_table_privilege('authenticated','public.applications','DELETE'),
  'authenticated applications access remains read-only'
);

select * from finish();
rollback;
