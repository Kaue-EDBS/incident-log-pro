# SAFRA-C06.1 — Evidência de leitura e autorização entre UI, REST/RPC e banco

Data: 26/09/2026

## Objetivo

Comprovar que as camadas atuais não possuem regras concorrentes de autorização e que nenhuma delas consegue contornar o modelo canônico de identidade/RBAC/RLS.

Esta evidência não declara que a UI Safra já consome os 11 cenários. Nesta fase, a leitura do catálogo Safra permanece **deny-by-default** e ainda não há RPC público de leitura de cenário.

## Regra canônica

```text
Microsoft session
-> UI session gate
-> publishable Supabase client / bearer token
-> server middleware when serverFn is used
-> public.safra_is_corporate_user()
-> governed role predicates where applicable
-> Postgres grants + RLS
-> domain tables
```

Nenhuma camada pode:
- usar service_role no browser;
- usar user_metadata como autorização;
- liberar cenário/owner apenas porque a UI esconde ou mostra algo;
- criar leitura direta de scenarios/scenario_owners sem contrato governado;
- permitir anon por REST ou RPC.

## Matriz de evidência

| Camada | Evidência | Resultado |
|---|---|---|
| UI | `AuthedShell` redireciona sessão ausente para `/auth` | PASS |
| UI | browser usa somente publishable key | PASS |
| UI | service_role não aparece no client browser | PASS |
| UI | não há leitura direta de `scenarios` ou `scenario_owners` | PASS / deny-by-default preservado |
| UI | não há autorização por `user_metadata` | PASS |
| Server middleware | Bearer é validado e `safra_is_corporate_user()` é consultado | PASS |
| REST/Data API | anon sem SELECT em catálogo/ownership Safra | PASS |
| REST/Data API | authenticated sem SELECT direto enquanto não existe read API governada | PASS |
| REST/Data API | RLS habilitada nas 5 tabelas de catálogo/ownership auditadas | PASS |
| RPC | anon sem EXECUTE em `safra_is_corporate_user`, `get_my_safra_roles`, `safra_has_role` | PASS |
| RPC | authenticated executa somente os predicados governados previstos | PASS |
| RPC | nenhum RPC público de leitura de scenario/owner existe nesta fase | PASS / superfície mínima |
| Banco | `private.safra_principals` e `private.safra_role_grants` sem grants para browser roles | PASS |

## Testes permanentes

### Banco / RPC

`supabase/tests/database/c06_1_read_authorization_coherence.test.sql`

PRIMARY:
```text
12/12 PASS
```

Valida:
- RLS;
- grants;
- ausência de policy silenciosa de leitura;
- EXECUTE de RPC por papel;
- ausência de RPC público de cenário;
- isolamento das tabelas privadas RBAC.

### UI / middleware

`.github/scripts/check-c06-1-ui-auth-coherence.py`

App Smoke Run 83 e Run 85:
```text
PASS
```

O checker bloqueia regressões como:
- remoção do gate global de sessão;
- service_role no browser;
- ausência do predicado corporativo no middleware;
- leitura direta de scenarios/scenario_owners pela UI;
- uso de user_metadata como autorização.

### REST/Data API direto

`.github/scripts/test-safra-direct-api.sh`

Database Disposable Run 123:
```text
PASS
```

### RPC direto

`.github/scripts/test-safra-direct-rpc.sh`

Database Disposable Run 123:
```text
PASS
```

A chamada anônima direta a `/rest/v1/rpc/safra_is_corporate_user` deve retornar 401/403.

## Leitura correta do resultado

```text
AUTHORIZATION_COHERENCE = PASS
UI_AUTH_GATE = PASS
REST_DIRECT_ACCESS = DENIED
RPC_ANON_ACCESS = DENIED
DATABASE_RLS_GRANTS = PASS
SAFRA_UI_CATALOG_READ = NOT_IMPLEMENTED_YET
UI_VS_API_DATASET_PARITY = NOT_APPLICABLE_UNTIL_GOVERNED_READ_API_EXISTS
```

A ausência atual de leitura Safra na UI não é convertida em PASS de paridade de conteúdo. O que esta ação comprova é que **não existe caminho de leitura/autorização mais permissivo em UI, REST/RPC ou banco**.

Quando a read API do Safra for criada, esta action deve ganhar teste de paridade positiva do dataset retornado para cada papel autorizado.


### Fechamento CI

```text
APP_SMOKE_RUN_85 = SUCCESS
DATABASE_DISPOSABLE_RUN_123 = SUCCESS
C06_1_ACTION_03_CI = PASS
```
