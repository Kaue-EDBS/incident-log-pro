# C07 — Regras de tempo

> Substitui o antigo `C07_SLA_ENGINE.md` (guardado em `docs/historico/`). A engine de SLA foi aposentada em 01/10/2026 (D-75), porque nenhum card usa SLA (D-62).

## O que são

Cálculos que respondem perguntas sobre tempo **a partir dos horários gravados pelo servidor**, sem guardar duração em lugar nenhum:

| Pergunta | Função | Decisão |
|---|---|---|
| Quais avisos da escada já venceram e para quem? | `private.safra_reminder_steps(abertura, parte_solicitante, parte_dono, cancelamento, agora)` | D-76 |
| Quanto tempo levou cada parte e o protocolo todo? | `private.safra_close_times(abertura, parte_solicitante, parte_dono, cancelamento)` | D-77 |
| Em que dia do relatório cai este horário? | `private.safra_local_day(horário)` | Regra 2 (fuso `America/Sao_Paulo`) |

As funções recebem os horários como parâmetro. As colunas com o horário de cada parte fechada chegam na F01, que só liga essas colunas aos cálculos; a M05 usa a escada para enviar os avisos.

## Regras

1. **Duração nunca é fonte.** Nenhuma tabela guarda minutos, segundos ou intervalo (teste no CI).
2. **Horários só do servidor**, em `timestamptz` (UTC no banco). O navegador não manda horário.
3. **Relógio negativo é recusado** (`SAFRA_TIME_NEGATIVE`): nada antes da abertura, nem o "agora" da consulta.
4. **Horário ausente não vira "OK"** (`SAFRA_TIME_REQUIRED`); parte aberta fica em aberto, nunca zero.
5. **Tempo corrido em horas absolutas**, 24h por dia; horário de verão não muda nada.
6. **Dia e hora dos relatórios** no fuso de São Paulo.
7. **Nada disso é chamável pelo navegador.**

## Escada de avisos (D-76)

- 2h, 4h e depois de hora em hora (5h, 6h, …) desde a abertura;
- para quando o solicitante fecha a parte dele ou o protocolo é cancelado;
- o solicitante sempre recebe "foi resolvido?"; o dono recebe o pedido de cobrança só enquanto não fechou a parte dele;
- vale no instante exato (2h00); fechar ou cancelar exatamente nesse instante impede aquele aviso.

## Tempos de encerramento (D-77)

- solicitante: abertura → parte do solicitante;
- dono: abertura → parte do dono;
- consolidado: abertura → **última** parte fechada;
- `CLOSED` (as duas partes), `IN_PROGRESS` (alguma parte aberta), `CANCELLED` (fora dos tempos);
- cada tempo vem em dois formatos: intervalo (para exibir) e **total em segundos** (para somar e comparar no analytics). Use os segundos em contas: o intervalo do PostgreSQL agrupa horas em dias ("2 days 01:15").

## Testes

`supabase/tests/database/c07_aud2_time_rules.test.sql` (35): limite exato, sem aviso de 3h, de hora em hora, fechamento às 1h59 e no instante exato, cancelamento, dono que fecha primeiro, avisos simultâneos para as duas pessoas, fusos diferentes, horário de verão de 2018, relógio negativo, horário ausente, tempos parciais, cancelados e consolidado, superfície fechada ao navegador e ausência de duração gravada.
