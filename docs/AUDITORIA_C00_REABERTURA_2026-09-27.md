# AUDITORIA C00 — REABERTURA CORRETIVA

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C00 — Baseline e contenção P0  
**Data de abertura:** 27/09/2026  
**Horário de abertura:** 11:26 BRT  
**Estado:** CONCLUÍDA  
**Natureza:** reauditoria técnica e rodada corretiva pós-fechamento  
**Data de fechamento:** 27/09/2026  
**Horário de fechamento:** 13:15 BRT

---

## 1. Motivo da reabertura

O SAFRA-C00 havia sido encerrado com evidências de contenção P0. Em 27/09/2026 foi iniciada uma nova auditoria sobre o estado atual do repositório para verificar se evoluções posteriores preservaram os controles originalmente aprovados e se havia resíduos técnicos, regressões ou dívida de engenharia em hooks, funções, migrations, CI e código legado.

A reabertura **não invalida o fechamento histórico do C00**. Ela registra uma nova rodada de garantia sobre o estado atual do sistema.

---

## 2. Resultado da reauditoria antes das correções

### C00 original

| Ação | Resultado da reauditoria |
|---|---|
| Preservar baseline e histórico Git | PASS |
| Remover `.env` do tracking e tratar exposição | PASS |
| Bloquear acesso `anon` | PASS |
| Habilitar RLS e remover policies abertas | PASS para contenção P0 |
| Testar acesso não autorizado | PASS histórico, com cobertura automatizada atual a reforçar |

### Evidências confirmadas

- baseline `8c38efe9a8ef73a9469083baf16fc33bc82b5b96` permanece ancestral de `main`;
- `main` está 439 commits à frente e 0 atrás da baseline auditada;
- `.env` permanece fora do tracking;
- `.gitignore` protege `.env` e `.env.*`;
- `.env.example` contém apenas placeholders;
- histórico do `.env` auditado não revelou `service_role`, `sb_secret_` ou JWT privilegiado;
- `anon` permanece sem grants nas estruturas protegidas auditadas;
- policies permissivas originais `USING (true)` foram removidas;
- `supabase/tests/database/c00_security_regression.test.sql` permanece verde no banco descartável;
- o Database Disposable Test atual reconstrói as migrations canônicas e mantém os testes de segurança verdes.

---

## 3. Pendências abertas nesta rodada

### C00-AUD-01 — Reforçar teste HTTP direto do legado

**Estado:** CLOSED

O smoke HTTP atual testa as estruturas novas do schema v2 e RPCs governadas, mas não testa diretamente:

- `public.applications`;
- `public.incidents`.

**Execução concluída:** `applications` e `incidents` foram incluídas no smoke HTTP anônimo. No pipeline descartável, ambas responderam `HTTP 401`, transformando a contenção histórica em regressão automatizada.

**Objetivo:** transformar a evidência histórica do C00 em regressão automática e repetível no pipeline atual.

---

### C00-AUD-02 — Restaurar menor privilégio no write-path legado

**Estado:** CLOSED

O C00 restringiu operações de `authenticated` em `public.incidents` por coluna. O C04 posteriormente passou a conceder `SELECT, INSERT, UPDATE` na tabela inteira para usuários autenticados sujeitos à autorização corporativa.

Isso **não reabre o acesso anônimo P0**, mas reduz o princípio de menor privilégio originalmente estabelecido.

O legado continua funcionalmente referenciado pelas telas e hooks de:

- visão geral;
- histórico de incidentes;
- aplicações;
- indicadores;
- detalhe de incidente;
- `useApplications()`;
- `useIncidents()`;
- `useIncident()`;
- `useUpdateIncident()`.

**Execução concluída:** a migration canônica `20260927154505_c00_restore_legacy_least_privilege.sql` restaurou grants por coluna no write-path legado. `useUpdateIncident()` passou a aceitar somente um DTO restrito aos campos legados editáveis. A migration foi validada no banco descartável e promovida ao Lovable Cloud PRIMARY, preservando as policies corporativas do C04.

---

### C00-AUD-03 — Limpeza de lint e transformação do lint em gate real

**Estado:** CLOSED

O pipeline atual executa:

`Lint legacy baseline`

com `continue-on-error: true`.

A execução auditada encontrou:

- **956 problemas**;
- **949 erros**;
- **7 warnings**;
- **948 erros potencialmente corrigíveis automaticamente**.

A maior parte corresponde a formatação/Prettier, não a falhas funcionais. Mesmo assim, o estado atual permite um pipeline verde com lint vermelho.

**Execução concluída:**

1. os erros mecânicos/Prettier foram saneados sem alteração de regra de negócio;
2. arquivos gerados pelo Lovable/Supabase foram explicitamente excluídos da análise em vez de editados;
3. as exportações intencionais de helpers junto a componentes receberam exceções locais documentadas;
4. `continue-on-error` foi removido do workflow;
5. o script passou a executar `eslint . --max-warnings=0`;
6. App Smoke, typecheck e build passaram com o lint como gate bloqueante de zero warnings.

---

### C00-AUD-04 — Remover ou justificar hook legado sem consumidor

**Estado:** CLOSED

`useStartIncident()` permanece em `src/lib/queries.ts`, enquanto o fluxo atual de START usa:

