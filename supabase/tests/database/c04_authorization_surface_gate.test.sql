begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

create temporary table c04_expected_tables(name text primary key) on commit drop;
insert into c04_expected_tables(name) values
('applications'),
('governance_issues'),
('incidents'),
('notifications_log'),
('operational_areas'),
('scenario_owners'),
('scenario_proposal_owner_responses'),
('scenario_proposals'),
('scenario_slas'),
('scenario_version_impacted_areas'),
('scenario_version_systems'),
('scenario_versions'),
('scenarios'),
('systems'),
('treatment_escalations'),
('treatment_events'),
('treatment_impact_measurements'),
('treatment_impacted_areas'),
('treatments');

create temporary table c04_expected_public_functions(signature text primary key) on commit drop;
insert into c04_expected_public_functions(signature) values
('get_my_safra_roles()'),
('get_safra_rbac_audit_events(integer)'),
('safra_get_start_catalog()'),
('safra_has_role(text)'),
('safra_is_corporate_user()'),
('safra_log_access_denied(text,text)'),
('safra_session_is_live()'),
('safra_start_treatment(uuid,uuid,text,uuid[])'),
('set_updated_at()'),
('validate_incident_timestamps()');

create temporary table c04_authenticated_execute_allowlist(signature text primary key) on commit drop;
insert into c04_authenticated_execute_allowlist(signature) values
('get_my_safra_roles()'),
('get_safra_rbac_audit_events(integer)'),
('safra_get_start_catalog()'),
('safra_has_role(text)'),
('safra_is_corporate_user()'),
('safra_session_is_live()'),
('safra_start_treatment(uuid,uuid,text,uuid[])');

select is(
  (select count(*)::bigint from c04_expected_tables),
  19::bigint,
  'PREV-05: authorization contract explicitly inventories 19 public tables'
);

select is(
  (
    select count(*)::bigint
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relkind in ('r','v','m','p')
      and not exists(select 1 from c04_expected_tables e where e.name=c.relname)
  ),
  0::bigint,
  'PREV-05: no unreviewed public table/view exists outside the canonical contract'
);

select is(
  (
    select count(*)::bigint
    from c04_expected_tables e
    where not exists(
      select 1
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public'
        and c.relkind in ('r','v','m','p')
        and c.relname=e.name
    )
  ),
  0::bigint,
  'PREV-05: every contracted public table/view still exists'
);

select is(
  (
    select count(*)::bigint
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relkind in ('r','p')
      and not c.relrowsecurity
  ),
  0::bigint,
  'PREV-05: every public base/partitioned table keeps RLS enabled'
);

select is(
  (
    select count(*)::bigint
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relkind in ('r','v','m','p')
      and (
        has_table_privilege('anon',c.oid,'SELECT')
        or has_table_privilege('anon',c.oid,'INSERT')
        or has_table_privilege('anon',c.oid,'UPDATE')
        or has_table_privilege('anon',c.oid,'DELETE')
      )
  ),
  0::bigint,
  'PREV-06: anon has zero CRUD privileges on the entire public relation surface'
);

select is(
  (
    select count(*)::bigint
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relkind in ('r','v','m','p')
      and (
        has_table_privilege('authenticated',c.oid,'SELECT')
        or has_table_privilege('authenticated',c.oid,'INSERT')
        or has_table_privilege('authenticated',c.oid,'UPDATE')
        or has_table_privilege('authenticated',c.oid,'DELETE')
      )
  ),
  0::bigint,
  'PREV-05: authenticated browser has zero direct CRUD privileges on public relations'
);

select is(
  (select count(*)::bigint from pg_policies where schemaname='public'),
  0::bigint,
  'PREV-05: no public RLS policy creates a hidden direct-table surface'
);

select is(
  (
    select count(*)::bigint
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and not exists(
        select 1
        from c04_expected_public_functions e
        where e.signature=p.oid::regprocedure::text
      )
  ),
  0::bigint,
  'PREV-05: no unreviewed public function exists outside the canonical contract'
);

select is(
  (
    select count(*)::bigint
    from c04_expected_public_functions e
    where not exists(
      select 1
      from pg_proc p
      join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public'
        and p.oid::regprocedure::text=e.signature
    )
  ),
  0::bigint,
  'PREV-05: every contracted public function still exists'
);

select is(
  (
    select count(*)::bigint
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and has_function_privilege('anon',p.oid,'EXECUTE')
  ),
  0::bigint,
  'PREV-06: anon has zero EXECUTE privilege on every public function'
);

select is(
  (
    select count(*)::bigint
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and has_function_privilege('authenticated',p.oid,'EXECUTE')
      and not exists(
        select 1
        from c04_authenticated_execute_allowlist a
        where a.signature=p.oid::regprocedure::text
      )
  ),
  0::bigint,
  'PREV-05: authenticated EXECUTE surface contains no RPC outside the allowlist'
);

select is(
  (
    select count(*)::bigint
    from c04_authenticated_execute_allowlist a
    where not exists(
      select 1
      from pg_proc p
      join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public'
        and p.oid::regprocedure::text=a.signature
        and has_function_privilege('authenticated',p.oid,'EXECUTE')
    )
  ),
  0::bigint,
  'PREV-05: every approved authenticated RPC remains executable as contracted'
);

select * from finish();
rollback;
