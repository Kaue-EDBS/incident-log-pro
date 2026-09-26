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
