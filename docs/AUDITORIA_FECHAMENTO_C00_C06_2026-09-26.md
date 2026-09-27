# AUDITORIA DE FECHAMENTO — C00 a C06

Data: 26/09/2026

## Objetivo

Registrar de forma consolidada as auditorias retrospectivas executadas antes do avanço funcional do Painel Safra.

Regra aplicada:
- pendência corrigível sem decisão humana -> corrigida imediatamente;
- decisão de negócio não inferível -> WAITING_HUMAN_DECISION / governance_issues;
- item de fase futura -> permanece vinculado à fase correta;
- nenhuma fase recebe PASS por inferência.

## Resultado consolidado

| Fase | Escopo auditado | Resultado |
|---|---|---|
| C00 | Baseline e contenção P0 — 5 ações | 5/5 PASS 100% |
| C01 | Documentação canônica e PROJECT_PROFILE — 5 ações | 5/5 PASS 100% |
| C02 | Threat model e abuso de negócio — 7 ações | 7/7 PASS 100% |
| C03 | Glossário e modelo de domínio — 5 ações | 5/5 PASS 100% |
| C04 | Identidade, RBAC e RLS — 7 ações, somente escopo próprio | 7/7 PASS 100% APP_SCOPE |
| C06 | Seed canônico da Matriz v3 — 6 ações | 6/6 PASS 100% |

## C00 — Baseline e contenção P0

1. baseline/histórico Git — PASS;
2. secrets fora do versionamento — PASS;
3. anon bloqueado — PASS;
4. RLS/policies abertas corrigidas — PASS;
5. regressão de segurança legacy applications/incidents — PASS.

Correção durante auditoria:
- criado `supabase/tests/database/c00_security_regression.test.sql`;
- PRIMARY 12/12;
- Database Disposable Run 102 = SUCCESS.

## C01 — Documentação canônica e PROJECT_PROFILE

1. documentação canônica consolidada — PASS;
2. PROJECT_PROFILE completo — PASS;
3. UNKNOWN material = 0 — PASS;
4. retenção formalizada — PASS;
5. gates G3/G3.25 — PASS.

Correções:
- PROJECT_PROFILE sincronizado com C04-C07;
- final_rbac atualizado para IMPLEMENTED;
- estados antigos de governance reconciliados.

## C02 — Threat model e abuso de negócio

1. ameaças centrais — PASS;
2. abuso API/dados/retry/SLA — PASS;
3. controles + fase responsável — PASS;
4. testes positivos/negativos/concorrência/bordas — PASS;
5. contrato de evidência — PASS;
6. riscos residuais — PASS;
7. gates G3.5/THREAT-001/AUTHZ-001 — PASS.

Correção:
- threat model reconciliado com RBAC/Entra já implementados.

## C03 — Glossário e modelo de domínio

1. vocabulário canônico — PASS;
2. cenário/versão/tratativa/impacto — PASS;
3. criticidade sem inferência — PASS;
4. handoff para C05 — PASS;
5. ausência de definições concorrentes — PASS.

Correção:
- decisões antigas conflitantes foram marcadas como superseded sem apagar histórico.

## C04 — Identidade, RBAC e RLS

Escopo limitado ao próprio C04.

1. Microsoft Entra / SSO — PASS;
2. role mapping governado — PASS;
3. RLS + equivalência UI/REST/RPC/server — PASS;
4. anon + sessão inválida/expirada — PASS;
5. proteção de principals/roles + sem herança automática — PASS;
6. troca/revogação + sessão revogada + auditoria — PASS;
7. gates G5/ID-001/ID-002/AUDIT-001 — PASS APP_SCOPE.

Evidência de self-test atual:
- BASELINE = PASS;
- ROLE_CHANGE = PASS;
- ROLE_REVOCATION = PASS;
- REVOKED_SESSION = PASS;
- EXPIRED_JWT = PASS;
- VALID_SESSION = PASS;
- ROLLBACK = PASS;
- RBAC_AUDIT_TRAIL = PASS.

