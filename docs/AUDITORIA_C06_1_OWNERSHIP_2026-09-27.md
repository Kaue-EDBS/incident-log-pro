# Auditoria SAFRA-C06.1 — Teste de ownership real

Data: 27/09/2026  
Repositório: `Kaue-EDBS/incident-log-pro`  
Branch auditada: `main`  
Ambiente live auditado: Lovable Cloud PRIMARY / PostgreSQL-Supabase

## Objetivo

Reexecutar o SAFRA-C06.1 de ponta a ponta e fechar as quatro ações de ownership somente com evidência verificável em:

- vínculos persistidos no schema v2;
- RBAC e RLS;
- banco PRIMARY;
- UI/server;
- REST/Data API;
- RPC;
- banco descartável reconstruído pelas migrations canônicas;
- GitHub Actions.

Nenhuma regra de ownership foi inferida a partir de papel administrativo.

## Resultado executivo

```text
C06_1_ACTION_01 = PASS
C06_1_ACTION_02 = PASS
C06_1_ACTION_03 = PASS
C06_1_ACTION_04 = PASS
C06_1_PRIMARY_AUDIT = PASS
C06_1_MIGRATION_DRIFT = 0
C06_1_APP_SMOKE = PASS_RUN_87
C06_1_DATABASE_CI = PASS_RUN_125
SAFRA_C06_1 = CONCLUIDO
NEXT_PHASE = SAFRA-C07
```

## Ação 1 — ownership real dos 11 cenários

Fonte técnica:

```text
public.scenarios
-> public.scenario_owners
-> private.safra_principals
-> private.safra_role_grants
```

Teste permanente:

`supabase/tests/database/c06_02_real_ownership_persistence.test.sql`

Reauditoria no PRIMARY:

- 11 cenários canônicos;
- 11 vínculos ativos de ownership;
- exatamente 1 owner ativo por cenário;
- 3 owners distintos;
- 0 vínculos órfãos;
- 0 owner sem role ativa `scenario_owner`;
- 0 overlap com `safra_platform_admin`, `safra_governance_admin` ou `safra_executive_admin`;
- 0 `assignment_reason` ausente;
- índice único parcial preserva no máximo um owner ativo por cenário.

Distribuição confirmada:

| Cenário  | Owner           |
| -------- | --------------- |
| SAFRA-01 | Daniel Garcia   |
| SAFRA-02 | Daniel Garcia   |
| SAFRA-03 | Daniel Garcia   |
| SAFRA-04 | Jiane Rodrigues |
| SAFRA-05 | Jiane Rodrigues |
| SAFRA-06 | Jiane Rodrigues |
| SAFRA-07 | Daniel Garcia   |
| SAFRA-08 | Jiane Rodrigues |
| SAFRA-09 | Renato de Paulo |
| SAFRA-10 | Daniel Garcia   |
| SAFRA-11 | Daniel Garcia   |

Validação humana dos 11 vínculos: **APROVADA**.

Resultado:

```text
C06_1_ACTION_01_TECHNICAL = PASS
C06_1_ACTION_01_HUMAN_VALIDATION = APPROVED
```

## Ação 2 — sem herança administrativa e sem fallback silencioso

Teste permanente:

`supabase/tests/database/c06_1_owner_no_inheritance_no_fallback.test.sql`

Cobertura:

- ownership exige vínculo explícito em `scenario_owners`;
- role administrativa não cria ownership;
- role `scenario_owner` isolada não substitui o vínculo de cenário;
- cenário PUBLISHED exige exatamente um owner ativo;
- owner de cenário PUBLISHED precisa possuir role `scenario_owner` ativa;
- ausência do vínculo não seleciona fallback;
- admin inelegível não substitui owner automaticamente;
- testes negativos preservam o estado original por rollback.

Resultado:

```text
C06_1_ACTION_02 = PASS
TESTS = 10/10
ADMIN_ROLE_INHERITANCE = 0
SILENT_OWNER_FALLBACK = 0
```

## Ação 3 — coerência de leitura/autorização entre UI, REST/RPC e banco

Evidência canônica:

`docs/data-contracts/C06_1_READ_AUTHORIZATION_EVIDENCE.md`

Testes permanentes:

- `supabase/tests/database/c06_1_read_authorization_coherence.test.sql`;
- `.github/scripts/check-c06-1-ui-auth-coherence.py`;
- `.github/scripts/test-safra-direct-api.sh`;
- `.github/scripts/test-safra-direct-rpc.sh`.

Reauditoria:

