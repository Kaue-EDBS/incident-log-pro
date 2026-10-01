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
           and description like '%D-51%'
           and ((status = 'OPEN' and resolved_at is null)
             or (status = 'RESOLVED' and resolution_text like 'D-63%'))),
  'GI-SAFRA-010 is persisted; OPEN, or RESOLVED only by the owner decision D-63'
);

select is(
  (select count(*)::bigint from public.governance_issues
   where (status = 'OPEN' or resolution_text ~ '^D-[0-9]+ ')
     and issue_key in ('GI-SAFRA-001','GI-SAFRA-002','GI-SAFRA-003','GI-SAFRA-004','GI-SAFRA-005',
                       'GI-SAFRA-006','GI-SAFRA-007','GI-SAFRA-008','GI-SAFRA-009','GI-SAFRA-010')),
  10::bigint,
  'GI-SAFRA-001..010 are OPEN or resolved only by a cited human decision'
);

select * from finish();
rollback;
