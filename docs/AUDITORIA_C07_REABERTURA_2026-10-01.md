# AUDITORIA C07 — REABERTURA (C07-AUD2)

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C07 — Engine de SLA → regras de tempo  
**Data:** 01/10/2026  
**Estado:** CONCLUÍDA  
**Migration:** `20261001230000_c07_aud2_retire_sla_engine_and_time_rules.sql` (CI verde: App Smoke #244, Database Disposable #282; aplicada e conferida no PRIMARY: 38 = 38, 15 tabelas, 0 funções de SLA)  
**Teste novo:** `c07_aud2_time_rules.test.sql` (31)  
**Decisões:** D-75, D-76, D-77

---

## 1. O que o C07 cuida (em linguagem simples)

Originalmente, a **engine de SLA**: o cronômetro de prazo de cada card. Como o owner decidiu que nenhum card terá SLA (D-62), o C07 passa a cuidar das **regras de tempo** que o produto vai usar: a escada de avisos e os tempos de encerramento do analytics.

---

## 2. Decisões do owner nesta rodada

| # | Pergunta | Resposta | Decisão |
|---|---|---|---|
| 1 | O que fazer com a engine de SLA parada? | Aposentar | D-75 |
| 2 | Dono que fechou primeiro continua recebendo o pedido de cobrança? | Não; só o solicitante | D-76 |
| 3 | Depois das 4h? | Continua avisando de hora em hora | D-76 |
| 4 | Tempo consolidado? | Até a última parte fechada | D-77 |

---

## 3. Os 6 passos do C07, adaptados

| # | Passo original (SLA) | Adaptação | Resultado |
|---|---|---|---|
| 1 | Duração derivada de eventos | Tempos do analytics sempre calculados; nenhuma duração gravada | PASS — teste confere que nenhuma tabela tem coluna de duração |
| 2 | Definição completa do SLA | Definição da escada (2h, 4h, de hora em hora; quem recebe; quando para) | PASS — D-76 e `safra_reminder_steps` |
| 3 | Sem evento = não mensurável | Parte aberta fica em aberto; cancelado fora dos tempos; horário ausente recusado | PASS |
| 4 | Fuso e regras temporais | UTC no banco, São Paulo nos relatórios, horas absolutas | PASS |
| 5 | Sem relógio negativo nem manipulação | `as_of` ou parte antes da abertura recusados; horários só do servidor; funções fora do alcance do navegador | PASS |
| 6 | Testes de borda | Exatamente 2h00, 1h59, fechamento no instante exato, cancelamento, dois avisos simultâneos, fusos, horário de verão | PASS — 31 testes |

---

## 4. Auditoria própria

### C07-AUD2-01 — Engine de SLA sem uso — MÉDIA — APOSENTADA (D-75)

Seis funções, a tabela `scenario_slas` (0 linhas), o evento `SLA_BREACHED` (0 registros), campos de SLA no catálogo e no resumo do START, e 8 arquivos de teste sustentavam um recurso que o produto não usa. Removidos. Os prazos da Matriz v3 seguem como texto de referência. Schema público: 16 → 15 tabelas.

### C07-AUD2-02 — Regras de tempo do produto sem teste — MÉDIA — CORRIGIDO

A escada de avisos e os tempos do analytics existiam só como texto nas decisões. Agora são cálculos testados, prontos para a M05 (envio) e a F01 (colunas de cada parte).

### C07-AUD2-03 — Texto da GI-SAFRA-009 incompleto — BAIXA — CORRIGIDO

A resolução citava só 2h e 4h. Atualizada para a escada da D-76, no banco e na função de resolução.

### Verificado e correto

- todos os horários vêm de gatilhos de relógio do servidor (C05);
- o fuso do banco continua UTC (`c07_timezone_analytics_smoke`);
- o contrato de fuso do front (`src/lib/metrics.ts`) segue testado em dois fusos no CI.

### Para a F01/M05

- colunas de horário e autor de cada parte fechada (D-66/D-72);
- envio dos avisos usando `safra_reminder_steps`, um envio por etapa (AB-NOTIF-01);
- a trava da D-57 contando a parte do solicitante.

---

## 5. Gate

**PASS.** SLA aposentado sem perda de dado; regras de tempo do produto definidas pelo owner e cobertas por testes de borda.
