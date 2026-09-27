# C07 — Engine de SLA

## Objetivo

Calcular estado de SLA a partir de eventos e timestamps oficiais sem inferir regra de negócio.

## Estados

- `ON_TRACK`
- `BREACHED`
- `COMPLETED_ON_TIME`
- `COMPLETED_LATE`
- `NOT_MEASURABLE`
- `NOT_APPLICABLE` somente por regra explícita

## Precedência de avaliação

1. regra explícita de não aplicabilidade;
2. presença do evento inicial;
3. presença do alvo estruturado;
4. consistência temporal;
5. CANCEL;
6. END;
7. relógio corrente versus deadline.

## Regra de deadline

- exatamente no deadline ainda é on-time;
- breach começa somente após o deadline;
- `breached_at` é o próprio deadline quando o prazo é ultrapassado.

## CANCEL

- CANCEL não equivale a SLA cumprido;
- se ocorrer antes do breach e sem end_event, resultado é `NOT_MEASURABLE`;
- se ocorrer depois do deadline, o breach permanece registrado.

## Fonte de tempo

- timestamps server-side;
- `timestamptz`;
- nenhuma duração enviada pelo client é fonte de verdade.

## Alvo estruturado

Unidades suportadas no núcleo:
- MINUTE;
- HOUR;
- DAY.

Valor deve ser maior que zero.

## SLAs dos 11 cenários

O texto de SLA da Matriz v3 continua preservado como fonte canônica, mas não foi convertido automaticamente em `scenario_slas`.

Motivo:
- start_event/end_event nem sempre estão formalmente definidos;
- alguns thresholds continuam em WAITING_HUMAN_DECISION;
- versões v1 já estão PUBLISHED e não podem ser reescritas.

Quando uma regra for homologada, ela nasce em nova `scenario_version`.

## Limites desta fase

C07 implementa o motor e suas bordas.

Não antecipa:
- START funcional;
- END/CANCEL funcional;
- persistência automática de evento SLA_BREACHED;
- UI runtime do cronômetro;
- notificações;
- thresholds ainda não decididos.

Esses itens pertencem às fases C08/M02/M04/M05/F01/F02 conforme roadmap.


## Contrato estrutural obrigatório do SLA

A partir de 27/09/2026, todo registro em `public.scenario_slas` deve possuir obrigatoriamente:

```text
start_event
end_event
target_value
target_unit
```

Sem qualquer um dos quatro campos, o SLA estruturado não pode existir.

### Semântica

- `start_event`: evento canônico cuja primeira ocorrência inicia o relógio;
- `end_event`: evento canônico cuja primeira ocorrência encerra a medição;
- `target_value`: quantidade positiva do alvo temporal;
- `target_unit`: unidade do alvo, limitada no C07 a `MINUTE`, `HOUR` ou `DAY`.

### Invariantes

- `start_event` e `end_event` são NOT NULL e não podem ser vazios;
- `start_event <> end_event`;
- `target_value` é NOT NULL e maior que zero;
- `target_unit` é NOT NULL e pertence ao conjunto suportado;
- `target_text` permanece como evidência textual/origem, mas não substitui o modelo estruturado;
- nenhum SLA é criado a partir de interpretação automática de texto.

### Implementação

Migration:
`supabase/migrations/20260927094000_c07_require_complete_sla_model.sql`

Teste:
`supabase/tests/database/c07_sla_model_contract.test.sql`

CI:
- App Smoke Run 90 = SUCCESS;
- Database Disposable Run 128 = SUCCESS;
- rebuild = PASS;
- pgTAP = PASS;
- rollback latest = PASS;
- lint = PASS.

PRIMARY:
- quatro campos = NOT NULL;
- RLS = ENABLED;
- constraints de valor/unidade/eventos = ativas;
- `scenario_slas` = 0 registros;
- migration `20260927094000` rastreada.

```text
C07_SLA_MODEL = PASS
STRUCTURED_SLA_ROWS_INFERRED = 0
```


## Regra aprovada — duração por timestamps

A duração de SLA não é recebida pronta do client e não é persistida como fonte paralela.

```text
closed_duration = end_timestamp - start_timestamp
open_duration = server_as_of - start_timestamp
canonical_duration_unit = seconds
```

