begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

insert into auth.users(
  id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at
)
values(
  '02020202-0000-4000-8000-000000000001'::uuid,
  'kaue.pastrello@editoradobrasil.com.br',
  '{"provider":"azure"}'::jsonb,
  true,
  false,
  clock_timestamp(),
  clock_timestamp()
);

insert into auth.sessions(id,user_id,created_at,updated_at)
values(
  '02020202-0000-4000-8000-000000000002'::uuid,
  '02020202-0000-4000-8000-000000000001'::uuid,
  clock_timestamp(),
  clock_timestamp()
);

-- AUTHZ bypass regression: same bound admin sub, but external email and nonexistent session.
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','02020202-0000-4000-8000-000000000001',
    'email','outsider@example.com',
    'session_id','02020202-0000-4000-8000-000000000099',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,
  true
);

select ok(
  not public.safra_is_corporate_user(),
  'external domain plus missing session fails canonical corporate predicate'
);

select is(
  public.get_my_safra_roles(),
  '{}'::text[],
  'invalid corporate session cannot enumerate governed roles'
);

select ok(
  not public.safra_has_role('safra_platform_admin'),
  'invalid corporate session cannot use bound platform-admin role'
);

select is(
  (select count(*)::bigint from public.get_safra_rbac_audit_events(5)),
  0::bigint,
  'invalid corporate session cannot enumerate RBAC audit rows'
);

-- Correct domain, but revoked/missing session still fails.
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','02020202-0000-4000-8000-000000000001',
    'email','kaue.pastrello@editoradobrasil.com.br',
    'session_id','02020202-0000-4000-8000-000000000099',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,
  true
);

select ok(
  not public.safra_is_corporate_user(),
  'corporate email without live auth.sessions row is rejected'
);

select is(
  public.get_my_safra_roles(),
  '{}'::text[],
  'revoked/missing session cannot enumerate roles'
);

-- Valid canonical corporate session retains intended role behavior.
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','02020202-0000-4000-8000-000000000001',
    'email','kaue.pastrello@editoradobrasil.com.br',
    'session_id','02020202-0000-4000-8000-000000000002',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,
  true
);

select ok(
  public.safra_is_corporate_user(),
  'valid corporate live session passes canonical predicate'
);

select ok(
  public.safra_has_role('safra_platform_admin'),
  'valid corporate live session retains platform-admin role'
);

select ok(
  'safra_platform_admin' = any(public.get_my_safra_roles()),
  'valid corporate live session can enumerate its governed roles'
);


select private.safra_log_rbac_event(
  'ACCESS_DENIED',
  'C02-AUD-POSITIVE-REGRESSION',
  'DENIED',
  null,
  null,
  null,
  jsonb_build_object('purpose','positive audit RPC regression')
);

select is(
  (
    select count(*)::bigint
    from public.get_safra_rbac_audit_events(100)
    where action='ACCESS_DENIED'
      and resource='C02-AUD-POSITIVE-REGRESSION'
  ),
  1::bigint,
  'valid corporate platform admin can read governed RBAC audit events'
);


insert into public.scenario_proposals(
  proposed_by,
  proposer_name,
  proposer_email,
  title,
  problem_description,
  safra_impact_description
)
values(
  '02020202-0000-4000-8000-000000000001'::uuid,
  'C02 Threat Test',
  'kaue.pastrello@editoradobrasil.com.br',
  'TEST-C02-PROPOSAL-12TH-CARD',
  'Proposal fixture must remain outside the productive scenario catalog.',
  'Threat-model regression: proposal cannot publish itself as the 12th card.'
);

select is(
  (
    select count(*)::bigint
    from public.scenarios
    where code='TEST-C02-PROPOSAL-12TH-CARD'
       or name='TEST-C02-PROPOSAL-12TH-CARD'
  ),
  0::bigint,
  'scenario proposal cannot create or publish a productive scenario by itself'
);

select is(
  jsonb_array_length(public.safra_get_start_catalog()),
  11,
  'scenario proposal does not become a 12th START catalog card'
);

-- Expired token cannot reuse the role binding.
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','02020202-0000-4000-8000-000000000001',
    'email','kaue.pastrello@editoradobrasil.com.br',
    'session_id','02020202-0000-4000-8000-000000000002',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()-interval '1 minute')::bigint
  )::text,
  true
);

select ok(
  not public.safra_is_corporate_user(),
  'expired token fails canonical corporate predicate'
);

