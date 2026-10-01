begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

select is(
  (select count(*)::bigint from pg_class c
   where c.relnamespace='public'::regnamespace
     and c.relname in (
      'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
      'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
      'treatments','treatment_impacted_areas','treatment_impact_measurements',
      'treatment_events','scenario_proposals',
      'scenario_proposal_owner_responses','notifications_log','governance_issues'
     )
     and c.relrowsecurity),
  16::bigint,
  'all 16 SAFRA domain tables keep RLS enabled'
);

select is(
  (select count(*)::bigint
   from pg_constraint c
   join pg_class cl on cl.oid=c.conrelid
   where c.contype='f'
     and c.confdeltype='c'
     and cl.relname in (
      'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
      'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
      'treatments','treatment_impacted_areas','treatment_impact_measurements',
      'treatment_events','scenario_proposals',
      'scenario_proposal_owner_responses','notifications_log','governance_issues'
     )),
  0::bigint,
  'SAFRA domain keeps zero destructive cascade FKs'
);

select is(
  (select count(*)::bigint
   from information_schema.role_table_grants
   where table_schema='public'
     and table_name in (
      'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
      'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
      'treatments','treatment_impacted_areas','treatment_impact_measurements',
      'treatment_events','scenario_proposals',
      'scenario_proposal_owner_responses','notifications_log','governance_issues'
     )
     and grantee in ('anon','authenticated')),
  0::bigint,
  'domain tables keep no direct anon/authenticated grants'
);

select ok(
  not has_function_privilege('anon','private.safra_audit_role_grant_change()','EXECUTE')
  and not has_function_privilege('authenticated','private.safra_audit_role_grant_change()','EXECUTE')
  and not has_function_privilege('anon','private.safra_rbac_audit_immutable()','EXECUTE')
  and not has_function_privilege('authenticated','private.safra_rbac_audit_immutable()','EXECUTE')
  and not has_function_privilege('anon','private.safra_correlation_id()','EXECUTE')
  and not has_function_privilege('authenticated','private.safra_correlation_id()','EXECUTE'),
  'private SAFRA helpers are not executable by anon/authenticated'
);

select is(
  (select count(*)::bigint from public.scenarios where code ~ '^SAFRA-(0[1-9]|1[01])$'),
  11::bigint,
  'canonical catalog remains exactly 11 scenarios'
);

select is(
  (select count(*)::bigint
   from public.scenario_versions sv
   join public.scenarios sc on sc.id=sv.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and sv.criticality is null),
  11::bigint,
  'v1 history keeps null criticality for all 11 (D-55 applies to v2 only)'
);

select is(
  (select count(*)::bigint from public.treatments),
  0::bigint,
  'audit/seed does not create fake treatments'
);

select is(
  (select count(*)::bigint from storage.buckets),
  0::bigint,
  'storage remains disabled/unused in current MVP scope'
);



select ok(
  not has_function_privilege(
    'authenticated',
    'public.safra_log_access_denied(text,text)',
    'EXECUTE'
  ),
  'access-denied audit writer is backend-only'
);

select * from finish();
rollback;
