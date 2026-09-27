# AUDITORIA C02 — REABERTURA CORRETIVA

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C02 — Threat model e abuso de negócio  
**Data de abertura da rodada corretiva:** 27/09/2026  
**Horário:** 18:37 BRT  
**Estado:** EM EXECUÇÃO  
**Natureza:** reauditoria de ameaças, autorização, integridade temporal, duplicidade, controles e testes contra o estado atual do código e do Lovable Cloud PRIMARY

---

## 1. Objetivo

Revalidar o fechamento histórico do SAFRA-C02 contra o estado atual da aplicação, cobrindo código, hooks, funções, RPCs, migrations, RLS, grants, Data API, testes, audit trail, idempotência, integridade temporal e riscos residuais.

O fechamento histórico do C02 não é apagado. Esta rodada registra uma nova fotografia após a implementação de C04–C08.

## 2. Escopo obrigatório da reauditoria

1. Mapear abuse cases do domínio: START indevido/duplicado, END prematuro/repetido e CANCEL usado para mascarar histórico.
2. Mapear ameaças de autorização e bypass: owner/criticidade, Data API/RPC, enumeração e vazamento.
3. Mapear integridade temporal/histórica: timestamps, edição retroativa e versionamento com tratativas ativas.
4. Mapear duplicidade/manipulação: retry, double submit, tentativa de parar SLA e publicação indevida do 12º card.
5. Associar controles: RLS, autorização server-side, versionamento, append-only, constraints, role mapping, correlation ID, idempotência e minimização.
6. Derivar testes positivos, negativos, concorrência/retry e limites/bordas temporais.
7. Revalidar risco residual e os gates `G3.5`, `THREAT-001` e `AUTHZ-001`.

## 3. Achados da abertura

### C02-AUD-01 — RPCs de RBAC sem predicado corporativo completo

**Estado:** OPEN  
**Severidade:** HIGH / AUTHZ

Teste controlado no PRIMARY confirmou que um JWT sintético com `sub` pertencente a principal com role, mas com domínio externo e `session_id` inexistente, produz simultaneamente:

- `public.safra_is_corporate_user() = false`;
- `public.get_my_safra_roles()` retornando role governada;
- `public.get_safra_rbac_audit_events(5)` retornando registros de auditoria para principal com role administrativa.

Conclusão: os RPCs de RBAC precisam exigir o mesmo predicado canônico de sessão corporativa usado pelo fluxo Safra.

### C02-AUD-02 — abuse cases citados, mas não definidos canonicamente

**Estado:** OPEN  
**Severidade:** MEDIUM / MODELAGEM

A documentação retrospectiva cita IDs como `AB-API-01`, `AB-DATA-01`, `AB-LEAK-01`, `AB-RETRY-01` e `AB-SLA-01`, porém não há definição canônica rastreável desses casos nos documentos centrais.

### C02-AUD-03 — riscos residuais desatualizados

**Estado:** OPEN  
**Severidade:** MEDIUM / DOCUMENTAÇÃO

A tabela de riscos residuais ainda marca diversos controles como `DEFERRED_CONTROL`, embora C04–C08 já tenham materializado RLS, RBAC, guards temporais, versionamento, START transacional e engine de SLA.

### C02-AUD-04 — ausência de teste concorrente real de START

**Estado:** OPEN  
**Severidade:** MEDIUM / TESTE

O START usa `pg_advisory_xact_lock`, chave única e retry idempotente, mas a suíte atual comprova retry sequencial e não duas transações concorrentes disputando a mesma chave.

### C02-AUD-05 — conflito de idempotência sem teste explícito

**Estado:** OPEN  
**Severidade:** MEDIUM / TESTE

A RPC implementa `SAFRA_START_IDEMPOTENCY_CONFLICT` quando a mesma chave chega com payload/ator/cenário divergente, mas não há caso pgTAP específico para esse contrato.

### C02-AUD-06 — smoke HTTP não cobre toda a superfície Data API

**Estado:** OPEN  
**Severidade:** MEDIUM / AUTHZ TEST

O smoke anônimo atual cobre somente parte das tabelas. O schema Safra possui 17 tabelas centrais com RLS/deny-by-default e a cobertura HTTP deve ser ampliada para detectar regressões de grant/exposição.

### C02-AUD-07 — EXECUTE legado desnecessário em trigger functions

