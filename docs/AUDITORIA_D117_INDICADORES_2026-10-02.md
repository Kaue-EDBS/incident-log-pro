# AUDITORIA D-117 — MTTD, MTTR, MTBF e MTTF (02/10/2026)

**Origem:** pedido do owner ("precisamos ter MTTR, MTBF, MTTD e MTTF") · **Visões:** D-88  
**Migration:** `20261002250000_d117_reliability_metrics.sql` · **Tela:** Analytics  
**Testes:** `d117_reliability_metrics.test.sql` (17, com valores calculados à mão), smoke de tela (tabela e acessibilidade)

## 1. Definições (respostas do owner)

| Indicador | Conta | Decisão |
|---|---|---|
| **MTTD** | abertura − início do problema informado | 1.a |
| **MTTR** | última parte concluída − abertura (o dono só sabe quando o protocolo abre); no encerramento automático, a parte que concluiu | 2.b, D-113 |
| **Falha** | só protocolo **encerrado**; cancelados e os fora do analytics (D-115) não contam | 3.a |
| **Mesmo problema, várias pessoas** | protocolos do mesmo card que se sobrepõem no tempo = **uma** falha | 4.a |
| **MTTF** | abertura da falha − fim da falha anterior, no mesmo card | 5.a |
| **MTBF** | abertura da falha − abertura da falha anterior, no mesmo card (= MTTF + MTTR) | 5.a |
| **Cálculo** | média e mediana, na Safra corrente | 6.b |
| **Quem vê** | dono: os seus cards; Jair, Bruno e admins: todos e o consolidado | 7.a (D-88) |

## 2. Achados

| # | Achado | Tratamento |
|---|---|---|
| D117-01 | A D-50 tinha retirado MTTD/MTTR/MTBF como métricas de incidente de TI | voltam como indicadores **dos protocolos da Safra** (D-117), sem ligação com TI |
| D117-02 | Falha agrupada: qual "início do problema" vale no MTTD? | o mais cedo entre os protocolos do grupo |
| D117-03 | MTBF e MTTF precisam de pelo menos 2 falhas no card | com menos, mostram "—" (nunca um zero inventado) |
| D117-04 | O fim da Safra (marcação manual, D-59/D-70) ainda não existe | início fixo em 01/10/2026 (D-69) e fim = agora; muda quando a marcação for construída |
| D117-05 | Encerramento automático (D-113) | tempo até a parte concluída, não até a hora da varredura |
| D117-06 | Um protocolo esquecido distorce a média | a mediana aparece junto |
| D117-07 | Troca de dono do card | o dono vê os cards de que é dono **hoje**, com todo o histórico deles na Safra |
| D117-08 | Modo Camaleão | "Dono do card" mostra os cards do dono escolhido; "Governança" e "Administração" mostram tudo |
| D117-09 | Protocolos de demonstração | o total fora da conta aparece embaixo da tabela |

## 3. Evidências

- **CI:** App Smoke Test #291 e Database Disposable Test #329 verdes (commit `98ca4e5`).
- **PRIMARY (02/10/2026):** migration aplicada, **54 = 54**. Teste com o login do owner (desfeito no final): visão "todos os cards", 11 cards, 0 falhas na Safra (o único protocolo, 03-0001, foi cancelado e está fora do analytics), 1 protocolo excluído, Safra desde 01/10/2026 00:00 (São Paulo).
