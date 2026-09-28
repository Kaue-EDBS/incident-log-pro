begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

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
  5::bigint,
  'all five C05 FK support indexes exist'
);

select matches(
  (select indexdef from pg_indexes where schemaname='public' and indexname='idx_governance_issues_resolved_by'),
  '\\(resolved_by\\)',
  'governance_issues.resolved_by has a direct support index'
);

select matches(
  (select indexdef from pg_indexes where schemaname='public' and indexname='idx_scenario_proposal_owner_responses_candidate_owner_id'),
  '\\(candidate_owner_id\\)',
  'proposal candidate_owner_id has a direct support index'
);

select matches(
  (select indexdef from pg_indexes where schemaname='public' and indexname='idx_scenario_version_impacted_areas_operational_area_id'),
  '\\(operational_area_id\\)',
  'scenario version impacted area FK has a direct support index'
);

select matches(
  (select indexdef from pg_indexes where schemaname='public' and indexname='idx_scenario_version_systems_system_id'),
  '\\(system_id\\)',
  'scenario version system FK has a direct support index'
);

select matches(
  (select indexdef from pg_indexes where schemaname='public' and indexname='idx_treatment_impacted_areas_operational_area_id'),
  '\\(operational_area_id\\)',
  'treatment impacted area FK has a direct support index'
);

select ok(
  position(
    'new.updated_at := clock_timestamp()'
    in pg_get_functiondef('private.safra_guard_scenario_version_update()'::regprocedure)
  )=0,
  'scenario version guard no longer owns updated_at'
);

select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid='public.scenario_versions'::regclass
      and tgname='trg_00_scenario_versions_server_clock'
      and not tgisinternal
  ),
  'scenario version server-clock trigger remains installed'
);

select ok(
  not exists(
    select 1 from pg_trigger
    where tgrelid='public.treatments'::regclass
      and tgname='trg_treatments_updated_at'
      and not tgisinternal
  ),
  'duplicate treatment touch trigger is removed'
);

select ok(
  exists(
    select 1 from pg_trigger
    where tgrelid='public.treatments'::regclass
      and tgname='trg_00_treatments_server_clock'
      and not tgisinternal
  ),
  'treatment server-clock trigger remains installed'
);

insert into public.scenario_versions(
  id,scenario_id,version_no,status,protocol_text
)
select
  '05050505-6000-4000-8000-000000000001'::uuid,
  sc.id,
  (select max(version_no)+1000 from public.scenario_versions sv where sv.scenario_id=sc.id),
  'DRAFT',
  'C05 block C pgTAP clock probe'
from public.scenarios sc
where sc.code='SAFRA-01';

select pg_sleep(0.01);

update public.scenario_versions
set protocol_text='C05 block C pgTAP clock probe updated'
where id='05050505-6000-4000-8000-000000000001'::uuid;

select ok(
  (
    select updated_at > created_at
    from public.scenario_versions
    where id='05050505-6000-4000-8000-000000000001'::uuid
  ),
  'scenario version updated_at still advances via server clock only'
);

insert into auth.users(
  id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at
)
values(
  '05050505-6000-4000-8000-000000000002'::uuid,
  'c05.blockc.pgtap@example.invalid',
  '{"provider":"email"}'::jsonb,
  false,false,clock_timestamp(),clock_timestamp()
);

insert into public.treatments(
  id,scenario_id,scenario_version_id,status,opened_by,
  owner_id_at_start,responsible_area_id_at_start,
  impact_summary,start_correlation_id,start_idempotency_key
)
select
  '05050505-6000-4000-8000-000000000010'::uuid,
  sc.id,sc.current_version_id,'ACTIVE',
  '05050505-6000-4000-8000-000000000002'::uuid,
  so.owner_id,sc.responsible_area_id,
  'C05 block C pgTAP treatment clock probe',
  '05050505-6000-4000-8000-000000000011'::uuid,
  'c05-block-c-pgtap-treatment-clock'
from public.scenarios sc
join public.scenario_owners so on so.scenario_id=sc.id and so.valid_to is null
where sc.code='SAFRA-01';

select pg_sleep(0.01);

update public.treatments
set impact_summary='C05 block C pgTAP treatment clock probe updated'
where id='05050505-6000-4000-8000-000000000010'::uuid;

select ok(
  (
    select updated_at > created_at
    from public.treatments
    where id='05050505-6000-4000-8000-000000000010'::uuid
  ),
  'treatment updated_at still advances via server clock only'
);

select * from finish();
rollback;
