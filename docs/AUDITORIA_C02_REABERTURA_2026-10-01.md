# AUDITORIA C02 — SEGUNDA REABERTURA (C02-AUD2)

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C02 — Threat model e abuso de negócio  
**Data:** 01/10/2026  
**Estado:** CONCLUÍDA — gates recertificados; uma regra decidida (D-65) aguarda aplicação no START  
**Decisões geradas:** D-64 a D-70 (`docs/DECISOES.md`)  
**Documento dono das ameaças:** `docs/PRIVACIDADE_THREAT_MODEL.md` (§7, §7.1, §7.2 e §14)

---

## 1. O que o C02 cuida (em linguagem simples)

O C02 pensa em **como alguém poderia abusar do sistema**, por erro ou de propósito, e registra para cada abuso **qual proteção existe** e **qual teste prova que ela funciona**. Esta rodada fez duas coisas:

1. fechou a reauditoria de 27/09 (C02-AUD), que tinha sido executada mas nunca registrada como concluída;
2. revisou as ameaças à luz das decisões de 30/09 e 01/10 (D-50 a D-63), que mudaram o produto.

---

## 2. Fechamento da C02-AUD (27/09/2026)

Conferido no código, nos testes e no PRIMARY em 01/10/2026:

| Achado | Situação | Evidência |
|---|---|---|
| C02-AUD-01 — RPCs de RBAC sem predicado corporativo | CLOSED | `private.get_my_safra_roles`, `private.safra_has_role` e `public.get_safra_rbac_audit_events` usam `safra_is_corporate_user()` no PRIMARY; asserções em `c02_threat_model_authz.test.sql` |
| C02-AUD-02 — abuse cases sem definição canônica | CLOSED | `PRIVACIDADE_THREAT_MODEL.md` §7.1 |
| C02-AUD-03 — riscos residuais desatualizados | CLOSED | atualizados em 27/09 e de novo em §14 (01/10) |
| C02-AUD-04 — sem teste concorrente de START | CLOSED | `.github/scripts/test-safra-start-concurrency.sh` no Database Disposable Test |
| C02-AUD-05 — conflito de idempotência sem teste | CLOSED | `SAFRA_START_IDEMPOTENCY_CONFLICT` em `c02_threat_model_authz.test.sql` |
| C02-AUD-06 — smoke HTTP incompleto | CLOSED | `test-safra-direct-api.sh` cobre as 17 tabelas Safra |
| C02-AUD-07 — EXECUTE legado em trigger functions | CLOSED | revogado em 27/09; funções removidas pela D-50 em 30/09 |
| C02-AUD-08 — matriz de paridade desatualizada | CLOSED | `MATRIZ_PARIDADE.md` §2 separa START de END/CANCEL |
| C02-AUD-09 — contratos de END/CANCEL/12º card | CLOSED | AB-END-01..03, AB-CANCEL-01, AB-CARD-01..02 |
| C02-AUD-10 — treatment terminal reescrevível | CLOSED | guard `safra_guard_terminal_treatment_immutable` no PRIMARY; asserção "closed treatment row is immutable" |

Os testes rodaram verdes no CI em 01/10/2026 (`5f710c7`).

---

## 3. Os sete passos do C02 contra o estado atual

| # | Passo | Resultado | Observação |
|---|---|---|---|
| 1 | Abuse cases do domínio (START indevido/duplicado, END prematuro/repetido, CANCEL para mascarar) | PASS | novos: AB-START-04 (segunda abertura da mesma pessoa), AB-START-05 (dono abre o próprio card), AB-END-02 (link encaminhado), AB-END-03 (duas partes) |
| 2 | Autorização e bypass (owner/criticidade, Data API/RPC, enumeração, vazamento) | PASS | bypass de RBAC fechado; AB-NOTIF-02 cobre vazamento por canal do Teams |
| 3 | Integridade temporal e histórica | PASS | versão 2 CRITICAL criada sem reescrever a v1; guards de versão e de treatment terminal |
| 4 | Duplicidade e manipulação (retry, double submit, "parar SLA", 12º card) | PASS | sem SLA nos cards (D-62): o abuso passa a ser "parar os avisos" (AB-SLA-01 reescrito); AB-NOTIF-01; AB-CARD-02 |
| 5 | Controles associados | PASS | tabela §7.2 atualizada: trava por pessoa, avisos, D-52 contra drift |
| 6 | Testes derivados | PASS | positivos, negativos, concorrência e bordas em pgTAP e scripts; novos contratos de END/avisos ficam como testes obrigatórios da F01/M05 |
| 7 | Risco residual e gates | PASS | §14 com 15 riscos, todos com estado e fase; nenhum bloqueia |

---

## 4. Decisões tomadas nesta rodada

| ID | Decisão |
|---|---|
| D-64 | END só por quem abriu ou pelo dono do card, cada um no próprio perfil; botão "Resolvido" abre o Painel e pede confirmação |
| D-65 | dono de card não abre protocolo dos próprios cards; pode abrir de cards de outros donos |
| D-66 | encerramento em duas partes, cada uma com seu horário; CANCEL por um dos dois, com motivo; trava liberada quando o usuário fecha a parte dele; relatórios com três tempos |
| D-67 | escada de avisos: 2h e 4h ao dono (para cobrar o usuário) e ao usuário, até ele fechar; sem Jair e sem 3h; 4h não é SLA |
| D-68 | 12º card com separação de funções; proposta do Jair aprovada pelo Kaue |
| D-69 | Safra corrente começou em 01/10/2026; termina quando o Kaue marcar |
| D-70 | encerrar a Safra exige digitar "ENCERRAR SAFRA"; 7 dias para reabrir sem apagar dados |

Nova pendência: **GI-SAFRA-011** — avisos também pelo Teams? Para pessoa ou canal? (M05).

---

## 5. Gates

| Gate | Significado | Resultado |
|---|---|---|
| G3.5 | modelo de ameaças completo, com controles e fase para cada risco | **PASS** |
| THREAT-001 | abusos de negócio mapeados e ligados a controles e testes | **PASS** |
| AUTHZ-001 | autorização validada no servidor, sem bypass conhecido | **PASS** — bypass de RBAC fechado e verificado no PRIMARY |

**Ressalva:** a regra D-65 (dono não abre o próprio card) está decidida, mas a verificação no START ainda não foi aplicada (RR-C02-11). Não é falha de acesso: hoje o dono consegue abrir protocolo do próprio card, o que contraria a regra de negócio, mas não expõe dado nem eleva privilégio. Entra na próxima migration do START.

---

## 6. Pendências que saem desta auditoria

1. Aplicar a D-65 no START (migration + teste + mensagem na tela).
2. Espelhar a GI-SAFRA-011 na tabela `public.governance_issues` (D-53), na mesma migration.
3. F01/F02: END em duas partes, CANCEL por um dos dois, trava por parte do usuário (D-64/D-66).
4. M05: escada de avisos (D-67), aviso de abertura (D-58), decisão sobre Teams (GI-SAFRA-011).
5. F04/M05: marcação da Safra com as proteções da D-70.
6. M10: 12º card com separação de funções (D-68).
