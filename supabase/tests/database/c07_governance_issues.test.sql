begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

select is(
  (select count(*)::bigint
   from public.governance_issues
   where issue_key in (
     'GI-SAFRA-001','GI-SAFRA-002','GI-SAFRA-003','GI-SAFRA-004','GI-SAFRA-005',
     'GI-SAFRA-006','GI-SAFRA-007','GI-SAFRA-008','GI-SAFRA-009'
   )),
  9::bigint,
  'GI-SAFRA-001..009 are persisted'
);

select is(
  (select count(*)::bigint
   from public.governance_issues
   where issue_key in (
     'GI-SAFRA-001','GI-SAFRA-002','GI-SAFRA-003','GI-SAFRA-004','GI-SAFRA-005',
     'GI-SAFRA-006','GI-SAFRA-007','GI-SAFRA-008','GI-SAFRA-009'
   )
   and ((status='OPEN' and resolved_at is null and resolved_by is null and resolution_text is null)
     or (status='RESOLVED' and resolved_by is not null and resolution_text ~ '^D-[0-9]+ '))),
  9::bigint,
  'each canonical governance issue is OPEN, or RESOLVED only with a cited human decision (D-xx)'
);

select ok(
  exists(select 1 from public.governance_issues
         where issue_key='GI-SAFRA-002'
           and description like '%X h%'
           and description like '%X min%'
           and description like '%SAFRA-10%'
           and description like '%SAFRA-11%'),
  'GI-SAFRA-002 records X h, X min, picking limit and capacity threshold'
);

select ok(
  exists(select 1 from public.governance_issues
         where issue_key='GI-SAFRA-003'
           and description ilike '%curva A%'),
  'GI-SAFRA-003 records curve-A minimum source'
);

select ok(
  exists(select 1 from public.governance_issues
         where issue_key='GI-SAFRA-009'
           and description ilike '%TREATMENT_OPENED%'
           and description ilike '%TREATMENT_RESOLVED%'
           and description ilike '%SAFRA-01%'
           and description ilike '%SAFRA-05%'),
  'GI-SAFRA-009 records approved SLA mapping policy and unambiguous candidates'
);

select is(
  (select count(*)::bigint from public.scenario_slas),
  0::bigint,
  'governance issue registration does not infer structured SLA rows'
);

select is(
  (select count(*)::bigint
   from public.scenario_versions sv
   join public.scenarios sc on sc.id=sv.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and sv.criticality is null),
  11::bigint,
  'governance issue registration does not infer scenario criticality'
);

select * from finish();
rollback;
