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
  (select count(*)::bigint from public.governance_issues where status = 'OPEN'),
  10::bigint,
  'GI-SAFRA-001..010 remain open until human decision'
);

select * from finish();
rollback;
