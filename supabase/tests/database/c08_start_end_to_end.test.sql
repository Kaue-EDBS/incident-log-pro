begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users(
  id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at
)
values(
  '08080808-0000-4000-8000-000000000001'::uuid,
  'c08.start.test@editoradobrasil.com.br',
  '{"provider":"azure"}'::jsonb,
  true,
  false,
  clock_timestamp(),
  clock_timestamp()
);

-- AUD-GERAL A-01: Microsoft identity of the corporate tenant for synthetic azure users.
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text,u.id,jsonb_build_object('sub',u.id::text,'email',u.email,'custom_claims',jsonb_build_object('tid','45ba725f-d260-45c3-ac85-11f433471277')),'azure',clock_timestamp(),clock_timestamp()
from auth.users u
where u.raw_app_meta_data->>'provider'='azure'
  and not exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='azure');

insert into auth.sessions(id,user_id,created_at,updated_at)
values(
  '08080808-0000-4000-8000-000000000002'::uuid,
  '08080808-0000-4000-8000-000000000001'::uuid,
  clock_timestamp(),
  clock_timestamp()
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','08080808-0000-4000-8000-000000000001',
    'email','c08.start.test@editoradobrasil.com.br',
    'session_id','08080808-0000-4000-8000-000000000002',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,
  true
);

select ok(
  not has_table_privilege('authenticated','public.scenarios','SELECT')
  and not has_table_privilege('authenticated','public.treatments','INSERT')
  and not has_table_privilege('authenticated','public.treatment_events','INSERT'),
  'browser keeps no direct Safra table read/write path'
);

select ok(
  not has_function_privilege('anon','public.safra_get_start_catalog()','EXECUTE'),
  'anon cannot call START catalog'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.safra_start_treatment(uuid,uuid,text,uuid[])',
    'EXECUTE'
  ),
  'anon cannot call START command'
);

select ok(
  has_function_privilege('authenticated','public.safra_get_start_catalog()','EXECUTE'),
  'authenticated can call governed START catalog'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.safra_start_treatment(uuid,uuid,text,uuid[])',
    'EXECUTE'
  ),
  'authenticated can call governed START command'
);

select is(
  jsonb_array_length(public.safra_get_start_catalog()),
  11,
  'START catalog exposes the 11 current ACTIVE/PUBLISHED scenarios'
);

select is(
  (
    select count(*)::bigint
    from jsonb_array_elements(public.safra_get_start_catalog()) item
    where item->>'criticality' = 'CRITICAL'
  ),
  11::bigint,
  'START catalog exposes CRITICAL for the 11 scenarios (D-55)'
);

create temporary table c08_start_result as
select public.safra_start_treatment(
  sc.id,
  '08080808-0000-4000-8000-000000000010'::uuid,
  'Impacto sintético do smoke C08',
  array[
    (
      select svia.operational_area_id
      from public.scenario_version_impacted_areas svia
      where svia.scenario_version_id=sc.current_version_id
      order by svia.operational_area_id
      limit 1
    )
  ]::uuid[]
) as payload
from public.scenarios sc
where sc.code='SAFRA-01';

select is(
  (select payload->>'status' from c08_start_result),
  'ACTIVE',
  'START creates ACTIVE treatment'
);

select is(
  (select payload->'scenario'->>'code' from c08_start_result),
  'SAFRA-01',
  'START result identifies selected scenario'
);

select is(
  (
    select count(*)::bigint
    from public.treatments
    where start_idempotency_key='08080808-0000-4000-8000-000000000010'
  ),
  1::bigint,
  'START persists exactly one treatment'
);

select is(
  (
    select count(*)::bigint
    from public.treatment_events e
    join public.treatments t on t.id=e.treatment_id
    where t.start_idempotency_key='08080808-0000-4000-8000-000000000010'
      and e.event_type='TREATMENT_OPENED'
  ),
  1::bigint,
  'START emits exactly one TREATMENT_OPENED event'
);

select is(
  (
    select t.opened_by
    from public.treatments t
    where t.start_idempotency_key='08080808-0000-4000-8000-000000000010'
  ),
  '08080808-0000-4000-8000-000000000001'::uuid,
  'START actor is taken from auth.uid server-side'
);

select ok(
  (
    select t.scenario_version_id=sc.current_version_id
       and t.owner_id_at_start=so.owner_id
       and t.responsible_area_id_at_start=sc.responsible_area_id
    from public.treatments t
    join public.scenarios sc on sc.id=t.scenario_id
    join public.scenario_owners so on so.scenario_id=sc.id and so.valid_to is null
    where t.start_idempotency_key='08080808-0000-4000-8000-000000000010'
  ),
  'START snapshots version, owner and responsible area from server state'
);