- `useSafraStartCatalog()`;
- `useSafraStartTreatment()`;
- RPCs governadas do schema v2.

Na auditoria atual não foi identificado consumidor ativo de `useStartIncident()` nas rotas versionadas.

**Execução concluída:** a ausência de consumidor ativo foi confirmada no código versionado e `useStartIncident()` foi removido. O START atual permanece exclusivamente no fluxo governado `useSafraStartCatalog()` + `useSafraStartTreatment()`/RPC.

---

## 4. Ordem de execução

A rodada corretiva será executada nesta sequência:

1. **C00-AUD-01** — reforçar regressão HTTP de `applications/incidents`;
2. **C00-AUD-02** — restaurar menor privilégio no legado e estreitar DTO/hook;
3. **C00-AUD-03** — limpar lint e torná-lo bloqueante;
4. **C00-AUD-04** — confirmar e remover código morto;
5. repetir testes de banco, Data API, RPC, typecheck, build e lint;
6. registrar evidências e fechar a reauditoria.

---

## 5. Gate de fechamento

Esta reauditoria só poderá ser marcada como concluída quando:

- os quatro itens C00-AUD estiverem fechados ou formalmente reclassificados;
- `anon` continuar negado;
- RLS continuar ativa;
- nenhum segredo privilegiado estiver versionado;
- baseline Git continuar preservada;
- banco descartável estiver verde;
- typecheck estiver verde;
- build estiver verde;
- lint estiver verde e bloqueante;
- documentação registrar data, hora, commits e evidências finais.

---

## 6. Decisão registrada

Em **27/09/2026 às 11:26 BRT**, foi autorizado **iniciar as alterações corretivas decorrentes da reauditoria do SAFRA-C00**.

A rodada corretiva foi executada integralmente e fechada em **27/09/2026 às 13:15 BRT**.

> **C00 historicamente encerrado e reauditoria corretiva C00-AUD concluída com evidências.**

O SAFRA-C08 não apaga nem substitui esta trilha de auditoria; todas as evidências históricas anteriores permanecem preservadas.

---

## 7. Evidências de fechamento

### Git / revisão

- PR #1 — `C00-AUD: close corrective security and code-quality items`: **MERGED**.
- Merge commit PR #1: `3eb1f59eae767bf50142bef80e7a3905e3088964`.
- PR #2 — `C00-AUD: require zero-warning lint`: **MERGED**.
- Merge commit PR #2: `facd2f35ecd7ad52b7f627d2b5e1ff2d61a090ec`.
- nenhum force-push, rebase destrutivo ou edição retroativa de migration publicada foi utilizado.

### C00-AUD-01

- `.github/scripts/test-safra-direct-api.sh` inclui `applications` e `incidents`;
- evidência do Database Disposable Test:
  - `applications -> HTTP 401`;
  - `incidents -> HTTP 401`.

### C00-AUD-02

- migration canônica: `supabase/migrations/20260927154505_c00_restore_legacy_least_privilege.sql`;
- `public.applications`: autenticado permanece somente leitura;
- `public.incidents`: escrita autenticada limitada a colunas explicitamente necessárias;
- `anon`: SELECT/INSERT/UPDATE/DELETE continuam negados;
- RLS continua habilitada em `applications` e `incidents`;
- PRIMARY registra a versão `20260927154505 / c00_restore_legacy_least_privilege`;
- o teste pgTAP C00 passou antes e depois do ensaio de rollback/rebuild.

### C00-AUD-03

- baseline inicial da reauditoria: **956 problemas de lint (949 erros, 7 warnings)**;
- `continue-on-error` removido;
- lint passa a ser gate obrigatório;
- comando canônico: `eslint . --max-warnings=0`;
- App Smoke do PR #2: **SUCCESS**;
- typecheck: **SUCCESS**;
- build: **SUCCESS**.

### C00-AUD-04

- `useStartIncident()` removido após confirmação de ausência de consumidor;
- fluxo START atual permanece governado por RPC, sem retorno ao insert legado direto.

### Pipelines

PR #1:
- App Smoke Test `36330896012`: **SUCCESS**;
- Database Disposable Test `36330896089`: **SUCCESS**.

Após merge do PR #1 em `main`:
- App Smoke Test `36331185946`: **SUCCESS**;
- Database Disposable Test `36331186024`: **SUCCESS**.

PR #2:
- App Smoke Test `36332169772`: **SUCCESS**;
- Database Disposable Test `36332169798`: **SUCCESS**.

---

## 8. Resultado final do gate

| Critério | Resultado |
|---|---|
| C00-AUD-01 fechado | PASS |
| C00-AUD-02 fechado | PASS |
| C00-AUD-03 fechado | PASS |
| C00-AUD-04 fechado | PASS |
| anon negado | PASS |
| RLS ativa | PASS |
| segredo privilegiado versionado | NÃO IDENTIFICADO |
| baseline/histórico Git preservados | PASS |
| banco descartável | PASS |
| Data API/RPC anônimos negados | PASS |
| rollback/rebuild | PASS |
| typecheck | PASS |
| build | PASS |
| lint bloqueante e zero-warning | PASS |
| PRIMARY alinhado à migration corretiva | PASS |

**Decisão de fechamento:** não restou pendência bloqueante ou corretiva aberta dentro do escopo C00-AUD.