Regras:
- timestamps oficiais são a única fonte de verdade;
- duração negativa é inválida;
- END anterior ao START resulta em `NOT_MEASURABLE`;
- a UI pode formatar segundos em minutos/horas/dias sem alterar a medida canônica.

Estado: **APPROVED — 27/09/2026**.


## Regra aprovada — timezone técnico e timezone de analytics

O sistema separa **instante técnico** de **calendário de negócio**.

### Instante técnico

- banco em `UTC`;
- armazenamento em `timestamptz`;
- duração calculada entre instantes absolutos;
- nenhuma duração depende de timezone visual.

### Calendário de analytics

Para dashboards e filtros por dia/hora:

```text
ANALYTICS_BUSINESS_TIMEZONE = America/Sao_Paulo
```

O timestamp UTC deve ser convertido para `America/Sao_Paulo` **antes** de:
- obter a data;
- agrupar por hora;
- definir início/fim de Hoje;
- definir início do mês;
- interpretar intervalo customizado informado como data local.

Exemplo crítico:

```text
2026-09-27 22:30 America/Sao_Paulo
= 2026-09-28 01:30 UTC

bucket UTC       -> 28/09  (incorreto para analytics de negócio)
bucket Sao Paulo -> 27/09  (correto)
```

### Frontend

`src/lib/metrics.ts` possui timezone explícito e não depende mais do timezone do computador.

`datetime-local` é interpretado como horário de São Paulo e convertido a UTC antes da persistência.

### Smoke permanente

- `supabase/tests/database/c07_timezone_analytics_smoke.test.sql`;
- `.github/scripts/test-c07-analytics-timezone.ts`;
- CI roda o teste de frontend com `TZ=UTC` e `TZ=Asia/Tokyo`.

Evidência final:
- App Smoke Run 96 = SUCCESS;
- Database Disposable Run 134 = SUCCESS.

Estado: **APPROVED — 27/09/2026**.


## Regra aprovada — relógio não-negativo e semântica de CANCEL

### Relógio

A engine nunca expõe contador negativo.

```text
remaining_seconds = max(0, deadline - effective_time)
elapsed_seconds < 0 => inválido / NOT_MEASURABLE
```

Depois do breach, `remaining_seconds` permanece em zero e o estado comunica a violação.

### CANCEL

`CANCEL` não é sinônimo de cumprimento do SLA.

Regras:
- CANCEL antes do prazo => `NOT_MEASURABLE`;
- CANCEL exatamente no prazo => `NOT_MEASURABLE`;
- CANCEL depois do prazo => `BREACHED`;
- nenhum caminho de CANCEL pode retornar `COMPLETED_ON_TIME` ou `COMPLETED_LATE`;
- END e CANCEL simultâneos => `CONFLICTING_TERMINAL_EVENTS`.

Somente o `end_event` real pode produzir estado `COMPLETED_*`.

Evidência:
- `supabase/tests/database/c07_clock_cancel_contract.test.sql`;
- Database Disposable Run 136 = SUCCESS;
- PRIMARY smoke = PASS.

Estado: **APPROVED — 27/09/2026**.


## Regra aprovada — END somente em TREATMENT_RESOLVED

Um SLA configurado só pode alcançar estado `COMPLETED_ON_TIME` ou `COMPLETED_LATE` quando:

```text
end_event = TREATMENT_RESOLVED
```

Qualquer outro valor de `end_event` é inválido para fechamento do SLA e resulta em:

```text
sla_state = NOT_MEASURABLE
evaluation_reason = END_EVENT_NOT_TREATMENT_RESOLVED
```

### Defesa em profundidade

1. O schema impede novos SLAs estruturados com outro `end_event`.
2. A engine configurada revalida `end_event` antes de chamar o avaliador temporal.
3. A função de estado por tratamento usa obrigatoriamente essa engine configurada.

Assim, mesmo uma escrita privilegiada fora do fluxo esperado não transforma um evento intermediário em sucesso de SLA.

### Evidência

Migration:
`supabase/migrations/20260927104000_c07_resolved_end_only.sql`

Teste:
`supabase/tests/database/c07_resolved_end_only.test.sql`

CI:
- App Smoke Run 101 = SUCCESS;
- Database Disposable Run 139 = SUCCESS;
- 11/11 testes da regra = PASS;
- rebuild/rollback/lint = PASS.

Estado: **APPROVED — 27/09/2026**.
