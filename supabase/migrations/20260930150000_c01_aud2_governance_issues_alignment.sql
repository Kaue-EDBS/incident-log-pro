-- SAFRA-C01-AUD2 — align public.governance_issues with docs/GOVERNANCE_ISSUES.md (D-53).
-- Only the status prefix of the description changes; no issue is resolved and no default is inferred.

begin;

update public.governance_issues
set description = regexp_replace(description, '^WAITING_HUMAN_DECISION\.', 'OPEN — DEFERRED_TO_M01.')
where issue_key = 'GI-SAFRA-004' and description like 'WAITING_HUMAN_DECISION.%';

update public.governance_issues
set description = regexp_replace(description, '^WAITING_HUMAN_DECISION\.', 'OPEN — DEFERRED_TO_M05.')
where issue_key = 'GI-SAFRA-005' and description like 'WAITING_HUMAN_DECISION.%';

update public.governance_issues
set description = regexp_replace(description, '^WAITING_HUMAN_DECISION\.', 'OPEN — DEFERRED_TO_F04_M05.')
where issue_key = 'GI-SAFRA-006' and description like 'WAITING_HUMAN_DECISION.%';

update public.governance_issues
set description = regexp_replace(description, '^WAITING_HUMAN_DECISION\.', 'OPEN — DEFERRED_TO_M10.')
where issue_key = 'GI-SAFRA-007' and description like 'WAITING_HUMAN_DECISION.%';

update public.governance_issues
set description = regexp_replace(description, '^WAITING_HUMAN_DECISION\.', 'OPEN — DEFERRED_TO_F05.')
where issue_key = 'GI-SAFRA-008' and description like 'WAITING_HUMAN_DECISION.%';

insert into public.governance_issues(issue_key, title, description, status)
values (
  'GI-SAFRA-010',
  'Liberação de START por card',
  'OPEN — NON_BLOCKING (D-51). Definir quais dos 11 cards podem ser abertos e por quem. Até decisão, os 11 cenários publicados continuam startáveis por qualquer usuário corporativo autenticado. Nenhum card é bloqueado por inferência. Não bloqueia START/C08.',
  'OPEN'
)
on conflict (issue_key) do nothing;

do $$
begin
  if exists (select 1 from public.governance_issues where description like 'WAITING_HUMAN_DECISION%') then
    raise exception 'C01-AUD2: governance issue still labelled WAITING_HUMAN_DECISION';
  end if;
  if not exists (select 1 from public.governance_issues where issue_key = 'GI-SAFRA-010' and status = 'OPEN') then
    raise exception 'C01-AUD2: GI-SAFRA-010 missing';
  end if;
end;
$$;

commit;
