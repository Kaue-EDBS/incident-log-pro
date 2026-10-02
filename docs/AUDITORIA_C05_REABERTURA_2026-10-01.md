# AUDITORIA C05 — REABERTURA (C05-AUD2)

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C05 — Schema v2, migrations e invariantes  
**Data:** 01/10/2026  
**Estado:** CONCLUÍDA  
**Commits:** `d7bc270` (pacote) — CI verde: App Smoke #238, Database Disposable #276  
**Migrations:** 3 reconstituídas (`20260928075934`, `20260928090910`, `20260928095246`) e `20261001200000_c05_aud2_retire_escalations_and_history_fk.sql` (aplicada e conferida no PRIMARY)

---

## 1. O que o C05 cuida (em linguagem simples)

A **estrutura do banco**: quais tabelas existem, como se ligam, quais regras impedem dados errados, como o histórico é protegido e como as mudanças de estrutura (migrations) são feitas e reconstruídas. Esta rodada auditou os 7 passos pedidos e fez uma auditoria própria.

---

## 2. Os 7 passos do C05

| # | Passo | Resultado | Observação |
|---|---|---|---|
| 1 | Autoridade das migrations, drift reconciliado, rollback | **PASS** | `supabase/migrations` é a fonte oficial; o drift de 28/09 foi reconstituído; **PRIMARY e repositório têm as mesmas 36 versões**; rollback em `ROLLBACK_E_BANCO_DESCARTAVEL.md` e ensaiado no CI |
| 2 | Schema do domínio | PASS | áreas, sistemas, papéis, cenários, versões, owners, áreas impactadas, SLAs |
| 3 | Estruturas transacionais e de governança | PASS adaptado | tratativas, eventos, avisos, propostas e `governance_issues`; escalonamento **removido** (D-73) |
| 4 | Invariantes relacionais e de estado | PASS | FKs explícitas; status por CHECK; CANCEL com motivo; END/CANCEL só de ACTIVE (`safra_guard_treatment`); estado terminal imutável |
| 5 | Integridade histórica e temporal | PASS após correção | versão congelada, versão publicada imutável, relógio do servidor; **a única cascata destrutiva (histórico de papéis) foi trocada por RESTRICT** |
| 6 | Concorrência e duplicidade | PASS | chaves de idempotência, `correlation_id`, advisory lock, trava D-57; não há views |
| 7 | Validação em banco descartável | PASS após correção | **novo teste de concorrência END × CANCEL**; demais casos já cobertos (constraints, double submit, version freeze, rollback, API direta, RLS) |

---

## 3. Auditoria própria

### C05-AUD2-01 — Drift de 28/09 — ALTA — CORRIGIDO

Três versões aplicadas no PRIMARY em 28/09/2026 sem arquivo nem SQL guardado (achado C00-AUD2-07). Comparação objeto a objeto (índices, constraints, gatilhos e hash do corpo de cada função) entre PRIMARY e repositório revelou:

| Versão | Conteúdo real | Reconstituição |
|---|---|---|
| `20260928075934_c04_reaudit_legacy_surface_hardening` | nenhum objeto vigente (atuou no legado removido pela D-50) | arquivo documentado sem efeito |
| `20260928090910_c05_notification_delivery_state_machine` | `notifications_delivery_status_check` e `notifications_delivery_state_fields_check` (no lugar de `notifications_status_not_blank`); nova `safra_notification_server_clock` | definições copiadas do PRIMARY, idempotentes |
| `20260928095246_c05_fk_indexes_and_clock_ownership` | 5 índices de FK; remoção de `trg_treatments_updated_at`; `safra_guard_scenario_version_update` sem escrever `updated_at` | definições copiadas do PRIMARY, idempotentes |

Efeito: o banco descartável do CI passa a ter o mesmo schema do PRIMARY. Teste: `c05_aud2_schema.test.sql`.

### C05-AUD2-02 — Escalonamento sem uso — MÉDIA — CORRIGIDO

`public.treatment_escalations` (0 linhas), seu guard e o tipo de evento `ESCALATION_CHANGED` removidos (D-73). O schema público passa de 17 para 16 tabelas; listas e contagens dos testes ajustadas.

### C05-AUD2-03 — Cascata destrutiva no histórico de papéis — MÉDIA — CORRIGIDO

`safra_role_grants.principal_id` era `ON DELETE CASCADE`: apagar um cadastro apagava o histórico de papéis. Passou a `ON DELETE RESTRICT`; cadastro se desativa (`is_active = false`). Nenhuma outra cascata existe em `public`/`private` (teste).

### C05-AUD2-04 — Concorrência END × CANCEL sem teste — MÉDIA — CORRIGIDO

Novo `.github/scripts/test-safra-end-cancel-concurrency.sh` no Database Disposable Test: duas sessões fecham o mesmo protocolo ao mesmo tempo (RESOLVED × CANCELLED); exatamente uma vence, a outra é barrada pelo guard terminal e o histórico não é reescrito.

### C05-AUD2-05 — Drizzle — BAIXA — REGISTRADO

`drizzle/schema.ts` está vazio ("auto-generated and intentionally left blank") e o `_journal.json` aponta para migrations removidas em 25/09. Ferramenta do Lovable, sem autoridade (ADR-035). Mantida para não interferir no Lovable.

---

## 4. Fora do C05, com fase definida

| Item | Fase |
|---|---|
| Campos do encerramento em duas partes (autor e horário por parte) e eventos `REQUESTER_PART_CLOSED`/`OWNER_PART_CLOSED` | F01 |
| Trava D-57 contando a parte do solicitante | F01 |
| Evento `REMINDER_SENT` e envio de avisos | M05 |

---

## 5. Gate

**PASS.** Schema, invariantes e histórico verificados; drift zerado (36 = 36); CI verde com os testes novos.
