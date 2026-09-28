begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

select is(
  (
    select count(*)::bigint
    from supabase_migrations.schema_migrations
    where version='20260928095246'
  ),
  0::bigint,
  'C05 Block C migration history entry is absent after local rollback'
);

select is(
  (
    select count(*)::bigint
    from pg_indexes
    where schemaname='public'
      and indexname in (
        'idx_governance_issues_resolved_by',
        'idx_scenario_proposal_owner_responses_candidate_owner_id',
        'idx_scenario_version_impacted_areas_operational_area_id',
        'idx_scenario_version_systems_system_id',
        'idx_treatment_impacted_areas_operational_area_id'
      )
  ),
  0::bigint,
  'all five C05 Block C support indexes are absent after rollback'
);

select ok(
  exists(
    select 1
    from pg_trigger
    where tgrelid='public.treatments'::regclass
      and tgname='trg_treatments_updated_at'
      and not tgisinternal
  ),
  'previous treatment updated_at trigger is restored after rollback'
);

select ok(
  position(
    'new.updated_at := clock_timestamp()'
    in pg_get_functiondef('private.safra_guard_scenario_version_update()'::regprocedure)
  ) > 0,
  'previous scenario version guard clock behavior is restored after rollback'
);

select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid='public.scenario_versions'::regclass
      and tgname='trg_00_scenario_versions_server_clock'
      and not tgisinternal
  ),
  'scenario version server-clock trigger remains present in the previous schema'
);

select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid='public.treatments'::regclass
      and tgname='trg_00_treatments_server_clock'
      and not tgisinternal
  ),
  'treatment server-clock trigger remains present in the previous schema'
);

select ok(
  to_regclass('public.governance_issues') is not null,
  'rollback preserves pre-existing governance schema'
);

select ok(
  to_regclass('public.treatments') is not null,
  'rollback preserves treatment history table'
);

select ok(
  to_regclass('public.scenario_versions') is not null,
  'rollback preserves scenario version history table'
);

select * from finish();
rollback;
