# ROLLBACK E BANCO DESCARTÁVEL — Painel Safra

> Documento operacional do SAFRA-C05.
> Fonte canônica de schema: `supabase/migrations`.

## 1. Objetivo

Definir:

1. como validar migrations em ambiente descartável antes de confiar nelas;
2. quando rollback físico é permitido;
3. quando rollback deve ser substituído por forward fix;
4. como preservar histórico e evitar perda de dados;
5. como separar PRIMARY de qualquer ambiente de teste.

## 2. Regra principal

O Lovable Cloud PostgreSQL/Supabase é o banco PRIMARY.

Nunca usar o PRIMARY como banco descartável.

O ambiente descartável padrão do projeto é o Supabase local iniciado por CLI/Docker.

Fluxo:

```text
Git checkout
 -> supabase start
 -> supabase db reset --local
 -> aplica supabase/migrations do zero
 -> aplica supabase/seed.sql
 -> supabase test db
 -> supabase db lint --local --level error
 -> supabase stop --no-backup
```

O banco local pode ser destruído e recriado a qualquer momento.

## 3. Fonte de verdade

```text
supabase/migrations = única fonte canônica de schema/migrations
supabase/seed.sql = dados exclusivamente sintéticos/locais
supabase/tests = testes de banco
Drizzle = tooling auxiliar sem autoridade de deploy
```

Não copiar dados produtivos para `seed.sql`.

## 4. Rollback antes de dados produtivos

Enquanto uma migration ainda não atingiu dados produtivos e não possui dependências externas:

- rollback físico pode ser feito por uma migration explícita;
- o rollback deve remover somente os objetos introduzidos pela mudança;
- nunca editar/apagar uma migration já publicada no histórico para “voltar atrás”;
- nunca reescrever histórico Git publicado;
- validar rollback em banco descartável antes de qualquer aplicação remota.

## 5. Rollback após dados produtivos

Depois que C06 inserir cenários reais ou houver treatments/eventos produtivos:

- não usar DROP destrutivo como rollback padrão;
- não apagar histórico operacional;
- não remover versões publicadas ou treatments por cascade;
- aplicar forward fix por nova migration;
- preservar IDs, snapshots e eventos;
- quando necessário, desativar funcionalidade por feature flag/policy/RPC sem destruir dados;
- qualquer correção administrativa deve gerar trilha auditável.

## 6. Rollback de migrations

### Migration ainda não aplicada ao PRIMARY

1. corrigir o arquivo local;
2. executar `supabase db reset --local`;
3. rodar `supabase test db`;
4. rodar lint;
5. somente depois aplicar ao remoto.

### Migration aplicada ao PRIMARY sem dados produtivos dependentes

1. criar nova migration de rollback;
2. testar localmente;
3. revisar impacto;
4. aplicar forward no PRIMARY;
5. nunca remover a migration original do histórico.

### Migration aplicada com dados produtivos dependentes

1. não apagar objetos/histórico;
2. criar migration corretiva;
3. manter compatibilidade com dados existentes;
4. documentar data release/impacto;
5. executar teste de restauração quando risco justificar;
6. tratar recuperação física/backup no SAFRA-C09.

## 7. Banco descartável

O banco descartável é obrigatório para:

- nova migration;
- mudança de constraint;
- trigger;
- função/RPC;
- policy RLS;
- mudança de grants;
- alteração de relacionamento/FK;
- mudança de schema que possa afetar replay completo.

Critério mínimo:

```text
supabase db reset --local = PASS
supabase test db = PASS
supabase db lint --local --level error = PASS
```

Se qualquer um falhar, a migration não está pronta.

## 8. Testes atuais

Arquivo:

`supabase/tests/database/c05_schema_v2.test.sql`

Cobre atualmente:

- 17 tabelas do schema v2;
- RLS ativa nas 17;
- anon sem grant direto;
- authenticated sem grant direto;
- criticidade sem default;
- GI-SAFRA-001 OPEN;
- ausência de unique ACTIVE por cenário;
- service_role sem TRUNCATE.

Os testes crescerão junto com C06/C07/C08/M01+.

## 9. Seed

`supabase/seed.sql` permanece sem dados de produção.

Regras:

- somente dados sintéticos;
- nenhum e-mail pessoal real;
- nenhum token/secret;
- nenhum dump do PRIMARY;
- fixtures específicas devem preferencialmente viver dentro dos testes e usar transaction + rollback.

## 10. CI

Workflow:

`.github/workflows/database-disposable-test.yml`

Executa em push/PR para `main`:

1. checkout;
2. instala Supabase CLI;
3. sobe stack local descartável;
4. reconstrói banco do zero;
5. roda pgTAP;
6. roda lint;
7. destrói ambiente sem backup.

## 11. Limites

Este banco descartável não substitui:

- backup do PRIMARY;
- restore test do PRIMARY;
- RTO/RPO;
- disaster recovery;
- capacidade.

Esses itens pertencem ao SAFRA-C09.

## 12. Regra de promoção

Nenhuma migration futura deve ser considerada pronta sem:

```text
MIGRATION_VERSIONED
+ LOCAL_RESET_PASS
+ DB_TEST_PASS
+ DB_LINT_PASS
+ ROLLBACK/FORWARD_FIX_PLAN
+ DOCS_UPDATED
```
