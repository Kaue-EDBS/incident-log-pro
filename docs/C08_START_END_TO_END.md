# SAFRA-C08 — START end-to-end

**Data:** 27/09/2026  
**Estado:** IMPLEMENTADO / PROMOVIDO / HOMOLOGAÇÃO HUMANA PENDENTE

## Objetivo

Implementar o START real de uma tratativa Safra sem permitir que a UI invente ou sobrescreva dados de governança.

## Contrato público

### `public.safra_get_start_catalog()`

Endpoint governado para a tela Abrir Protocolo. Retorna somente cenários ACTIVE com versão PUBLISHED e o contexto necessário ao START.

### `public.safra_start_treatment(...)`

Entrada permitida:
- `scenario_id`;
- `idempotency_key` UUID;
- resumo do impacto observado;
- áreas realmente impactadas.

A UI não envia:
- `scenario_version_id`;
- owner;
- criticidade;
- área responsável;
- ator;
- timestamps.

Esses valores são resolvidos ou gerados pelo servidor.

## Transação do START

1. valida identidade corporativa;
2. serializa retries pela chave de idempotência;
3. valida cenário ACTIVE e versão PUBLISHED;
4. resolve owner ativo e área responsável;
5. valida áreas impactadas;
6. cria treatment ACTIVE;
7. congela o snapshot;
8. grava TREATMENT_OPENED;
9. retorna o snapshot do protocolo (sem SLA desde a D-75).

## Idempotência

Mesmo UUID + mesmo payload => mesmo tratamento.

Mesmo UUID + payload diferente => `SAFRA_START_IDEMPOTENCY_CONFLICT`.

## UX implementada

A rota `/novo-incidente` passou a funcionar como **Abrir Protocolo**:
- catálogo dos cenários;
- protocolo e gatilho;
- owner;
- versão;
- criticidade;
- áreas realmente impactadas;
- resumo do impacto;
- confirmação explícita;
- resultado do START;
- contador de tempo desde a abertura (só exibição; não é prazo).

> 01/10/2026: os blocos de SLA foram removidos da tela (D-62) e do retorno do START (D-75). A rota hoje é `/abrir-protocolo`.

## Segurança

Deny-by-default preservado:
- sem SELECT direto de `scenarios` pelo browser;
- sem INSERT direto de `treatments`;
- sem INSERT direto de `treatment_events`;
- anon sem EXECUTE nos RPCs;
- payload do START não expõe campos de governança.

## Evidências

```text
HEAD = c0edd12efce96a97bddff952e71546b248f1f695
MIGRATION = 20260927142000_c08_start_end_to_end.sql
APP_SMOKE_129 = SUCCESS
DATABASE_DISPOSABLE_167 = SUCCESS
C08_PGTAP = 24/24 PASS
DIRECT_DATA_API_DENIAL = PASS
DIRECT_RPC_ANON_DENIAL = PASS
ROLLBACK = PASS
DB_LINT = PASS
PRIMARY_MIGRATION_TRACKED = true
PRIMARY_STARTABLE_SCENARIOS = 11
PRIMARY_TREATMENTS_AFTER_DEPLOY = 0
LOVABLE_RUNTIME = ready
```

## Problema de CI encontrado e corrigido

Durante a implementação, o Database Disposable ficou preso em `supabase start` por limitação/rate limit do pull de containers.

Foram aplicados:
- timeout;
- cleanup defensivo;
- retry único;
- timeout também no cleanup;
- rotação da chave de concorrência do workflow.

Depois disso, o Run 167 fechou em SUCCESS.

Também foi corrigido o plano pgTAP de 22 para 24 testes; os 24 asserts funcionais passaram.

## Limites deliberados

Não resolvidos por este trabalho:
- GI-SAFRA-004 — múltiplos ACTIVE;
- GI-SAFRA-005 — comunicação produtiva;
- GI-SAFRA-009 — resolvida pela D-62; SLA aposentado pela D-75;
- valores de negócio ainda ausentes de GI-001/002/003.

## Próximo passo

Homologação humana no runtime com sessão Microsoft corporativa real.

Não alterar o backend antes dessa homologação, salvo bug comprovado.
