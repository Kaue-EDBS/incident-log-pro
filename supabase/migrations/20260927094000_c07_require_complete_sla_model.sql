-- SAFRA-C07 — contrato estrutural completo de SLA
-- Cada linha em scenario_slas representa um SLA estruturado completo.
-- Não cria SLAs nem infere regras a partir de target_text.

begin;

-- C07 passa a exigir o alvo estruturado completo para qualquer novo SLA.
-- start_event e end_event já eram NOT NULL desde o schema v2.
alter table public.scenario_slas
  alter column target_value set not null,
  alter column target_unit set not null;

comment on column public.scenario_slas.start_event is
  'Evento canônico cuja primeira ocorrência inicia o relógio do SLA. Obrigatório; não pode ser inferido de texto livre.';

comment on column public.scenario_slas.end_event is
  'Evento canônico cuja primeira ocorrência encerra a medição do SLA. Obrigatório; deve ser diferente de start_event.';

comment on column public.scenario_slas.target_value is
  'Quantidade positiva do alvo temporal do SLA. Obrigatória em todo SLA estruturado.';

comment on column public.scenario_slas.target_unit is
  'Unidade do alvo temporal. Obrigatória; valores suportados pelo C07: MINUTE, HOUR e DAY.';

comment on table public.scenario_slas is
  'SLA versionado por scenario_version. Todo registro deve declarar start_event, end_event, target_value e target_unit; target_text permanece apenas como evidência textual de origem.';

commit;