- RLS ativa no catálogo/ownership Safra;
- `anon` sem SELECT direto;
- `authenticated` sem SELECT direto enquanto a read API governada não existe;
- 0 policy silenciosa expondo catálogo Safra;
- browser sem acesso direto a `private.safra_principals` e `private.safra_role_grants`;
- `anon` sem EXECUTE nos predicados corporativos/RBAC;
- sessão autenticada mantém somente os RPCs de identidade/RBAC previstos;
- nenhum RPC público de leitura de scenario/owner existe nesta fase;
- UI não lê `scenarios` ou `scenario_owners` diretamente;
- UI não utiliza `user_metadata` para autorização;
- service role não é usado no browser.

CI fresco:

- App Smoke Run 87 / ID `36309242985`: **SUCCESS**;
- Database Disposable Run 125 / ID `36309242956`: **SUCCESS**.

Resultado:

```text
C06_1_ACTION_03 = PASS
AUTHORIZATION_COHERENCE = PASS
REST_ANON = DENIED
RPC_ANON = DENIED
SAFRA_UI_CATALOG_READ = NOT_IMPLEMENTED_YET
UI_VS_API_DATASET_PARITY = NOT_APPLICABLE_UNTIL_GOVERNED_READ_API
```

A ausência da read API Safra não é tratada como paridade positiva. Quando essa API existir, deverá ser adicionada regressão de dataset por papel autorizado.

## Ação 4 — impedir autoatribuição/mutação direta de owner e preservar governança do vínculo

O roadmap já exigia que usuário autenticado não pudesse se autoatribuir owner por payload/REST/RPC e que alteração de ownership não ocorresse por caminho direto. A reauditoria transformou esse critério em teste permanente próprio.

Novo teste:

`supabase/tests/database/c06_1_owner_mutation_governance.test.sql`

Commit do teste:

`1c6b0dc10e7b36cfd5963ee7432bee45cbeb4682`

Hardening do smoke REST:

`.github/scripts/test-safra-direct-api.sh`

Commit:

`2f5032767cddb96b7e61787049afcd75f73962c2`

Cobertura:

- `authenticated` sem INSERT/UPDATE/DELETE em `scenario_owners`;
- `anon` sem INSERT/UPDATE/DELETE em `scenario_owners`;
- browser roles sem grants nas fontes privadas de RBAC;
- 0 RPC público de assign/reassign/set/change owner;
- `anon` e `authenticated` sem EXECUTE no guard privado de histórico;
- trigger `trg_00_scenario_owners_history` ativo;
- owner_id de vínculo existente é imutável;
- histórico de ownership não pode ser apagado fisicamente;
- tentativa direta POST em `scenario_owners` pela Data API = DENIED;
- tentativa direta PATCH em `scenario_owners` pela Data API = DENIED.

PRIMARY:

- `browser_owner_write_grants = 0`;
- `browser_private_rbac_grants = 0`;
- `public_owner_mutation_rpcs = 0`;
- `owner_history_trigger_count = 1`.

CI:

```text
C06_1_ACTION_04 = PASS
PGTAP_ACTION_04 = 13/13
DIRECT_OWNER_POST = DENIED
DIRECT_OWNER_PATCH = DENIED
OWNER_HISTORY_REWRITE = DENIED
OWNER_HISTORY_DELETE = DENIED
```

Observação de escopo: ainda não existe RPC/UI produtivo de reatribuição de owner. Isso é deny-by-default, não uma implementação antecipada de governança. Quando um fluxo produtivo de mudança de owner for criado, ele deverá ser server-side, autorizado, auditável e preservar o histórico temporal.

## Rebuild, rollback e drift

Database Disposable Run 125 confirmou:

- Matrix v3 reconciliation contract = PASS;
- stack descartável iniciada = PASS;
- rebuild pelas migrations canônicas = PASS;
- todos os testes de banco = PASS;
- Data API negativa = PASS;
- RPC negativa = PASS;
- rollback da migration mais recente = PASS;
- rebuild pós-rollback = PASS;
- lint do banco = PASS;
- teardown limpo = PASS.

GitHub e PRIMARY possuem as mesmas 17 migrations canônicas observadas nesta reauditoria.

```text
MIGRATION_DRIFT = 0
```

## Gate final

Não foi encontrado bloqueador técnico ou de autorização no escopo do C06.1.

Dívida deliberadamente fora deste gate:

- read API governada do catálogo Safra ainda não existe;
- paridade positiva UI x dataset será testada quando essa superfície for criada;
- fluxo produtivo de reatribuição de owner ainda não existe e não deve ser antecipado por RPC permissivo.

Esses itens não invalidam o ownership atual nem a segurança deny-by-default.

## Handoff

```text
SAFRA-C06.1 = CONCLUIDO
OWNERSHIP_REAL = PASS
AUTHORIZATION_COHERENCE = PASS
DIRECT_OWNER_MUTATION = DENIED
MIGRATION_DRIFT = 0
NEXT_PHASE = SAFRA-C07
```
