-- PRE-C08 — remover bloqueios falsos de START sem inventar dado de negócio
-- GI-001/002/003/009 permanecem auditáveis. O que muda é o impacto no MVP/C08.
-- Nenhum threshold, criticidade, fonte curva A ou SLA é inferido.

begin;

update public.governance_issues
set description = 'OPEN. D-44 aprovado em 27/09/2026. Os 11 cenários v1 permanecem com criticality NULL, significando criticidade não definida. A ausência de criticidade NÃO bloqueia START/C08, não pode ser convertida em HIGH/MODERATE e não dispara comunicação/escalonamento dependente de criticidade. A pergunta nominal sobre quais quatro cenários são CRITICAL continua aberta para enriquecimento futuro e, quando decidida, exige nova scenario_version; nenhuma versão PUBLISHED será reescrita.'
where issue_key='GI-SAFRA-001';

update public.governance_issues
set description = 'OPEN / AUTOMATION_DEFERRED. D-45 aprovado em 27/09/2026. SAFRA-02, SAFRA-04, SAFRA-10 e SAFRA-11 continuam elegíveis a START manual no MVP. Enquanto seus thresholds quantitativos não existirem em fonte aprovada, o detector automático correspondente é NOT_CONFIGURED e nenhum X h, X min, limite de fila ou capacidade pode ser inferido. A lacuna NÃO bloqueia C08; bloqueia apenas automação do gatilho.'
where issue_key='GI-SAFRA-002';

update public.governance_issues
set description = 'OPEN / AUTOMATION_DEFERRED. D-46 aprovado em 27/09/2026. SAFRA-09 continua elegível a START manual. Enquanto não existir fonte/regra oficial do saldo mínimo de SKU curva A, o Painel não classifica ruptura automaticamente e não inventa mínimo. A lacuna NÃO bloqueia C08; bloqueia somente automação objetiva do gatilho de ruptura.'
where issue_key='GI-SAFRA-003';

update public.governance_issues
set description = 'OPEN / MAPPING_POLICY_RESOLVED_FOR_C08. D-47 aprovado em 27/09/2026. SLA textual só é elegível a scenario_slas quando a cláusula descreve explicitamente prazo da tratativa, possui valor/unidade numéricos e pode usar TREATMENT_OPENED -> TREATMENT_RESOLVED sem criar evento por inferência. Pela Matriz v3, apenas SAFRA-01 (tratativa <=48h) e SAFRA-05 (tratativa <=4h) são candidatos inequívocos. Detecção/trigger, milestones intermediários, janelas no dia/no turno e pós-mortem não viram SLA runtime. As versões v1 PUBLISHED não são reescritas; futura materialização exige nova scenario_version. A issue NÃO bloqueia C08.'
where issue_key='GI-SAFRA-009';

commit;
