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

**Estado:** CLOSED / PASS em 27/09/2026 às 20:04 BRT  
**Severidade original:** HIGH / AUTHZ

A correção foi implementada pela migration canônica `20260927214303_c02_threat_model_authz_hardening.sql`, integrada pelo PR #8 e verificada no Lovable Cloud PRIMARY.

Controles finais:

- `private.safra_has_role(text)` exige `public.safra_is_corporate_user()`;
- `private.get_my_safra_roles()` retorna lista vazia quando o predicado corporativo canônico falha;
- `public.get_safra_rbac_audit_events(integer)` exige sessão corporativa canônica e role administrativa válida;
- os wrappers públicos `public.safra_has_role(text)` e `public.get_my_safra_roles()` herdam a decisão das funções privadas governadas;
- domínio externo não reutiliza role vinculada ao `sub`;
- sessão revogada/inexistente não reutiliza role vinculada ao `sub`;
- JWT expirado não reutiliza role vinculada ao `sub`.

Evidência automatizada:

- `supabase/tests/database/c02_threat_model_authz.test.sql`;
- cenário de domínio externo: PASS;
- cenário de sessão revogada/inexistente: PASS;
- cenário de JWT expirado: PASS;
- cenário positivo de admin corporativo válido: PASS;
- Database Disposable do head final do PR #8: SUCCESS;
- App Smoke do head final do PR #8: SUCCESS.

Evidência direta no PRIMARY em 27/09/2026 às 20:04 BRT:

| Cenário | Predicado corporativo | `safra_has_role(platform_admin)` | roles retornadas | audit rows |
|---|---:|---:|---:|---:|
| domínio externo | false | false | 0 | 0 |
| sessão revogada/inexistente | false | false | 0 | 0 |
| JWT expirado | false | false | 0 | 0 |

**Conclusão:** o bypass originalmente confirmado foi fechado. `AUTHZ-001` deixa de estar bloqueado por C02-AUD-01, mas a recertificação global do C02 continua pendente até a revisão dos demais achados.

### C02-AUD-02 — abuse cases citados, mas não definidos canonicamente

**Estado:** CLOSED / PASS em 27/09/2026  
**Severidade original:** MEDIUM / MODELAGEM

Os abuse cases foram consolidados **na própria fonte canônica** `docs/PRIVACIDADE_THREAT_MODEL.md`, sem criação de documentação paralela.

Cada caso agora possui obrigatoriamente:

- ID;
- pré-condição;
- ação maliciosa/abuso;
- resultado esperado;
- controle;
- fase responsável;
- teste/evidência.

Foram formalizados START, END, CANCEL, autorização/RBAC, owner, criticidade, Data API, mutação direta, vazamento/enumeração, tempo, versionamento, retry/concorrência, SLA e 12º card.

**Conclusão:** os IDs `AB-*` deixaram de ser referências retrospectivas soltas e passaram a ser contratos canônicos rastreáveis.

### C02-AUD-03 — riscos residuais desatualizados

**Estado:** CLOSED / PASS em 27/09/2026  
**Severidade original:** MEDIUM / DOCUMENTAÇÃO

A seção `Riscos residuais do SAFRA-C02` do `docs/PRIVACIDADE_THREAT_MODEL.md` foi reconciliada com os controles efetivamente materializados em C04–C08.

Atualizações principais:

- START classificado como controlado;
- autorização/sessão RBAC classificada como `CONTROLLED_VERIFIED_C02_AUD`;
- Data API tratada como superfície controlada por revoke + RLS + smoke;
- retry/concorrência ligado a idempotência, unique key e advisory lock;
- integridade temporal ligada a server clock, append-only e C07;
- histórico ligado a owner/version guards + snapshot;
- END/CANCEL permanecem com implementação funcional deferida, mas contrato de ameaça definido;
- notificações permanecem deferidas a M05;
- privacidade/base legal permanece fechada por D-49.

**Conclusão:** risco ainda futuro/deferido não é confundido com controle ausente.

### C02-AUD-04 — ausência de teste concorrente real de START

**Estado:** CLOSED / PASS em 27/09/2026 às 20:12 BRT  
**Severidade original:** MEDIUM / TESTE

Foi criado o teste concorrente real:

`.github/scripts/test-safra-start-concurrency.sh`

O teste abre **duas transações simultâneas** contra `public.safra_start_treatment` usando:

- mesmo cenário;
- mesma identidade corporativa;
- mesma `start_idempotency_key`;
- mesmo payload.

Contrato validado:

- as duas chamadas resolvem para o mesmo `treatment_id`;
- existe exatamente **1** linha em `public.treatments` para a chave;
- existe exatamente **1** evento `TREATMENT_OPENED`;
- o lock `pg_advisory_xact_lock` + unique key + lógica idempotente impedem double submit real.

Evidência do Database Disposable `36356284282`:

`PASS C02 concurrent START retry: same treatment cf66bb23-ec8a-4e17-9dc6-c6fce0aa4fe0, one treatment row, one opening event.`

**Conclusão:** concorrência real de START está coberta por regressão automatizada permanente.

### C02-AUD-05 — conflito de idempotência sem teste explícito

**Estado:** CLOSED / PASS em 27/09/2026 às 20:12 BRT  
**Severidade original:** MEDIUM / TESTE

Foi adicionado teste pgTAP explícito em:

`supabase/tests/database/c02_threat_model_authz.test.sql`

Fluxo validado:

1. START válido cria a tratativa usando uma `start_idempotency_key`;
2. a mesma chave é reutilizada com payload diferente;
3. a RPC deve rejeitar com SQLSTATE `22023`;
4. a mensagem esperada é `SAFRA_START_IDEMPOTENCY_CONFLICT`;
5. a tratativa original permanece a fonte válida.

A suíte passou no Database Disposable `36356284282`:

- `c02_threat_model_authz.test.sql ... ok`;
- **26 asserts C02** concluídos;
- suíte de banco total: **Files=26, Tests=369**;
- o mesmo teste passou novamente após rollback/rebuild.

**Conclusão:** reutilização conflitante de idempotency key deixou de ser apenas lógica implementada e passou a ter regressão automatizada explícita.

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

**Estado:** CLOSED / CONTRACT_DEFINED — IMPLEMENTAÇÃO FUNCIONAL DEFERIDA  
**Severidade original:** MEDIUM / MODELAGEM

Os contratos de abuso foram formalizados no `docs/PRIVACIDADE_THREAT_MODEL.md` sem antecipar implementação funcional.

Contratos registrados:

- `AB-END-01`: END apenas de ACTIVE, repetição/terminal rejeitados, ator e timestamp server-side e idempotência futura obrigatória;
- `AB-CANCEL-01`: motivo obrigatório, apenas de ACTIVE, sem apagar histórico, sem converter CANCEL em sucesso de SLA e idempotência futura obrigatória;
- `AB-CARD-01`: proposta permanece separada do cenário produtivo, sem autopublicação e com governança humana obrigatória.

Fases responsáveis:

- END/CANCEL: F01/F02;
- 12º card/publicação governada: M10.

A fonte canônica também registra os testes que deverão existir antes do PASS funcional dessas fases.

**Conclusão:** o threat model está pronto antes da implementação, sem invadir o roadmap funcional.

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
