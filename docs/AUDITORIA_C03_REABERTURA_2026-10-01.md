# AUDITORIA C03 — REABERTURA (C03-AUD2)

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C03 — Glossário e modelo de domínio  
**Data:** 01/10/2026  
**Estado:** CONCLUÍDA — glossário promovido à versão 2.0  
**Decisões geradas:** D-71, D-72, D-73 (`docs/DECISOES.md`)  
**Documento dono:** `docs/GLOSSARIO_DOMINIO.md` v2.0 (a v1.1 está em `docs/historico/`)

---

## 1. O que o C03 cuida (em linguagem simples)

O C03 define o **vocabulário oficial** do projeto: cada palavra (cenário, versão, protocolo, START, END…) tem um único significado, igual no banco, nas telas, nos testes e na conversa. Também define o "contrato" que diz ao banco (C05) como guardar cada conceito.

Entre 25/09 (versão 1.1) e 01/10, as decisões D-50 a D-70 mudaram o produto. Esta rodada alinhou o vocabulário a elas.

---

## 2. Os passos do C03

| # | Passo | Resultado | Observação |
|---|---|---|---|
| 0 | Vocabulário canônico do domínio | PASS após revisão | 8 termos reescritos e 5 termos novos (seção 3) |
| 1 | "Geral" é visão agregada, não área | PASS | sem mudança |
| 2 | Cenário × versão × tratativa | PASS | provado na prática pela versão 2 CRITICAL (D-55) |
| 3 | Impacto qualitativo/quantitativo e os "quatro CRITICAL" | PASS adaptado | impacto sem mudança; "quatro CRITICAL só com evidência" substituído pela D-55 (os 11 são CRITICAL) |
| 4 | Tudo no glossário, sem nome ambíguo para o C05 | PASS após revisão | contrato com o banco (seção 8) reescrito: estados, partes do END, eventos, trava, checklist |

---

## 3. O que mudou no glossário

### Termos reescritos

| Termo | Antes (v1.1) | Agora (v2.0) |
|---|---|---|
| START | qualquer pessoa; inicia SLAs | qualquer usuário corporativo **exceto o dono do card** (D-65); trava por pessoa (D-57); sem SLA (D-62) |
| Tratativa | 3 estados | 5 situações (D-72) com encerramento em duas partes |
| Owner | sem exclusividade | "dono do card"; não abre os próprios cards; fecha a parte dele; pode cancelar |
| SLA | cronômetro medido | conceito mantido, **sem uso nos cards** (D-62) |
| Criticidade | quatro CRITICAL pendentes | os 11 são CRITICAL (D-55); novo card nasce CRITICAL |
| END | um clique, qualquer pessoa | duas partes, solicitante e dono, cada um no próprio perfil (D-64/D-66) |
| CANCEL | qualquer pessoa | solicitante ou dono, com motivo (D-66) |
| Escalonamento | 4 níveis no Painel | **fora do Painel** (D-73) |
| Proposta/publicação | fluxo indefinido | proponente escreve, Jair aprova, admin publica, separação de funções (D-60/D-68) |

### Termos novos

| Termo | Origem |
|---|---|
| Solicitante | D-71 |
| Parte do solicitante / parte do dono | D-66 |
| Aviso e escada de avisos | D-58/D-67 |
| Safra corrente | D-59/D-69/D-70 |
| Card (como representação visual) | já usado; agora definido |

### Termos proibidos na interface

"chamado" (D-05, reafirmada pelo owner em 01/10), "incidente" (D-50) e "escalonamento" (D-73).

---

## 4. Impacto no C05 (banco)

O novo contrato da seção 8 do glossário aponta diferenças entre o que o banco tem hoje e o que as decisões pedem. Elas entram na reauditoria do C05 e nas fases indicadas:

| Diferença | Onde resolve |
|---|---|
| `treatments` tem um único `closed_by/closed_at`; o END em duas partes precisa de autor e horário por parte | F01 (desenho no C05-AUD) |
| trava D-57 conta `status = ACTIVE`; deve contar a parte do solicitante aberta | F01 |
| `treatment_escalations` e o evento `ESCALATION_CHANGED` sem uso (D-73) | **feito** na C05-AUD2 (01/10/2026) |
| evento `SLA_BREACHED` sem uso (D-62) | C05-AUD (documentar; sem tabela própria) |
| eventos novos `REQUESTER_PART_CLOSED`, `OWNER_PART_CLOSED`, `REMINDER_SENT` | F01/M05 |

---

## 5. Gate

Critério de saída do C03: **nenhuma entidade pode ter nome ambíguo ou duas definições concorrentes**.

**PASS.** O glossário v2.0 é a única definição vigente; a v1.1 é histórico. As diferenças com o banco estão listadas na seção 4 e têm fase responsável.

---

## 6. Fechamento complementar — 01/10/2026

Na verificação de "fechou 100%?", o owner pediu a correção de três sobras que ainda contrariavam o critério de saída do C03:

| Sobra | Correção |
|---|---|
| `REGRAS_NEGOCIO.md` com regras antigas (RB-003/004/005/006 sobre START/END/CANCEL por qualquer pessoa; RB-011 escalonamento; RB-012 SLA; RB-026 "quatro CRITICAL"; Bruno "escalonamento executivo"; precedência com "implementação legada"; lista de decisões abertas vencida) | reescritas conforme D-55 a D-73; RB-011 DEPRECATED; RB-026 mantida só como princípio; novas RB-SAFRA-030 a 033 (solicitante/dono, duas partes, avisos, Safra corrente) |
| `ARQUITETURA.md` com escalonamentos, SLA ativo e eventos `ESCALATION_CHANGED`/`SLA_BREACHED` | §4.5, §4.6, §4.7, §4.8, §4.9, §4.10, §4.11, §5 e §8 alinhadas |
| Tela com "tratativa", "START" e o endereço `/novo-incidente` | textos trocados por "protocolo"/"abertura"; rota renomeada para `/abrir-protocolo` (menu e atalhos atualizados); aviso desatualizado sobre a GI-SAFRA-004 substituído pela regra D-57 |

Verificação local: build, typecheck, lint zero-warning e checagens de coerência verdes.
