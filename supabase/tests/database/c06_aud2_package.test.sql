begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- C06-AUD2: the 11 published scenarios keep the Matrix v3 source and the owner decision for criticality.
select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id = sc.current_version_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and sv.status = 'PUBLISHED'
     and sv.criticality = 'CRITICAL'
     and (sv.source_reference::jsonb ->> 'source_sha256') = 'b0cca8cce835dbdc65ab0c30212fd89480d2cf51e9fb62d215ad1bde0963ead6'),
  11::bigint,
  'C06-AUD2: 11 current versions keep the approved Matrix v3 hash and D-55 criticality'
);

select is(
  (select count(*)::bigint from public.scenarios),
  11::bigint,
  'C06-AUD2: exactly the 11 Matrix v3 scenarios exist'
);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id = sc.current_version_id
   where sc.name = (sv.source_reference::jsonb ->> 'name')),
  11::bigint,
  'C06-AUD2 (D-74): scenario names are the literal Matrix v3 names'
);

select is(
  (select count(*)::bigint from public.scenarios where code !~ '^SAFRA-(0[1-9]|1[01])$'),
  0::bigint,
  'C06-AUD2: no scenario outside the Matrix v3 set (proposals are never published by inference)'
);

-- Governance issue texts aligned with the current decisions (statuses untouched).
select is(
  (select count(*)::bigint from public.governance_issues
   where issue_key = 'GI-SAFRA-002' and status = 'OPEN' and description like '%D-56%'
     and description like '%X h%' and description like '%X min%' and description like '%NOT_CONFIGURED%'),
  1::bigint,
  'GI-SAFRA-002 cites D-56 and preserves the open thresholds'
);

select is(
  (select count(*)::bigint from public.governance_issues
   where issue_key = 'GI-SAFRA-003' and status = 'OPEN' and description like '%D-56%' and description ilike '%curva A%'),
  1::bigint,
  'GI-SAFRA-003 cites D-56 and preserves the curve-A gap'
);

select is(
  (select count(*)::bigint from public.governance_issues
   where status = 'OPEN'
     and ((issue_key = 'GI-SAFRA-005' and description like '%D-58%' and description like '%GI-SAFRA-011%')
       or (issue_key = 'GI-SAFRA-006' and description like '%D-59%' and description like '%D-69%')
       or (issue_key = 'GI-SAFRA-007' and description like '%D-60%' and description like '%D-68%'))),
  3::bigint,
  'GI-SAFRA-005/006/007 cite D-58, D-59/D-69 and D-60/D-68'
);

-- The resolution routine now writes the D-67 ladder for GI-SAFRA-009.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('06a20000-0000-4000-8000-000000000001','c06aud2.actor@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());

select ok(
  private.safra_c01_aud2_resolve_governance_issues('06a20000-0000-4000-8000-000000000001'::uuid) >= 0,
  'C01-AUD2 resolution routine still runs'
);

select is(
  (select count(*)::bigint from public.governance_issues
   where issue_key = 'GI-SAFRA-009' and status = 'RESOLVED'
     and resolution_text like '%D-67%' and resolution_text not like '%3h%'),
  1::bigint,
  'GI-SAFRA-009 resolution cites the D-67 ladder (2h and 4h) without the retired 3h step'
);

select is(
  (select count(*)::bigint from public.governance_issues
   where status = 'OPEN'
     and issue_key in ('GI-SAFRA-002','GI-SAFRA-003','GI-SAFRA-005','GI-SAFRA-006','GI-SAFRA-007','GI-SAFRA-011')),
  6::bigint,
  'the six undecided or not-yet-implemented issues stay OPEN'
);

select * from finish();
rollback;