select ok(
  (
    select abs(extract(epoch from (t.opened_at-e.occurred_at))) < 1
    from public.treatments t
    join public.treatment_events e
      on e.treatment_id=t.id
     and e.event_type='TREATMENT_OPENED'
    where t.start_idempotency_key='08080808-0000-4000-8000-000000000010'
  ),
  'treatment/event official times are generated together by database clocks'
);

select is(
  (
    select (public.safra_start_treatment(
      sc.id,
      '08080808-0000-4000-8000-000000000010'::uuid,
      'Impacto sintético do smoke C08',
      array[
        (
          select svia.operational_area_id
          from public.scenario_version_impacted_areas svia
          where svia.scenario_version_id=sc.current_version_id
          order by svia.operational_area_id
          limit 1
        )
      ]::uuid[]
    )->>'treatment_id')::uuid
    from public.scenarios sc
    where sc.code='SAFRA-01'
  ),
  (select (payload->>'treatment_id')::uuid from c08_start_result),
  'same idempotency key returns same treatment'
);

select is(
  (
    select count(*)::bigint
    from public.treatments
    where start_idempotency_key='08080808-0000-4000-8000-000000000010'
  ),
  1::bigint,
  'retry does not duplicate treatment'
);

select is(
  (
    select count(*)::bigint
    from public.treatment_events e
    join public.treatments t on t.id=e.treatment_id
    where t.start_idempotency_key='08080808-0000-4000-8000-000000000010'
      and e.event_type='TREATMENT_OPENED'
  ),
  1::bigint,
  'retry does not duplicate TREATMENT_OPENED'
);

select throws_ok(
  $$
    select public.safra_start_treatment(
      (select id from public.scenarios where code='SAFRA-01'),
      '08080808-0000-4000-8000-000000000011'::uuid,
      null,
      '{}'::uuid[]
    );
  $$,
  'P0001',
  'SAFRA_START_ACTIVE_EXISTS',
  'same person cannot START a second ACTIVE treatment of the same scenario (D-57)'
);

select throws_ok(
  $$
    select public.safra_start_treatment(
      (select id from public.scenarios where code='SAFRA-01'),
      '08080808-0000-4000-8000-000000000012'::uuid,
      null,
      array['08080808-0000-4000-8000-000000000099'::uuid]
    );
  $$,
  '22023',
  'SAFRA_INVALID_IMPACTED_AREA',
  'START rejects impacted area outside the published scenario version'
);

insert into public.scenarios(code,name,lifecycle_status,responsible_area_id)
select
  'TEST-C08-DRAFT',
  'Synthetic draft scenario',
  'ACTIVE',
  id
from public.operational_areas
order by code
limit 1;

insert into public.scenario_versions(
  scenario_id,version_no,status,trigger_description,protocol_text,source_reference
)
select
  id,1,'DRAFT','Synthetic trigger','Synthetic protocol','C08 pgTAP'
from public.scenarios
where code='TEST-C08-DRAFT';

select throws_ok(
  $$
    select public.safra_start_treatment(
      (select id from public.scenarios where code='TEST-C08-DRAFT'),
      '08080808-0000-4000-8000-000000000013'::uuid,
      null,
      '{}'::uuid[]
    );
  $$,
  'P0001',
  'SAFRA_SCENARIO_NOT_STARTABLE',
  'DRAFT scenario/version cannot START'
);

update public.scenarios
set lifecycle_status='INACTIVE'
where code='SAFRA-11';

select throws_ok(
  $$
    select public.safra_start_treatment(
      (select id from public.scenarios where code='SAFRA-11'),
      '08080808-0000-4000-8000-000000000014'::uuid,
      null,
      '{}'::uuid[]
    );
  $$,
  'P0001',
  'SAFRA_SCENARIO_NOT_STARTABLE',
  'INACTIVE scenario cannot START'
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','08080808-0000-4000-8000-000000000001',
    'email','outsider@example.com',
    'session_id','08080808-0000-4000-8000-000000000002',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from now()+interval '1 hour')::bigint
  )::text,
  true
);

select throws_ok(
  $$
    select public.safra_start_treatment(
      (select id from public.scenarios where code='SAFRA-02'),
      '08080808-0000-4000-8000-000000000015'::uuid,
      null,
      '{}'::uuid[]
    );
  $$,
  '42501',
  'SAFRA_START_FORBIDDEN',
  'non-corporate identity cannot START'
);

select is(
  pg_get_function_identity_arguments(
    'public.safra_start_treatment(uuid,uuid,text,uuid[])'::regprocedure
  ),
  'p_scenario_id uuid, p_idempotency_key uuid, p_impact_summary text, p_impacted_area_ids uuid[]',
  'START payload exposes no owner/version/criticality/timestamp override'
);

select ok(
  to_regclass('public.scenario_slas') is null,
  'START has no structured SLA configuration (D-75)'
);

select * from finish();
rollback;
