begin;

create extension if not exists pgtap with schema extensions;

select plan(23);

select has_table('public', 'scenarios', 'scenarios exists');
select has_table('public', 'scenario_versions', 'scenario_versions exists');
select has_table('public', 'scenario_owners', 'scenario_owners exists');
select has_table('public', 'treatments', 'treatments exists');
select has_table('public', 'treatment_events', 'treatment_events exists');
select has_table('public', 'governance_issues', 'governance_issues exists');

select is(
  (
    select count(*)::bigint
    from pg_tables
    where schemaname = 'public'
      and tablename in (
        'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
        'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
        'treatments','treatment_impacted_areas','treatment_impact_measurements',
        'treatment_events','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  16::bigint,
  'all 16 SAFRA v2 domain tables exist (treatment_escalations retired by D-73)'
);

select is(
  (
    select count(*)::bigint
    from pg_tables
    where schemaname = 'public'
      and rowsecurity
      and tablename in (
        'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
        'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
        'treatments','treatment_impacted_areas','treatment_impact_measurements',
        'treatment_events','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  16::bigint,
  'RLS is enabled on all SAFRA v2 domain tables'
);

select is(
  (
    select count(*)::bigint
    from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee = 'anon'
      and table_name in (
        'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
        'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
        'treatments','treatment_impacted_areas','treatment_impact_measurements',
        'treatment_events','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  0::bigint,
  'anon has no direct grants on SAFRA v2 domain tables'
);

select is(
  (
    select count(*)::bigint
    from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee = 'authenticated'
      and table_name in (
        'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
        'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
        'treatments','treatment_impacted_areas','treatment_impact_measurements',
        'treatment_events','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  0::bigint,
  'authenticated has no direct grants before governed APIs are opened'
);

select ok(
  (
    select column_default is null
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'scenario_versions'
      and column_name = 'criticality'
  ),
  'scenario criticality has no default'
);

select ok(
  not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'treatments'
      and indexdef ilike '%unique%'
      and indexdef ilike '%active%'
      and indexdef not ilike '%opened_by%'
  ),
  'no one-ACTIVE-per-scenario uniqueness; only per person and scenario (D-57)'
);

select is(
  (
    select count(*)::bigint
    from public.governance_issues
    where issue_key = 'GI-SAFRA-001'
      and status = 'OPEN'
  ),
  1::bigint,
  'GI-SAFRA-001 remains explicitly OPEN'
);

select is(
  (
    select count(*)::bigint
    from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee = 'service_role'
      and privilege_type = 'TRUNCATE'
      and table_name in (
        'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
        'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
        'treatments','treatment_impacted_areas','treatment_impact_measurements',
        'treatment_events','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  0::bigint,
  'service_role has no TRUNCATE privilege on SAFRA v2 domain tables'
);



select ok(
  exists (
    select 1
    from pg_constraint c
    where c.conname = 'scenarios_current_version_same_scenario_fk'
      and c.conrelid = 'public.scenarios'::regclass
      and c.confrelid = 'public.scenario_versions'::regclass
      and c.contype = 'f'
  ),
  'scenario current_version FK is enforced'
);

select has_trigger(
  'public', 'scenario_versions', 'trg_00_scenario_versions_server_clock',
  'scenario version lifecycle uses server-side timestamps'
);

select has_trigger(
  'public', 'treatments', 'trg_00_treatments_server_clock',
  'treatment lifecycle uses server-side timestamps'
);

select has_trigger(
  'public', 'treatment_events', 'trg_treatment_events_append_only',
  'treatment events are append-only'
);

select has_trigger(
  'public', 'treatment_impact_measurements', 'trg_treatment_impact_measurements_append_only',
  'impact measurements are append-only'
);

select has_trigger(
  'public', 'scenario_slas', 'trg_scenario_slas_freeze',
  'published scenario SLA content is version-frozen'
);



select is(
  (
    select count(*)::bigint
    from pg_constraint c
    join pg_class cl on cl.oid = c.conrelid
    join pg_namespace n on n.oid = cl.relnamespace
    where c.contype = 'f'
      and n.nspname = 'public'
      and cl.relname in (
        'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
        'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
        'treatments','treatment_impacted_areas','treatment_impact_measurements',
        'treatment_events','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
      and c.confdeltype = 'c'
  ),
  0::bigint,
  'SAFRA domain has no destructive ON DELETE CASCADE foreign keys'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.treatments'::regclass
      and conname = 'treatments_cancel_reason_required'
  ),
  'CANCEL requires a non-blank reason'
);

select has_trigger(
  'public', 'treatments', 'trg_treatments_guard',
  'treatment guard enforces terminal transition rules and delete protection'
);

select * from finish();
rollback;
