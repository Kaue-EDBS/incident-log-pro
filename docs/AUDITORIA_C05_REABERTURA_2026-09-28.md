# AUDITORIA C05 — SCHEMA V2, MIGRATIONS E INVARIANTES

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C05 — Schema v2, migrations e invariantes  
**Abertura:** 28/09/2026 às 08:56 BRT  
**Branch exclusiva:** `audit/c05-schema-v2-migrations-invariants-2026-09-28`  
**Base:** C04-AUD empilhada + Lovable Cloud PRIMARY  
**Estado:** AUDITORIA ABERTA / ACHADOS AGUARDANDO DECISÃO  
**Regra:** o fechamento histórico do C05 é preservado; esta C05-AUD é uma reauditoria posterior e não altera produção sem decisão explícita.

## 1. Escopo assimilado

1. Definir a autoridade canônica das migrations, escolher entre `supabase/migrations` e Drizzle, reconciliar drift e documentar rollback.
2. Validar o schema v2: áreas, sistemas, papéis, cenários, versões, owners, áreas impactadas e SLAs.
3. Validar estruturas transacionais/governança: tratativas, eventos, escalonamentos, notificações, propostas e `governance_issues`.
4. Validar invariantes relacionais/estado: FKs, status governados, CANCEL com motivo e END/CANCEL somente de ACTIVE.
5. Validar integridade histórica/temporal: freeze de `scenario_version_id`, imutabilidade de versão publicada, timestamps server-side e ausência de cascade destrutivo.
6. Validar concorrência/duplicidade: idempotência, `correlation_id`, constraints temporais e views com RLS/security invoker.
7. Validar migrations/schema em banco descartável: constraints positivas/negativas, double submit, concorrência END x CANCEL, version freeze, rollback, API direta e RLS positiva/negativa.

## 2. Autoridade de migrations e drift

### Resultado

**PASS estrutural.**

- `supabase/migrations` está documentado como fonte canônica em `PROJECT_PROFILE`, `ROADMAP` e `ROLLBACK_E_BANCO_DESCARTAVEL.md`;
- Drizzle não possui autoridade de deploy;
- branch possui **28** migrations Supabase;
- PRIMARY registra **28** migrations;
- diferenças Git-only: **0**;
- diferenças PRIMARY-only: **0**;
- correspondência de versões: **exata**.

Drizzle atual:

- `drizzle/schema.ts` está intencionalmente vazio;
- snapshots 0000..0003 contêm 0 tabelas, 0 enums, 0 schemas e 0 views;
- não há migration SQL ativa sob `drizzle/migrations`;
- `drizzle.config.ts` e dependências Drizzle permanecem no repositório.

**Observação de higiene C05-HYG-01:** o tooling Drizzle residual não produz drift hoje, mas mantém uma segunda aparência de mecanismo de migration. Decidir entre remover os artefatos residuais ou criar um gate explícito que impeça Drizzle de ganhar autoridade por acidente.

## 3. Schema v2 e estruturas

### Resultado

**PASS.**

PRIMARY:

- 17/17 tabelas públicas do domínio Safra presentes;
- 17/17 com RLS;
- 2/2 tabelas privadas de papéis presentes: `safra_principals`, `safra_role_grants`;
- 8/8 entidades core: áreas, sistemas, cenários, versões, owners, relações de áreas/sistemas e SLAs;
- 7/7 estruturas transacionais/governança: treatments, events, escalations, notifications, proposals/responses e governance issues;
- 2/2 estruturas de impacto real.

Integridade relacional:

- **36 FKs** no domínio;
- **0 FKs com ON DELETE CASCADE**;
- **55 CHECK constraints**;
- **12 UNIQUE constraints** além de índices únicos parciais.

## 4. Invariantes de estado

### PASS

- `scenarios.lifecycle_status` governado;
- `scenario_versions.status` governado;
- `scenario_versions.criticality` governada quando não nula;
- `treatments.status` governado;
- `treatment_events.event_type` governado;
- `treatment_escalations.level` governado;
- `scenario_proposal_owner_responses.response` governado;
- `governance_issues.status` governado;
- CANCEL exige motivo não vazio;
- state fields de ACTIVE/RESOLVED/CANCELLED são mutuamente consistentes;
- END/CANCEL sequencial só pode partir de ACTIVE;
- treatment terminal não reabre.