-- Trigger helpers are internal-only and cannot be invoked through browser roles.
select ok(
  not has_function_privilege('anon','public.set_updated_at()','EXECUTE'),
  'anon cannot execute legacy set_updated_at trigger helper'
);

select ok(
  not has_function_privilege('authenticated','public.set_updated_at()','EXECUTE'),
  'authenticated cannot execute legacy set_updated_at trigger helper'
);

select ok(
  not has_function_privilege('anon','public.validate_incident_timestamps()','EXECUTE'),
  'anon cannot execute legacy timestamp validation trigger helper'
);

select ok(
  not has_function_privilege('authenticated','public.validate_incident_timestamps()','EXECUTE'),
  'authenticated cannot execute legacy timestamp validation trigger helper'
);

-- Restore a valid session for START idempotency threat tests.
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','02020202-0000-4000-8000-000000000001',
    'email','kaue.pastrello@editoradobrasil.com.br',
    'session_id','02020202-0000-4000-8000-000000000002',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,
  true
);

select is(
  (
    select public.safra_start_treatment(
      sc.id,
      '02020202-0000-4000-8000-000000000010'::uuid,
      'C02 threat-model idempotency baseline',
      '{}'::uuid[]
    )->>'status'
    from public.scenarios sc
    where sc.code='SAFRA-03'
  ),
  'ACTIVE',
  'baseline START succeeds for idempotency conflict test'
);

select throws_ok(
  $stmt$
    select public.safra_start_treatment(
      (select id from public.scenarios where code='SAFRA-03'),
      '02020202-0000-4000-8000-000000000010'::uuid,
      'different payload with same idempotency key',
      '{}'::uuid[]
    );
  $stmt$,
  '22023',
  'SAFRA_START_IDEMPOTENCY_CONFLICT',
  'same idempotency key with different payload is rejected'
);


update public.treatments
set status='CANCELLED',
    cancelled_by='02020202-0000-4000-8000-000000000001'::uuid,
    cancelled_at=clock_timestamp(),
    cancellation_reason='original auditable cancellation reason'
where start_idempotency_key='02020202-0000-4000-8000-000000000010';

select throws_ok(
  $stmt$
    update public.treatments
    set cancellation_reason='rewritten reason intended to mask history'
    where start_idempotency_key='02020202-0000-4000-8000-000000000010';
  $stmt$,
  'P0001',
  'closed treatment row is immutable; record an append-only correction event instead',
  'CANCEL reason/history cannot be rewritten after treatment becomes terminal'
);

select is(
  (
    select count(*)::bigint
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in ('safra_end_treatment','safra_cancel_treatment')
  ),
  0::bigint,
  'END/CANCEL RPCs remain unexposed until their governed implementation phase'
);

select is(
  (
    select count(*)::bigint
    from information_schema.role_table_grants
    where table_schema='public'
      and grantee='anon'
      and table_name in (
        'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
        'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
        'treatments','treatment_impacted_areas','treatment_impact_measurements',
        'treatment_events','treatment_escalations','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  0::bigint,
  'anon has no direct grants on the 17-table Safra domain surface'
);

select is(
  (
    select count(*)::bigint
    from information_schema.role_table_grants
    where table_schema='public'
      and grantee='authenticated'
      and table_name in (
        'operational_areas','systems','scenarios','scenario_versions','scenario_owners',
        'scenario_version_impacted_areas','scenario_version_systems','scenario_slas',
        'treatments','treatment_impacted_areas','treatment_impact_measurements',
        'treatment_events','treatment_escalations','scenario_proposals',
        'scenario_proposal_owner_responses','notifications_log','governance_issues'
      )
  ),
  0::bigint,
  'authenticated has no direct grants on the 17-table Safra domain surface'
);

select is(
  (
    select count(*)::bigint
    from pg_policies
    where schemaname='public'
      and (coalesce(qual,'')='true' or coalesce(with_check,'')='true')
  ),
  0::bigint,
  'no public policy reintroduces unconditional USING/WITH CHECK true'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.get_safra_rbac_audit_events(integer)',
    'EXECUTE'
  ),
  'anon cannot execute RBAC audit RPC'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.get_safra_rbac_audit_events(integer)',
    'EXECUTE'
  ),
  'authenticated may reach RBAC audit RPC only through its internal corporate/admin checks'
);

select * from finish();
rollback;
