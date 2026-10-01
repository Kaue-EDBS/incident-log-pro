begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

select is(
  (select count(*)::bigint from public.governance_issues
   where description like 'WAITING_HUMAN_DECISION%'),
  0::bigint,
  'no governance issue is labelled WAITING_HUMAN_DECISION (D-53 vocabulary)'
);

select ok(
  exists(select 1 from public.governance_issues
         where issue_key = 'GI-SAFRA-010'
           and status = 'OPEN'
           and resolved_at is null
           and description like '%D-51%'),
  'GI-SAFRA-010 is persisted as OPEN and non-blocking'
);

select is(
  (select count(*)::bigint from public.governance_issues
   where status = 'OPEN'
     and issue_key in ('GI-SAFRA-001','GI-SAFRA-002','GI-SAFRA-003','GI-SAFRA-004','GI-SAFRA-005',
                       'GI-SAFRA-006','GI-SAFRA-007','GI-SAFRA-008','GI-SAFRA-009','GI-SAFRA-010')),
  10::bigint,
  'GI-SAFRA-001..010 remain open until human decision'
);

select * from finish();
rollback;
