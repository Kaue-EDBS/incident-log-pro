# C06.02 — Pipeline canônico da Matriz v3

## Fluxo

```text
XLSX v3
-> parser versionado
-> staging
-> validação
-> preview diff
-> aprovação humana
-> seed/migration
-> reconciliação
```

## Fonte aceita

- nome lógico: `EDB06 - Matriz Contingencia v3.xlsx`;
- aba: `Matriz de Contingência`;
- SHA256 aprovado: `b0cca8cce835dbdc65ab0c30212fd89480d2cf51e9fb62d215ad1bde0963ead6`.

O parser falha se o hash esperado não corresponder ao arquivo fornecido.

## Parser

Arquivo:

`scripts/c06_matrix_pipeline.py`

Versão:

`1.0.0`

Responsabilidades:

- validar cabeçalhos;
- identificar os 11 cenários;
- reconstruir as cinco linhas de protocolo por cenário;
- normalizar códigos `SAFRA-01..SAFRA-11`;
- preservar texto da fonte;
- validar owners canônicos;
- detectar lacunas já conhecidas como governance issues;
- não inferir criticidade;
- não inferir SLA estruturado.

## Artefatos

- `c06_matriz_v3_staging.json` — saída normalizada do XLSX;
- `c06_matriz_v3_validation.json` — erros/warnings;
- `c06_primary_before_replay.json` — fotografia anterior do PRIMARY;
- `c06_matriz_v3_preview_diff.json` — diferenças propostas;
- `c06_matriz_v3_human_approval.json` — gate humano;
- `c06_matriz_v3_reconciliation.json` — resultado pós-seed.

Todos em `docs/data-contracts/`.

## Regras de gate

### Validação

A publicação não segue se houver erro estrutural.

Warnings de governance issues podem permanecer somente quando:

- estão formalmente registrados;
- o parser preserva o texto original;
- nenhum valor é inferido.

### Preview diff

`NO_DIFF`:

- replay pode seguir com aprovação humana;
- nenhuma nova migration de negócio é necessária se a migration canônica já estiver aplicada.

`DIFF_REQUIRES_HUMAN_REVIEW`:

- processo para;
- nenhuma seed/migration é aplicada automaticamente;
- o operador precisa aprovar cada mudança material.

## Seed/migration atual

`supabase/migrations/20260925213118_c06_seed_canonical_matrix_v3.sql`

Como o replay C06.02 resultou em zero diferença, esta migration continua sendo a fonte canônica. Não foi criada migration duplicada/no-op.

## Regressão RBAC/ownership

Teste:

`supabase/tests/database/c06_02_rbac_ownership.test.sql`

Valida:

- owner exato dos 11 cenários;
- Jair sem ownership;
- Bruno sem ownership;
- platform admins sem ownership automático;
- admin não herda `scenario_owner`;
- `authenticated` não pode INSERT/UPDATE/DELETE em `scenario_owners`;
- RLS continua ligada;
- ausência de policy de mutação direta.

A Data API também testa acesso direto a `scenario_owners`.

## Resultado do replay de 25/09/2026

- staging: 11;
- erros: 0;
- warnings: 5, todos governance issues conhecidos;
- preview diff: 0;
- approval: aprovada para replay sem mudança de negócio;
- migration nova: não necessária;
- reconciliação PRIMARY: PASS.

Próxima fase após CI verde: `SAFRA-C07`.
