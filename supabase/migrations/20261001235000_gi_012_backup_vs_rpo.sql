-- GI-SAFRA-012 (01/10/2026) — espelha docs/GOVERNANCE_ISSUES.md (D-53).
-- A auditoria somente leitura do lado do Lovable (L-01) mostrou backup diário, sem
-- restauração ponto a ponto (PITR), o que não atende a meta D-23 (RPO 5 min / RTO 30 min).
-- Decisão do owner fica para o SAFRA-C09; nenhum valor é assumido.
begin;

insert into public.governance_issues(issue_key, title, description, status)
values (
  'GI-SAFRA-012',
  'Backup diário x meta de RPO 5 min / RTO 30 min',
  'OPEN — DEFERRED_TO_C09. O Lovable Cloud informou backup diário, sem restauração ponto a ponto (PITR) no plano atual. A D-23 promete perder no máximo 5 minutos de dados (RPO) e voltar em 30 minutos (RTO); com backup diário a perda pode chegar a 24 horas. Decidir no C09: melhorar o plano (PITR) ou rever a meta da D-23. Não bloqueia o C08.',
  'OPEN'
)
on conflict (issue_key) do nothing;

commit;