### C05-AUD-01 — status de notificação não governado

**Estado:** OPEN / SCHEMA GAP  
**Severidade:** MEDIUM  
**Decisão humana necessária:** SIM

`notifications_log.delivery_status` possui apenas:

`CHECK (btrim(delivery_status) <> '')`

Teste adversarial reversível no PRIMARY comprovou que:

`delivery_status = 'TOTALLY_INVALID_STATUS'`

é aceito pelo banco.

Isso diverge do requisito de status governados. É necessário definir o vocabulário permitido antes da correção (por exemplo, quais estados de entrega são canônicos).

## 5. Integridade histórica e temporal

### Resultado

**PASS no comportamento atual.**

PRIMARY confirmado por teste reversível:

- conteúdo de versão PUBLISHED não pode ser alterado;
- filhos de versão PUBLISHED (áreas/sistemas/SLA) não podem ser alterados;
- `treatments.scenario_version_id` é snapshot imutável;
- CANCEL sem motivo é rejeitado;
- END de ACTIVE para RESOLVED funciona com `closed_at` server-side;
- tentativa posterior de CANCEL em tratativa terminal é rejeitada;
- nenhum teste deixou fixture persistida.

Controles existentes:

- server clock para scenario version;
- server clock para treatment;
- eventos append-only;
- impact measurements append-only;
- freeze de conteúdo filho;
- ausência de cascade destrutivo;
- constraints temporais de validade/open/close/cancel/notification/governance.

### C05-AUD-02 — version freeze sem regressão comportamental permanente C05

**Estado:** CLOSED / PASS_PRIMARY  
**Severidade:** MEDIUM  
**Decisão humana necessária:** NÃO

O comportamento passou no PRIMARY e existe evidência histórica no STATUS, porém a suíte C05 permanente atualmente verifica principalmente **existência de triggers**, não tenta modificar uma versão PUBLISHED e confirmar a rejeição.

Proposta: adicionar pgTAP negativo permanente para versão publicada + filhos + snapshot de treatment.

## 6. Concorrência, duplicidade e correlation

### PASS parcial

- START possui idempotência estrutural;
- `treatments.start_idempotency_key` é UNIQUE;
- `notifications_log.idempotency_key` é UNIQUE;
- `treatment_events` possui unicidade por treatment/event/idempotency quando a chave existe;
- `correlation_id` é NOT NULL nas estruturas críticas;
- há teste concorrente real para START (`test-safra-start-concurrency.sh`);
- constraints temporais/índices de uma relação ativa existem para owner, áreas impactadas e escalonamento;
- não existem views públicas/privadas hoje; requisito de `security_invoker` é **N/A nesta fotografia**.

### C05-AUD-03 — concorrência END x CANCEL não é testada

**Estado:** CLOSED / PASS_RUNTIME_AND_DISPOSABLE_GATE  
**Severidade:** HIGH  
**Decisão humana necessária:** NÃO

Não existe teste com duas transações reais competindo pelo mesmo treatment, uma tentando END e outra CANCEL.

Os guards sequenciais estão corretos, mas isso não substitui a prova de concorrência exigida pelo próprio escopo C05.

Como END/CANCEL RPCs ainda não existem, o teste deve ser feito agora no **nível de persistência** em banco descartável; o teste RPC deve ser repetido quando F01/F02 implementar as mutações.

## 7. Banco descartável, rollback, API direta e RLS

Suítes atuais executadas contra o PRIMARY em transação:

- `c05_schema_v2.test.sql` -> **23/23 PASS**;
- `c05_technical_guards.test.sql` -> **7/7 PASS**.

Database Disposable reconstrói migrations do zero e roda pgTAP, lint, START concorrente e smokes de API/RPC.

### C05-AUD-04 — rollback verifica tracking, não restauração estrutural

**Estado:** OPEN / TEST GAP  
**Severidade:** MEDIUM  
**Decisão humana necessária:** NÃO

`latest_migration_rollback.test.sql` valida apenas que a versão mais recente saiu de `supabase_migrations.schema_migrations`.

Não há assert genérico/manifesto comprovando que os objetos alterados pela migration voltaram ao estado anterior.

A documentação de rollback está correta: migration já publicada em produção deve receber forward-fix. O gap é de **ensaio local**, não da política operacional.

