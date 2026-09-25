begin;
create extension if not exists pgtap with schema extensions;
select plan(1);

select is(
  (
    select count(*)::bigint
    from supabase_migrations.schema_migrations
    where version = '__LATEST_VERSION__'
  ),
  0::bigint,
  'latest migration history entry is absent after rollback'
);

select * from finish();
rollback;
