begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

-- D-55: version 2 CRITICAL for the 11 scenarios; version 1 preserved as RETIRED.
select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id = sc.current_version_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and sv.version_no = 2 and sv.status = 'PUBLISHED' and sv.criticality = 'CRITICAL'),
  11::bigint,
  'D-55: the 11 scenarios point to a published CRITICAL version 2'
);

select is(
  (select count(*)::bigint
   from public.scenario_versions sv
   join public.scenarios sc on sc.id = sv.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and sv.version_no = 1 and sv.status = 'RETIRED' and sv.criticality is null
     and sv.retired_at is not null),
  11::bigint,
  'D-55: version 1 is preserved as RETIRED history with its original null criticality'
);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions v2 on v2.id = sc.current_version_id
   join public.scenario_versions v1 on v1.scenario_id = sc.id and v1.version_no = 1
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and v2.trigger_description is not distinct from v1.trigger_description
     and v2.detection_description is not distinct from v1.detection_description
     and v2.protocol_text is not distinct from v1.protocol_text
     and v2.expected_impact_summary is not distinct from v1.expected_impact_summary
     and v2.source_reference is not distinct from v1.source_reference),
  11::bigint,
  'D-55: version 2 content equals version 1 except criticality'
);

select is(
  (select count(*)::bigint from (
     select sc.id
     from public.scenarios sc
     join public.scenario_versions v1 on v1.scenario_id = sc.id and v1.version_no = 1
     where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
       and (select array_agg(operational_area_id order by operational_area_id)
            from public.scenario_version_impacted_areas where scenario_version_id = v1.id)
           is not distinct from
           (select array_agg(operational_area_id order by operational_area_id)
            from public.scenario_version_impacted_areas where scenario_version_id = sc.current_version_id)
       and (select array_agg(system_id::text || coalesce(context,'') order by system_id)
            from public.scenario_version_systems where scenario_version_id = v1.id)
           is not distinct from
           (select array_agg(system_id::text || coalesce(context,'') order by system_id)
            from public.scenario_version_systems where scenario_version_id = sc.current_version_id)
  ) q),
  11::bigint,
  'D-55: impacted areas and systems are copied to version 2'
);

select ok(
  to_regclass('public.scenario_slas') is null,
  'D-62/D-75: no structured SLA clock exists (engine retired)'
);

-- D-57: one ACTIVE treatment per person and scenario.
select ok(
  exists(select 1 from pg_indexes
         where schemaname = 'public'
           and indexname = 'treatments_one_active_per_person_scenario'
           and indexdef ilike '%unique%'
           and indexdef ilike '%(scenario_id, opened_by)%'
           and indexdef ilike '%ACTIVE%'),
  'D-57: unique ACTIVE index covers (scenario_id, opened_by)'
);

insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('01a20000-0000-4000-8000-000000000001','c01aud2.a@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp()),
  ('01a20000-0000-4000-8000-000000000002','c01aud2.b@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());

-- AUD-GERAL A-01: Microsoft identity of the corporate tenant for synthetic azure users.
insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text,u.id,jsonb_build_object('sub',u.id::text,'email',u.email,'custom_claims',jsonb_build_object('tid','45ba725f-d260-45c3-ac85-11f433471277')),'azure',clock_timestamp(),clock_timestamp()
from auth.users u
where u.raw_app_meta_data->>'provider'='azure'
  and not exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='azure');

insert into auth.sessions(id,user_id,created_at,updated_at)
values
  ('01a20000-0000-4000-8000-000000000011','01a20000-0000-4000-8000-000000000001',clock_timestamp(),clock_timestamp()),
  ('01a20000-0000-4000-8000-000000000012','01a20000-0000-4000-8000-000000000002',clock_timestamp(),clock_timestamp());

select set_config('request.jwt.claims', json_build_object(
  'sub','01a20000-0000-4000-8000-000000000001','email','c01aud2.a@editoradobrasil.com.br',
  'session_id','01a20000-0000-4000-8000-000000000011','is_anonymous',false,
  'app_metadata',json_build_object('provider','azure'),
  'exp',extract(epoch from now()+interval '1 hour')::bigint)::text, true);

select is(
  (select count(*)::bigint
   from jsonb_array_elements(public.safra_get_start_catalog()) item
   where item->>'criticality' = 'CRITICAL'),
  11::bigint,
  'D-55: START catalog shows the 11 scenarios as CRITICAL'
);

select is(
  public.safra_start_treatment(
    (select id from public.scenarios where code='SAFRA-02'),
    '01a20000-0000-4000-8000-000000000101'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[])->>'status',
  'ACTIVE',
  'D-57: first START by person A succeeds'
);

select is(
  public.safra_start_treatment(
    (select id from public.scenarios where code='SAFRA-02'),
    '01a20000-0000-4000-8000-000000000101'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[])->>'idempotent_replay',
  'true',
  'D-57: retry with the same key is an idempotent replay, not a second opening'
);

select throws_ok(
  $$ select public.safra_start_treatment(
       (select id from public.scenarios where code='SAFRA-02'),
       '01a20000-0000-4000-8000-000000000102'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[]) $$,
  'P0001',
  'SAFRA_START_ACTIVE_EXISTS',
  'D-57: person A cannot open a second ACTIVE treatment of the same scenario'
);

select is(
  public.safra_start_treatment(
    (select id from public.scenarios where code='SAFRA-03'),
    '01a20000-0000-4000-8000-000000000103'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[])->>'status',
  'ACTIVE',
  'D-57: person A may hold ACTIVE treatments in different scenarios'
);

select set_config('request.jwt.claims', json_build_object(
  'sub','01a20000-0000-4000-8000-000000000002','email','c01aud2.b@editoradobrasil.com.br',
  'session_id','01a20000-0000-4000-8000-000000000012','is_anonymous',false,
  'app_metadata',json_build_object('provider','azure'),
  'exp',extract(epoch from now()+interval '1 hour')::bigint)::text, true);

select is(
  public.safra_start_treatment(
    (select id from public.scenarios where code='SAFRA-02'),
    '01a20000-0000-4000-8000-000000000201'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[])->>'status',
  'ACTIVE',
  'D-57: person B may open the same scenario while A has one ACTIVE'
);

-- Closing the first treatment frees person A for a new one.
update public.treatments
set status = 'CANCELLED',
    cancelled_by = '01a20000-0000-4000-8000-000000000001',
    cancelled_at = clock_timestamp(),
    cancellation_reason = 'C01-AUD2 pgTAP: close to free the lock'
where start_idempotency_key = '01a20000-0000-4000-8000-000000000101';

select set_config('request.jwt.claims', json_build_object(
  'sub','01a20000-0000-4000-8000-000000000001','email','c01aud2.a@editoradobrasil.com.br',
  'session_id','01a20000-0000-4000-8000-000000000011','is_anonymous',false,
  'app_metadata',json_build_object('provider','azure'),
  'exp',extract(epoch from now()+interval '1 hour')::bigint)::text, true);

select is(
  public.safra_start_treatment(
    (select id from public.scenarios where code='SAFRA-02'),
    '01a20000-0000-4000-8000-000000000104'::uuid, 'Resumo de teste: pedidos parados no fluxo', '{}'::uuid[])->>'status',
  'ACTIVE',
  'D-57: after closing, person A can open the same scenario again'
);

-- Governance resolution logic (applied in PRIMARY only when the owner exists in Auth).
select is(
  (select private.safra_c01_aud2_resolve_governance_issues('01a20000-0000-4000-8000-000000000001'::uuid)
   + (select count(*)::int from public.governance_issues
      where status = 'OPEN'
        and issue_key in ('GI-SAFRA-002','GI-SAFRA-003','GI-SAFRA-005','GI-SAFRA-006','GI-SAFRA-007'))),
  10,
  'GI-001/004/008/009/010 resolve; GI-002/003/005/006/007 stay OPEN'
);

select * from finish();
rollback;