### C05-AUD-05 — direct API autenticada não é exercitada por HTTP

**Estado:** IMPLEMENTED / AWAITING_DISPOSABLE_RUNTIME  
**Severidade:** MEDIUM  
**Decisão humana necessária:** NÃO

`test-safra-direct-api.sh` usa apenas a publishable/anon key e prova negação anônima.

Há prova SQL de que `authenticated` não possui grants diretos e de que RLS oculta linhas quando grants são temporariamente adicionados, mas não existe um smoke HTTP com token de usuário autenticado tentando acessar diretamente as tabelas.

### C05-AUD-06 — significado de “RLS positiva” no desenho RPC-only

**Estado:** WAITING_HUMAN_DECISION / TEST CONTRACT  
**Severidade:** MEDIUM  
**Decisão humana necessária:** SIM

Hoje o browser possui **0 CRUD direto** nas tabelas Safra e há **0 policies públicas**; acesso positivo acontece por RPC governada.

Logo, “RLS positiva” não existe como caminho produtivo de tabela.

Decidir uma das duas interpretações:

A. considerar a autorização positiva por RPC como o lado positivo do contrato e manter RLS/tabela apenas como deny-by-default;  
B. exigir uma policy positiva de tabela apenas para satisfazer o teste — opção que ampliaria a superfície Data API e contradiz o hardening atual.

Recomendação técnica da auditoria: **A**.

## 8. Higiene estrutural

### C05-HYG-02 — cinco FKs sem índice de suporte pelo lado filho

**Estado:** IMPROVEMENT  
**Severidade:** LOW/MEDIUM PERFORMANCE

FKs sem índice cujo prefixo começa pelas colunas FK:

- `governance_issues.resolved_by`;
- `scenario_proposal_owner_responses.candidate_owner_id`;
- `scenario_version_impacted_areas.operational_area_id`;
- `scenario_version_systems.system_id`;
- `treatment_impacted_areas.operational_area_id`.

Não afeta integridade, mas pode aumentar scans/locks em joins e tentativas de update/delete nos pais.

### C05-HYG-03 — clocks/updated_at redundantes

**Estado:** IMPROVEMENT  
**Severidade:** LOW

- `scenario_versions.updated_at` é tocado tanto pelo server-clock quanto pelo guard de update;
- `treatments.updated_at` é tocado tanto pelo server-clock quanto por `safra_touch_updated_at`.

Não foi encontrada falha funcional, mas há duplicidade de responsabilidade entre triggers.

## 9. Resultado consolidado

```text
MIGRATION_AUTHORITY = PASS
MIGRATION_HISTORY_28_OF_28 = PASS
SCHEMA_V2 = PASS
TRANSACTIONAL_GOVERNANCE_SCHEMA = PASS
FK_CASCADE_DESTRUCTIVE = 0
HISTORICAL_FREEZE_RUNTIME = PASS
SERVER_TIMESTAMPS = PASS
START_IDEMPOTENCY_CONCURRENCY = PASS_BY_EXISTING_TEST
PUBLIC_VIEWS = 0 / N_A

OPEN_FINDINGS = 6
  C05-AUD-01 notification status vocabulary
  C05-AUD-02 permanent version-freeze regression
  C05-AUD-03 END x CANCEL real concurrency
  C05-AUD-04 structural rollback proof
  C05-AUD-05 authenticated direct-API HTTP smoke
  C05-AUD-06 positive-RLS contract interpretation

HYGIENE_IMPROVEMENTS = 2
  C05-HYG-01 Drizzle residual tooling
  C05-HYG-02 five FK support indexes
  C05-HYG-03 duplicate updated_at/clock responsibility

C05_AUD = OPEN / AWAITING_DECISIONS
```

## 10. Decisões necessárias antes de corrigir

1. Definir o vocabulário canônico de `notifications_log.delivery_status`.
2. Confirmar que “RLS positiva” será interpretada como **autorização positiva via RPC governada**, mantendo tabelas deny-by-default, em vez de criar policy positiva direta.

Os demais achados podem ser corrigidos tecnicamente sem nova decisão de negócio, após autorização.


## 11. Decisões aprovadas e execução

**Registrado em:** 28/09/2026 às 09:12 BRT

### 11.1 Decisão 1 — vocabulário canônico de notificações

**Decisão aprovada:** usar somente:

- `QUEUED`;
- `SENT`;
- `FAILED`.

Máquina de estados aprovada:

```text
QUEUED -> SENT
QUEUED -> FAILED
SENT = terminal
FAILED = terminal
```

Regras de consistência:

```text
QUEUED
  sent_at = null
  failed_at = null
  failure_reason = null

SENT
  sent_at != null
  failed_at = null
  failure_reason = null

FAILED
  sent_at = null
  failed_at != null
  failure_reason != null / non-blank
```

Também foi decidido que toda notificação **nasce QUEUED**.

#### Implementação

Migration canônica:

`supabase/migrations/20260928090910_c05_notification_delivery_state_machine.sql`

A migration:

- remove o check permissivo `notifications_status_not_blank`;
- cria `notifications_delivery_status_check`;
- cria `notifications_delivery_state_fields_check`;
- endurece `private.safra_notification_server_clock()`;
- obriga INSERT inicial como QUEUED;
- permite apenas QUEUED -> SENT ou QUEUED -> FAILED;
- torna SENT/FAILED terminais;
- gera `sent_at` e `failed_at` no banco;
- exige `failure_reason` em FAILED;
- preserva `queued_at` e `created_at` server-side.

#### Evidência

Ensaio reversível pré-promoção:

```text
7/7 PASS
```

Regressão permanente:

`supabase/tests/database/c05_notification_delivery_state_machine.test.sql`

Resultado no PRIMARY após promoção:

```text
c05_notification_delivery_state_machine = 10/10 PASS
c05_schema_v2 = 23/23 PASS
c05_technical_guards = 7/7 PASS
notifications_log residual rows = 0
migration_count = 29
```

**C05-AUD-01 = CLOSED / PASS_PRIMARY**

---

### 11.2 Decisão 2 — interpretação de “RLS positiva”

**Decisão aprovada: OPÇÃO A.**

Contrato:

```text
ACESSO POSITIVO = RPC GOVERNADA
ACESSO DIRETO À TABELA = DENY-BY-DEFAULT
RLS DE TABELA = DEFESA NEGATIVA / DEFENSE-IN-DEPTH
```

Não será criada policy positiva de tabela apenas para satisfazer um teste.

Motivo:

- a arquitetura atual é RPC-only para a superfície funcional Safra;
- `authenticated` possui 0 CRUD direto;
- criar policy positiva reabriria Data API sem necessidade funcional;
- o caminho positivo já é exercitado por RPC autenticada;
- o caminho negativo continua coberto por grants + RLS + smoke de Data API.

Portanto, para C05:

- **RLS negativa** = usuário/anon não acessa tabela diretamente;
- **autorização positiva** = usuário corporativo válido executa RPC governada;
- views futuras, se surgirem, deverão usar `security_invoker` ou permanecer não expostas.

**C05-AUD-06 = CLOSED / DECISION_A**

---

## 12. Estado atualizado das pendências

Após as duas decisões acima:

```text
OPEN_FINDINGS = 2
CLOSED_THIS_ROUND = 4
HYGIENE_IMPROVEMENTS = 2
```

### Pendências ainda abertas

| ID | Pendência | Tipo | Severidade | Decisão humana |
|---|---|---|---|---|
| C05-AUD-04 | fortalecer rollback para provar restauração estrutural, não apenas tracking | Rollback test gap | MEDIUM | NÃO |
| C05-AUD-05 | executar no banco descartável o smoke HTTP autenticado já implementado | API runtime evidence | MEDIUM | NÃO |

### Melhorias de higiene ainda abertas

| ID | Melhoria | Impacto |
|---|---|---|
| C05-HYG-02 | adicionar índices de suporte para 5 FKs hoje não cobertas pelo prefixo de índice | Performance / locks |
| C05-HYG-03 | reduzir responsabilidade duplicada de `updated_at` em triggers | Clareza / manutenção |

### Itens fechados nesta rodada

| ID | Estado |
|---|---|
| C05-AUD-01 | CLOSED / PASS_PRIMARY |
| C05-AUD-06 | CLOSED / DECISION_A |

A C05-AUD permanece aberta até tratamento ou decisão explícita sobre os 4 gaps técnicos e 3 melhorias de higiene.


## 13. Bloco A — autoridade única de migrations