**Estado:** OPEN  
**Severidade:** LOW / HARDENING

`public.set_updated_at()` e `public.validate_incident_timestamps()` ainda aparecem executáveis por `anon`/`authenticated`. São trigger functions e não foi observada exploração prática, mas o privilégio é desnecessário e deve ser revogado explicitamente.

### C02-AUD-08 — matriz de paridade desatualizada

**Estado:** OPEN  
**Severidade:** LOW / DOCUMENTAÇÃO

`docs/MATRIZ_PARIDADE.md` ainda registra `START/END server-side = não`; START já está implementado por RPC governada e precisa ser separado de END/CANCEL.

### C02-AUD-09 — contratos de abuso futuros para END/CANCEL/12º card

**Estado:** OPEN / IMPLEMENTAÇÃO FUNCIONAL DEFERIDA  
**Severidade:** MEDIUM / MODELAGEM

END, CANCEL e 12º card ainda não possuem command/RPC produtivo. Nesta rodada, o threat model e os testes esperados serão formalizados, mas a implementação funcional continuará na fase própria do roadmap.

### C02-AUD-10 — imutabilidade de treatment terminal

**Estado:** OPEN  
**Severidade:** HIGH / INTEGRIDADE HISTÓRICA

Durante a execução foi identificado que o status terminal já era protegido, porém uma linha `RESOLVED`/`CANCELLED` ainda poderia ter campos históricos reescritos por caminho privilegiado sem mudar o status, por exemplo `cancellation_reason` ou timestamps de fechamento.

**Direção corretiva:** tornar qualquer UPDATE posterior ao estado terminal inválido; correções posteriores devem ser representadas exclusivamente por evento append-only (`ADMIN_CORRECTION_RECORDED`/evento governado), preservando a evidência original.

## 4. Controles já confirmados na abertura

- 17 tabelas do domínio Safra com RLS habilitada;
- sem grants diretos `SELECT/INSERT/UPDATE/DELETE` a `anon`/`authenticated` nas 17 tabelas centrais auditadas;
- START com validação corporativa server-side;
- actor do START derivado de `auth.uid()`;
- owner/versão/área resolvidos no banco;
- timestamps oficiais server-side;
- snapshot de `scenario_version_id`, owner e área no START;
- `start_idempotency_key` única;
- `pg_advisory_xact_lock` no START;
- `correlation_id` persistida;
- version freeze de cenário publicado/retirado;
- histórico de ownership protegido contra rewrite/delete;
- `treatment_events` append-only e com server clock;
- tratamento não pode ser apagado fisicamente;
- END/CANCEL somente de `ACTIVE` no persistence guard;
- CANCEL exige motivo;
- SLA não considera CANCEL como sucesso;
- snapshots históricos ignoram eventos futuros.

## 5. Decisão de execução

Em **27/09/2026 às 18:37 BRT**, foi autorizado iniciar as alterações do C02-AUD.

Direção aprovada para a execução:

1. corrigir imediatamente o bypass dos RPCs de RBAC;
2. consolidar abuse cases no documento canônico existente, sem criar fonte concorrente;
3. atualizar riscos residuais conforme controles já implementados;
4. criar testes de concorrência e conflito de idempotência do START;
5. ampliar smoke de Data API/RPC e remover EXECUTE legado desnecessário;
6. corrigir a matriz de paridade;
7. modelar END/CANCEL/12º card sem antecipar sua implementação funcional;
8. reexecutar App Smoke + Database Disposable;
9. revalidar o PRIMARY;
10. somente então recertificar `G3.5`, `THREAT-001` e `AUTHZ-001`.

## 6. Regra de fechamento

A reauditoria somente poderá ser marcada como concluída quando:

- C02-AUD-01 a C02-AUD-10 estiverem corrigidos ou formalmente classificados/deferidos;
- os testes derivados estiverem versionados e verdes;
- a superfície Data API/RPC auditada estiver coerente com deny-by-default;
- o bypass de RBAC estiver comprovadamente fechado;
- riscos residuais estiverem atualizados;
- os gates `G3.5`, `THREAT-001` e `AUTHZ-001` puderem ser recertificados por evidência atual;
- documentação e `PROJECT_PROFILE` refletirem o estado real.

> **C02 permanece historicamente fechado; C02-AUD está EM EXECUÇÃO e não está recertificado.**
