begin;

create extension if not exists pgtap with schema extensions;

select plan(14);

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
        'treatment_events','treatment_escalations','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  17::bigint,
  'all 17 SAFRA v2 domain tables exist'
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
        'treatment_events','treatment_escalations','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  17::bigint,
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
        'treatment_events','treatment_escalations','scenario_proposals',
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
        'treatment_events','treatment_escalations','scenario_proposals',
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
  ),
  'C05 does not invent one-ACTIVE-treatment-per-scenario uniqueness'
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
        'treatment_events','treatment_escalations','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  0::bigint,
  'service_role has no TRUNCATE privilege on SAFRA v2 domain tables'
);

select * from finish();
rollback;
