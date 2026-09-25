begin;

create extension if not exists pgtap with schema extensions;

select plan(2);

select is(
  (
    select count(*)::bigint
    from pg_constraint
    where conrelid = 'public.treatments'::regclass
      and conname = 'treatments_cancel_reason_required'
  ),
  0::bigint,
  'latest C05 constraint is absent after rolling back one migration'
);

select is(
  (
    select count(*)::bigint
    from supabase_migrations.schema_migrations
    where version = '20260925210500'
  ),
  0::bigint,
  'latest C05 migration history entry is absent after rollback'
);

select * from finish();
rollback;
