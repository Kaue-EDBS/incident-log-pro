begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

select ok(
  (select status='OPEN' or (status='RESOLVED' and resolution_text like 'D-55%')
   from public.governance_issues where issue_key='GI-SAFRA-001'),
  'GI-001 is OPEN, or RESOLVED only by the owner decision D-55'
);

select matches(
  (select description from public.governance_issues where issue_key='GI-SAFRA-001'),
  'NÃO bloqueia START/C08|NAO bloqueia START/C08',
  'GI-001 is explicitly non-blocking for START'
);

select matches(
  (select description from public.governance_issues where issue_key='GI-SAFRA-001'),
  'criticality NULL',
  'GI-001 preserves explicit undefined criticality'
);

select is(
  (select status from public.governance_issues where issue_key='GI-SAFRA-002'),
  'OPEN',
  'GI-002 remains OPEN for future automation threshold'
);

select matches(
  (select description from public.governance_issues where issue_key='GI-SAFRA-002'),
  'START manual',
  'GI-002 defines manual START fallback'
);

select matches(
  (select description from public.governance_issues where issue_key='GI-SAFRA-002'),
  'NOT_CONFIGURED',
  'GI-002 automatic detector is explicitly not configured'
);

select is(
  (select status from public.governance_issues where issue_key='GI-SAFRA-003'),
  'OPEN',
  'GI-003 remains OPEN for official curve-A source'
);

select matches(
  (select description from public.governance_issues where issue_key='GI-SAFRA-003'),
  'START manual',
  'GI-003 defines manual START fallback'
);

select ok(
  (select status='OPEN' or (status='RESOLVED' and resolution_text like 'D-62%')
   from public.governance_issues where issue_key='GI-SAFRA-009'),
  'GI-009 is OPEN, or RESOLVED only by the owner decision D-62'
);

select matches(
  (select description from public.governance_issues where issue_key='GI-SAFRA-009'),
  'SAFRA-01',
  'GI-009 records SAFRA-01 as unambiguous runtime candidate'
);

select matches(
  (select description from public.governance_issues where issue_key='GI-SAFRA-009'),
  'SAFRA-05',
  'GI-009 records SAFRA-05 as unambiguous runtime candidate'
);

select is(
  (select count(*)::bigint
   from public.governance_issues
   where issue_key in ('GI-SAFRA-001','GI-SAFRA-002','GI-SAFRA-003','GI-SAFRA-009')
     and description ilike '%bloqueia C08%'
  ),
  3::bigint,
  'GI-002/003/009 explicitly say they do not block C08; GI-001 uses START/C08 wording'
);

select * from finish();
rollback;