Fronteira externa:
- recuperação Microsoft = EXTERNAL_CORPORATE_CONTROL;
- MFA/Conditional Access = EXTERNAL_CORPORATE_CONTROL.

## C06 — Seed canônico da Matriz v3

1. fonte + parser versionado — PASS;
2. validação + preview diff + aprovação humana — PASS;
3. seed dos 11 cenários — PASS;
4. reconciliação integral — PASS 198/198;
5. ownership real persistido — PASS 11/11;
6. não inferência de criticidade/SLA/thresholds/P1-P4 — PASS.

Evidências:
- Database Run 98 = SUCCESS;
- Database Run 101 = SUCCESS;
- `MATRIX_V3_RECONCILIATION = 198/198`;
- `REAL_OWNERSHIP_LINKS = 11/11`.

## Próxima fase

SAFRA-C06.1 — Teste de ownership real

### Ação 1

**Testar ownership real dos 11 cenários usando os vínculos efetivamente persistidos no schema v2.**

Fonte técnica:

```text
public.scenarios
-> public.scenario_owners
-> private.safra_principals
-> private.safra_role_grants
```

Critério:
- exatamente 11 cenários;
- exatamente 11 vínculos ativos;
- 1 owner ativo por cenário;
- owner principal existente;
- role scenario_owner ativa;
- sem duplicidade;
- sem herança administrativa;
- assignment_reason presente;
- validação humana cenário a cenário após o teste técnico.

Estado atual:

```text
C06_1_ACTION_01_TECHNICAL = PASS
C06_1_ACTION_01_HUMAN_VALIDATION = APPROVED
```


### C06.1 — Ação 2

**Validar owner por cenário sem herança por papel administrativo e sem fallback silencioso.**

Resultado técnico:
- 10/10 testes PASS;
- 11 cenários com owner explícito;
- 0 ownership derivado de papel administrativo;
- 0 fallback silencioso;
- ausência do owner explícito bloqueia o cenário publicado;
- admin sem role `scenario_owner` não pode substituir owner;
- estado original é restaurado após os testes negativos.

```text
C06_1_ACTION_02 = PASS
ADMIN_ROLE_INHERITANCE = NONE
SILENT_OWNER_FALLBACK = NONE
```


### C06.1 — Ação 3

**Registrar evidência de leitura e autorização coerentes entre UI, REST/RPC e banco.**

Resultado:
- autorização cross-layer = PASS;
- PRIMARY = 12/12;
- App Smoke checker = PASS;
- REST anon = DENIED;
- RPC anon = DENIED;
- RLS/grants = PASS;
- nenhuma leitura direta de cenário/owner na UI;
- nenhuma paridade de dataset foi inferida antes da existência da read API governada.

```text
C06_1_ACTION_03 = PASS
AUTHORIZATION_COHERENCE = PASS
UI_VS_API_DATASET_PARITY = NOT_APPLICABLE_UNTIL_GOVERNED_READ_API
```


---

## Atualização pós-fechamento C06.1 — 27/09/2026

A fotografia de 26/09 foi reauditada após a aprovação humana e a materialização da quarta ação.

Fonte de fechamento atual:
`docs/AUDITORIA_C06_1_OWNERSHIP_2026-09-27.md`.

Resultado:

```text
C06_1_ACTION_01 = PASS
C06_1_ACTION_02 = PASS
C06_1_ACTION_03 = PASS
C06_1_ACTION_04 = PASS
APP_SMOKE_RUN_87 = SUCCESS
DATABASE_DISPOSABLE_RUN_125 = SUCCESS
MIGRATION_DRIFT = 0
SAFRA-C06.1 = CONCLUIDO
NEXT_PHASE = SAFRA-C07
```

A quarta ação formaliza a proibição já prevista de autoatribuição/mutação direta de owner:
browser roles não possuem escrita em `scenario_owners`, não existe RPC público de reatribuição,
POST/PATCH direto é negado e o histórico de ownership não pode ser reescrito ou apagado.

A ausência de read API governada do catálogo e de um fluxo produtivo de reatribuição permanece
deny-by-default e não constitui abertura de autorização.