**Executado em:** 28/09/2026 às 09:23 BRT  
**Escopo:** C05-HYG-01  
**Estado:** **CLOSED / PASS**

### 13.1 Diagnóstico confirmado

A auditoria confirmou que Drizzle não possuía uso real em runtime, build ou CI:

- nenhum script de `package.json` usa Drizzle;
- nenhum workflow usa Drizzle;
- nenhuma referência de código a `drizzle-kit`, `drizzle-orm` ou `LOVABLE_DB_MIGRATION_URL`;
- `drizzle/schema.ts` estava vazio;
- os quatro snapshots Drizzle continham 0 tabelas, 0 enums, 0 schemas e 0 views;
- `supabase/migrations` já era a autoridade documental e operacional.

### 13.2 Limpeza executada

Removidos da branch:

- `drizzle.config.ts`;
- `drizzle/schema.ts`;
- `drizzle/migrations/meta/0000_snapshot.json`;
- `drizzle/migrations/meta/0001_snapshot.json`;
- `drizzle/migrations/meta/0002_snapshot.json`;
- `drizzle/migrations/meta/0003_snapshot.json`;
- `drizzle/migrations/meta/_journal.json`.

Dependências diretas removidas de `package.json` e do manifesto raiz de `bun.lock`:

- `drizzle-kit`;
- `drizzle-orm`;
- `postgres`.

A remoção de `postgres` foi feita porque não existe import/uso direto no projeto e sua presença estava associada somente ao tooling Drizzle removido.

### 13.3 Gate permanente

Criado:

`.github/scripts/check-c05-migration-authority.py`

Contrato do gate:

- `supabase/migrations` precisa existir;
- precisa haver pelo menos uma migration SQL canônica;
- `drizzle.config.*` é proibido;
- diretório `drizzle/` é proibido;
- `drizzle-kit` e `drizzle-orm` como dependências diretas são proibidos;
- scripts de package não podem invocar Drizzle.

O gate foi incluído em:

- `.github/workflows/app-smoke-test.yml`;
- `.github/workflows/database-disposable-test.yml`.

### 13.4 Verificação

Fotografia da branch após limpeza:

```text
package drizzle-kit = absent
package drizzle-orm = absent
package postgres = absent

bun.lock root drizzle-kit = absent
bun.lock root drizzle-orm = absent
bun.lock root postgres = absent

drizzle paths = 0
supabase migrations = 29
migration authority gate = present
```

PRIMARY permanece inalterado por este bloco:

```text
supabase_migrations.schema_migrations = 29
latest = 20260928090910
```

Nenhuma DDL foi executada no PRIMARY no Bloco A.

### 13.5 Decisão arquitetural consolidada

```text
MIGRATION_AUTHORITY = supabase/migrations
DRIZZLE_MIGRATION_AUTHORITY = FORBIDDEN
SECOND_SCHEMA_TRACK = FORBIDDEN_WITHOUT_EXPLICIT_ADR
C05-HYG-01 = CLOSED/PASS
```

O CI executável do head final continua sujeito ao gate normal da fila/GitHub Actions; a verificação estrutural desta branch passou pela inspeção direta acima.


## 14. Bloco B — invariantes difíceis e superfície autenticada

**Executado em:** 28/09/2026 às 09:37 BRT  
**Escopo:** C05-AUD-02, C05-AUD-03 e C05-AUD-05  
**Estado:** **PARCIALMENTE CONCLUÍDO — 2 CLOSED / 1 IMPLEMENTED_PENDING_RUNTIME**

### 14.1 C05-AUD-02 — regressão comportamental de version freeze

Criado:

`supabase/tests/database/c05_version_freeze_behavior.test.sql`

A regressão agora tenta de fato violar os invariantes, em vez de apenas verificar existência de triggers.

Cobertura:

1. alteração de conteúdo de versão `PUBLISHED`;
2. regressão de `PUBLISHED -> DRAFT`;
3. remoção de área impactada de versão publicada;
4. remoção de sistema de versão publicada;
5. inclusão de SLA em versão publicada;
6. alteração de `treatment.scenario_version_id`;
7. alteração de `owner_id_at_start`;
8. alteração de `responsible_area_id_at_start`;
9. alteração de `opened_at`;
10. confirmação de que o snapshot permaneceu inalterado.

Execução contra o Lovable Cloud PRIMARY, dentro de transação com rollback:

```text
10/10 PASS
```

Pós-teste:

```text
synthetic auth users = 0
synthetic treatments = 0
synthetic SLAs = 0
```

**C05-AUD-02 = CLOSED / PASS_PRIMARY**

---

### 14.2 C05-AUD-03 — concorrência real END x CANCEL

Criado o teste permanente de banco descartável:

`.github/scripts/test-c05-end-cancel-concurrency.sh`

O script executa duas disputas reais, com duas conexões PostgreSQL concorrentes:

```text
ROUND 1
END adquire a linha primeiro
CANCEL compete pela mesma treatment
esperado: END commit / CANCEL reject

ROUND 2
CANCEL adquire a linha primeiro
END compete pela mesma treatment
esperado: CANCEL commit / END reject
```

O gate também valida que nenhum estado híbrido aparece.

Foi integrado ao:

`.github/workflows/database-disposable-test.yml`

#### Prova runtime controlada no PRIMARY

Para não escrever tratativas fictícias em `public.treatments`, foi criada temporariamente uma tabela técnica isolada:

`private.c05_aud_concurrency_treatments`

Ela recebeu a mesma estrutura relevante e os mesmos quatro triggers/guards usados por `public.treatments`.

Foram abertas sessões concorrentes reais.

**END-first:**

```text
END = commit
CANCEL = rejected
erro concorrente = closed treatment row is immutable
estado final = RESOLVED
closed_at = populated
cancelled_at = null
```

**CANCEL-first:**

```text
CANCEL = commit
END = rejected
erro concorrente = closed treatment row is immutable
estado final = CANCELLED
cancelled_at = populated
cancellation_reason = preserved
closed_at = null
```

Após a prova:

`private.c05_aud_concurrency_treatments` foi removida e a inexistência foi confirmada.

Isso comprova que o guard terminal serializa corretamente a disputa e que **exatamente uma transição terminal vence**, independentemente da ordem de lock.

A prova canônica no banco descartável permanece obrigatória no CI para evitar depender de DDL técnica no PRIMARY.

**C05-AUD-03 = CLOSED / PASS_RUNTIME_AND_DISPOSABLE_GATE**

---

### 14.3 C05-AUD-05 — HTTP autenticado contra Data API

Criado:

`.github/scripts/test-c05-authenticated-direct-api.sh`

Fluxo do teste:

1. sobe stack Supabase descartável;
2. usa a chave administrativa **somente local** para criar usuário descartável confirmado;
3. autentica esse usuário por senha;
4. valida o token em `/auth/v1/user`;
5. usa esse token autenticado contra as 17 tabelas Safra pela REST Data API;
6. todas devem responder negação;
7. tenta também POST/PATCH diretos em `treatments` e `scenario_owners`;
8. remove o usuário descartável ao final.

O teste prova especificamente a diferença entre:

```text
AUTH TOKEN VALID = true
DIRECT TABLE SURFACE = denied
```

Foi integrado ao:

`.github/workflows/database-disposable-test.yml`

#### Execução nesta sessão

Não foi possível executar este smoke HTTP agora porque o ambiente de execução disponível não possui Supabase CLI/Docker local e o acesso de rede do container está indisponível. Não foi criado usuário no PRIMARY e não foram lidos/expostos secrets de produção para contornar a limitação.

Portanto:

**C05-AUD-05 = IMPLEMENTED / AWAITING_DISPOSABLE_RUNTIME**

Ele só será fechado como PASS após execução real no Database Disposable.

---

### 14.4 Resultado do Bloco B

```text
C05-AUD-02 = CLOSED/PASS_PRIMARY
C05-AUD-03 = CLOSED/PASS_RUNTIME_AND_DISPOSABLE_GATE
C05-AUD-05 = IMPLEMENTED/AWAITING_DISPOSABLE_RUNTIME

OPEN_FINDINGS = 2
  C05-AUD-04 structural rollback proof
  C05-AUD-05 authenticated HTTP runtime evidence

HYGIENE_IMPROVEMENTS = 2
  C05-HYG-02 FK support indexes
  C05-HYG-03 duplicate updated_at responsibility
```

Próximo bloco estrutural: C05-HYG-02 + C05-HYG-03.  
O fechamento final ainda precisará executar o smoke HTTP autenticado e o rollback estrutural no banco descartável.
