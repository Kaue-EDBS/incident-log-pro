-- C06-AUD2 (01/10/2026) — alinhar os textos das governance issues no banco com
-- docs/GOVERNANCE_ISSUES.md e com as decisões D-56, D-58, D-59, D-60 e D-67.
--
-- Só textos mudam. Nenhum status é alterado:
--   - descrições das issues OPEN (002, 003, 005, 006, 007) passam a citar a decisão vigente;
--   - a resolução da GI-SAFRA-009 passa a citar a escada revista da D-67 (2h e 4h),
--     que substituiu a escada 2h/3h/4h da D-62;
--   - a função de resolução da C01-AUD2 passa a gravar o texto novo da GI-009, para que
--     um banco reconstruído do zero chegue ao mesmo texto do PRIMARY.
begin;

update public.governance_issues gi
set description = r.description
from (values
  ('GI-SAFRA-002', 'OPEN — DEFERRED_TO_PRODUCT_V2 (D-56). A detecção automática dos cenários SAFRA-02, SAFRA-04, SAFRA-10 e SAFRA-11 fica para a V2/V3 do produto. Os limites X h (SAFRA-02), X min (SAFRA-04), de lead time/fila (SAFRA-10) e de capacidade (SAFRA-11) seguem sem valor e nenhum pode ser inferido. Até lá, START manual (D-45) e detector automático NOT_CONFIGURED. NÃO bloqueia C08; bloqueia só a automação do gatilho.'),
  ('GI-SAFRA-003', 'OPEN — DEFERRED_TO_PRODUCT_V2 (D-56). O mínimo de saldo de SKU curva A do SAFRA-09 só serve à detecção automática, que fica para a V2/V3 do produto. Até lá, START manual (D-46) e nenhuma ruptura é classificada automaticamente nem recebe mínimo inventado. NÃO bloqueia C08; bloqueia só a automação objetiva da ruptura.'),
  ('GI-SAFRA-005', 'OPEN — DECIDED (D-58), implementação na SAFRA-M05. Avisos por e-mail (Microsoft 365) e Teams: o dono do card recebe pelos dois; o Jair recebe só por e-mail, de todos os protocolos; platform admins não recebem, salvo se forem donos do card. O uso do Teams está em revisão na GI-SAFRA-011; até a decisão, a M05 considera apenas e-mail.'),
  ('GI-SAFRA-006', 'OPEN — DECIDED (D-59), implementação na SAFRA-F04/M05. A Safra corrente é aberta e encerrada manualmente no sistema, por marcação do Kaue, com horário do servidor e autor registrado. A Safra corrente começou em 01/10/2026 (D-69); o encerramento exige confirmação reforçada e pode ser desfeito em 7 dias (D-70).'),
  ('GI-SAFRA-007', 'OPEN — DECIDED (D-60), implementação na SAFRA-M10. O conteúdo do cenário novo é escrito por quem propôs; o Jair aprova; um platform admin publica; o card nasce CRITICAL. Quem propõe não aprova nem publica a própria proposta (D-68). Nenhuma proposta é publicada por inferência.')
) as r(issue_key, description)
where gi.issue_key = r.issue_key
  and gi.status = 'OPEN';

create or replace function private.safra_c01_aud2_resolve_governance_issues(p_actor uuid)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_count integer;
begin
  if p_actor is null then
    raise exception 'C01-AUD2: resolving actor is required';
  end if;

  update public.governance_issues gi
  set status = 'RESOLVED',
      resolved_by = p_actor,
      resolution_text = r.resolution_text
  from (values
    ('GI-SAFRA-001', 'D-55 (30/09/2026): os 11 cenários são CRITICAL; aviso de abertura ao dono do card, diretoria fora por ora. Aplicado na scenario_version v2 (migration 20261001120000).'),
    ('GI-SAFRA-004', 'D-57 (30/09/2026): no máximo uma tratativa ACTIVE por pessoa e por cenário. Aplicado por índice único e verificação no START (migration 20261001120000).'),
    ('GI-SAFRA-008', 'D-61 (30/09/2026): dia, horário e ritual da governança semanal ficam fora do Painel; a F05 mantém tela de resumo e registro de ações.'),
    ('GI-SAFRA-009', 'D-62 (01/10/2026): nenhum card terá cronômetro de SLA. Escada de avisos revista pela D-67: aos 2h e aos 4h da abertura, enquanto o solicitante não fechar a parte dele, aviso ao dono do card e pergunta "foi resolvido?" ao solicitante; 24h por dia; implementação na M05/F01.'),
    ('GI-SAFRA-010', 'D-63 (01/10/2026): os 11 cenários publicados seguem liberados para qualquer usuário corporativo autenticado; sem restrição por card.')
  ) as r(issue_key, resolution_text)
  where gi.issue_key = r.issue_key
    and gi.status = 'OPEN';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function private.safra_c01_aud2_resolve_governance_issues(uuid) from public, anon, authenticated;

update public.governance_issues
set resolution_text = 'D-62 (01/10/2026): nenhum card terá cronômetro de SLA. Escada de avisos revista pela D-67: aos 2h e aos 4h da abertura, enquanto o solicitante não fechar a parte dele, aviso ao dono do card e pergunta "foi resolvido?" ao solicitante; 24h por dia; implementação na M05/F01.'
where issue_key = 'GI-SAFRA-009'
  and status = 'RESOLVED';

do $$
begin
  if exists (select 1 from public.governance_issues
             where issue_key in ('GI-SAFRA-002','GI-SAFRA-003','GI-SAFRA-005','GI-SAFRA-006','GI-SAFRA-007')
               and status = 'OPEN'
               and description not like 'OPEN — %') then
    raise exception 'C06-AUD2: open governance issue text not aligned';
  end if;
  if exists (select 1 from public.governance_issues
             where issue_key = 'GI-SAFRA-009' and status = 'RESOLVED'
               and resolution_text like '%2h/3h/4h%') then
    raise exception 'C06-AUD2: GI-SAFRA-009 still cites the superseded 2h/3h/4h ladder';
  end if;
end;
$$;

commit;
