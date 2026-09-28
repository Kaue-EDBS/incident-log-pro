# AUDITORIA C04 — IDENTIDADE, RBAC E RLS

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C04 — Identidade, RBAC e RLS  
**Data de abertura:** 28/09/2026  
**Horário:** 07:15 BRT  
**Estado:** EM EXECUÇÃO / AGUARDANDO DECISÕES CORRETIVAS  
**Base da auditoria:** branch `audit/c03-corrections-2026-09-28` + Lovable Cloud PRIMARY  
**Dependência de merge:** esta branch é empilhada sobre a C03-AUD e não deve ser mesclada antes da conclusão da fila anterior.

---

## 1. Objetivo

Reauditar a implementação de identidade corporativa, sessão, RBAC, ownership, RLS e acesso direto REST/RPC após C05–C08 e após a limpeza do frontend Reliability no C03-AUD.

A auditoria cobre código, hooks de autenticação, funções SQL, grants, policies, RPCs, vínculos de owner e evidências de teste persistidas.

## 2. Escopo solicitado

1. Testar bloqueio total do `anon`, garantindo que não consiga ler nem escrever dados protegidos.
2. Testar sessão expirada, garantindo que nenhuma mutation produza efeito.
3. Testar usuário autenticado em START, END e CANCEL conforme as regras autorizadas.
4. Testar tentativa de elevação de privilégio via payload.
5. Testar separação dos papéis de negócio: Jair com governança global, Bruno com analytics/executive global sem permissão técnica e Jiane sem governança global.
6. Testar que `platform admin` não herda ownership automaticamente.
7. Testar acesso direto REST/RPC contra as mesmas regras da UI/RLS.

## 3. Evidência atual do PRIMARY

### 3.1 Papéis governados

- `jair.silva@editoradobrasil.com.br` → `safra_governance_admin`;
- `bruno.palhao@editoradobrasil.com.br` → `safra_executive_admin`;
- `jiane.rodrigues@editoradobrasil.com.br` → `scenario_owner`;
- Kaue, Amanda, Vinicius e João → `safra_platform_admin`.

Jair e Kaue estão atualmente vinculados a `auth.uid()` real e possuem sessão viva observada. Bruno e Jiane permanecem pré-provisionados, ainda sem `auth.uid()` real vinculado.

### 3.2 Ownership real

- Jiane possui 4 vínculos ativos: SAFRA-04, SAFRA-05, SAFRA-06 e SAFRA-08;
- Jair possui 0 cenários;
- Bruno possui 0 cenários;
- todos os quatro `safra_platform_admin` possuem 0 cenários.

### 3.3 Superfície de banco

Todas as tabelas `public` observadas estão com RLS habilitada.

`anon` possui:

- 0 SELECT;
- 0 INSERT;
- 0 UPDATE;
- 0 DELETE;

em todas as tabelas/views `public` e `private` inspecionadas.

Os RPCs Safra/RBAC públicos também permanecem sem EXECUTE para `anon`.

### 3.4 Evidência histórica controlada C04

A tabela `private.safra_c04_test_runs` possui três execuções controladas recentes. A última, em 26/09/2026 23:48 UTC, registrou 9/9 PASS.

Controles comprovados:

- JWT expirado → autorização false;
- JWT válido + sessão viva → true;
- JWT válido + session_id existente → true;
- JWT válido + session_id inexistente/revogado → false;
- role grant reconhecido imediatamente;
- role revocation reconhecida imediatamente;
- RBAC audit trail append-only com ator/ação/recurso/hora/correlation id;
- estado restaurado após self-test.

---

## 4. Resultado por ação

### C04-AUD-01 — bloqueio total do anon

**Estado:** PASS / CURRENT_PRIMARY  
**Severidade:** nenhuma pendência material

Evidências:

- nenhuma tabela/view `public` ou `private` concede CRUD a `anon`;
- `safra_get_start_catalog`, `safra_start_treatment`, `safra_is_corporate_user`, `safra_has_role`, `get_my_safra_roles` e `get_safra_rbac_audit_events` não são executáveis por `anon`;
- `.github/scripts/test-safra-direct-api.sh` cobre a superfície Data API;
- `.github/scripts/test-safra-direct-rpc.sh` cobre RPCs anônimos.

Conclusão: o controle está tecnicamente correto. A reexecução HTTP automatizada atual aguarda apenas disponibilidade de GitHub Actions.

### C04-AUD-02 — sessão expirada sem efeito de mutation

**Estado:** OPEN / TEST GAP  
**Severidade:** MEDIUM / REGRESSION COVERAGE

O predicado canônico está correto e a evidência C04 persistida prova:

- JWT expirado → false;
- sessão removida/revogada → false.

O START também valida `safra_is_corporate_user()` antes de qualquer INSERT.

Porém, não existe hoje um assert dedicado que prove diretamente:

```text
JWT expirado
→ chama mutation
→ recebe FORBIDDEN
→ zero treatment/event/efeito persistido
```

A auditoria não considera apenas inferência de código suficiente para este item porque o requisito é explicitamente “nenhuma mutation produza efeito”.

**Direção proposta:** criar regressão pgTAP explícita para START agora e tornar o mesmo teste obrigatório para END/CANCEL quando forem implementados.

### C04-AUD-03 — usuário autenticado em START, END e CANCEL

**Estado:** PARTIAL / DEFERRED_BY_PHASE  
**Severidade:** MEDIUM / COVERAGE DE FASE

START:

- PASS;
- `safra_start_treatment` é executável por `authenticated`, não por `anon`;
- usuário corporativo base pode START sem papel privilegiado;
- ator vem de `auth.uid()`;
- owner/version/área são resolvidos no servidor;
- C08 possui pgTAP positivo e negativo.

END/CANCEL:

- os RPCs `safra_end_treatment` e `safra_cancel_treatment` ainda não existem;
- a ausência é deliberada e já documentada como `DEFERRED_TO_F01/F02`;
- portanto não é possível testar autorização funcional de END/CANCEL nesta fotografia.

Achado documental associado:

- `docs/PROJECT_PROFILE.yaml` ainda registra `base_authenticated_user.can_end: true` e `can_cancel: true` sem distinguir “regra aprovada futura” de “capacidade já implementada”.

**Direção proposta:** não antecipar END/CANCEL; corrigir a semântica documental e registrar testes obrigatórios na fase de implementação correspondente.

### C04-AUD-04 — elevação de privilégio via payload

**Estado:** PASS / CURRENT_SURFACE

Evidências:

- assinatura START: `scenario_id`, `idempotency_key`, `impact_summary`, `impacted_area_ids`;
- payload não aceita `owner_id`, `scenario_version_id`, `criticality`, ator, timestamp ou papel;
- START resolve owner, versão, área responsável, ator e clocks no servidor;
- `scenario_owners` não possui grants diretos para `authenticated`;
- tabelas privadas de principal/role grant não possuem grants browser;
- role lookup depende do predicado corporativo canônico após hardening C02.

Conclusão: não foi encontrado caminho de privilege escalation via payload na superfície implementada.

### C04-AUD-05 — separação Jair / Bruno / Jiane

**Estado:** PASS NO MODELO / RUNTIME PARCIALMENTE HOMOLOGADO

Estado persistido:

- Jair → apenas `safra_governance_admin`; sem platform/executive/scenario_owner;
- Bruno → apenas `safra_executive_admin`; sem platform/governance/scenario_owner;
- Jiane → apenas `scenario_owner`; sem platform/governance/executive.

Ownership:

- Jiane: 4 cenários explícitos;
- Jair: 0;
- Bruno: 0.

Observação de homologação:

- Jair possui login real vinculado;
- Bruno e Jiane ainda não possuem `auth.uid()` real vinculado;
- o trigger de binding e o self-test de grant/revoke já comprovam a mecânica, mas login real individual de Bruno/Jiane ainda não foi observado;
- a superfície funcional de analytics global ainda não está implementada, logo neste momento valida-se o papel `safra_executive_admin`, não uma tela de analytics inexistente.

Isso não é considerado defeito do C04, mas deve ser lembrado quando analytics entrar em produção.

### C04-AUD-06 — platform admin não herda ownership

**Estado:** PASS

Evidências:

- Kaue, Amanda, Vinicius e João: 0 vínculos ativos em `scenario_owners`;
- `scenario_owner` é papel separado;
- owner publicado precisa possuir grant ativo `scenario_owner`;
- suíte `c06_1_owner_no_inheritance_no_fallback.test.sql` verifica que nenhum papel administrativo produz ownership e que principals administrativos possuem zero cenários sem vínculo explícito.

Conclusão: administração técnica e autoridade de negócio permanecem separadas.

### C04-AUD-07 — REST/RPC direto = mesmas regras da UI

**Estado:** OPEN / AUTHZ SURFACE DRIFT  
**Severidade:** MEDIUM

Superfície Safra nova:

- PASS;
- UI START chama RPC governado;
- browser não possui CRUD direto nas 17 tabelas Safra;
- anon não executa RPCs;
- middleware server-side e AuthProvider usam `safra_is_corporate_user()`.

Divergência encontrada após C03-AUD:

- o frontend Reliability foi removido;
- porém `public.applications` e `public.incidents` continuam com SELECT concedido a `authenticated`;
- policies C04 ainda permitem leitura dessas duas tabelas para qualquer sessão corporativa válida;
- PRIMARY contém atualmente 3 linhas em `applications` e 15 em `incidents`.

Portanto, um usuário corporativo pode consultar essas estruturas diretamente por REST mesmo sem existir mais UI correspondente.

Isso contradiz o novo estado arquitetural do C03, no qual essas tabelas foram classificadas como persistência histórica estacionada, não funcionalidade ativa.

**Direção proposta:** revogar SELECT de `authenticated` em `applications`/`incidents` e retirar as policies C04 legadas, preservando as tabelas no PRIMARY apenas para service_role/migration até decisão futura de remoção física.

---

## 5. Higiene de código observada

Não foi encontrado bypass novo em hooks ou funções de autenticação.

Pontos positivos:

- `AuthProvider` consulta o RPC canônico após obter sessão;
- `auth-middleware.ts` valida Bearer token, claims e o mesmo RPC canônico;
- `client.ts` bloqueia secret/service key no browser;
- `private.safra_has_role` e `private.get_my_safra_roles` exigem sessão corporativa canônica;
- arquivos marcados como gerados que carregam controles de segurança são cobertos por `check-c01-corporate-access-coherence.py`.

Não foi encontrada nova “sujeira” crítica de auth no código inspecionado.

## 6. Pendências para decisão

| ID | Pendência | Proposta |
|---|---|---|
| C04-AUD-02 | falta teste mutation + JWT expirado + zero efeito | adicionar pgTAP agora |
| C04-AUD-03 | END/CANCEL inexistentes; profile parece declarar capacidade atual | manter implementação deferida e corrigir documentação |
| C04-AUD-07 | REST ainda lê `applications/incidents` embora Reliability tenha saído do produto | revogar SELECT/policies legadas agora |

Itens 01, 04, 05 e 06 não requerem correção funcional nesta fotografia.

## 7. Gate de fechamento

C04-AUD só poderá ser recertificada quando:

- C04-AUD-02 tiver regressão explícita de mutation sem efeito sob JWT expirado;
- C04-AUD-03 estiver documentalmente reconciliado como START atual + END/CANCEL deferidos, com testes obrigatórios futuros;
- C04-AUD-07 tiver decisão executada sobre a superfície REST legada;
- App Smoke e Database Disposable puderem ser reexecutados após retorno da cota do GitHub Actions;
- o PRIMARY for reverificado após qualquer migration corretiva.

> **C04 histórico permanece preservado. Esta C04-AUD está EM EXECUÇÃO e ainda não foi recertificada.**


## 8. Decisão de execução — branch exclusiva e fila

**Decisão registrada em:** 28/09/2026 às 07:42 BRT  
**Estado:** MELHORIAS AUTORIZADAS / AGUARDANDO VEZ NA FILA  
**Branch exclusiva:** `audit/c04-identity-rbac-rls-2026-09-28`  
**Posição na fila programada:** **ITEM 3**

O fechamento histórico do SAFRA-C04 permanece preservado. A reauditoria C04-AUD passa a ter uma onda corretiva própria e isolada. Nenhuma correção deste bloco deve ser aplicada diretamente na branch C03-AUD nem em `main`.

A branch C04 é o recipiente canônico para ir acumulando novos achados e melhorias que pertençam estritamente a **Identidade, sessão, RBAC, ownership, RLS e equivalência UI/REST/RPC** até a execução do ITEM 3.

### 8.1 Backlog de melhorias autorizado

| ID | Melhoria | Estado de entrada |
|---|---|---|
| C04-IMP-01 | Retirar a superfície REST legacy de `public.applications` e `public.incidents` para `authenticated`, preservando as tabelas como histórico estacionado | AUTORIZADO / PENDENTE |
| C04-IMP-02 | Remover/reconciliar policies legacy de `applications/incidents` que não devem permanecer como superfície funcional | AUTORIZADO / PENDENTE |
| C04-IMP-03 | Criar regressão explícita: JWT expirado -> START negado -> zero mutation/efeito persistido | AUTORIZADO / PENDENTE |
| C04-IMP-04 | Reconciliar END/CANCEL como funcionalidade ainda deferida e provar ausência de exposição prematura, sem implementar os RPCs nesta onda | AUTORIZADO / PENDENTE |
| C04-IMP-05 | Criar regressão do binding de principal por identidade corporativa para principals ainda sem `auth.user` vinculado | AUTORIZADO / PENDENTE |
| C04-IMP-06 | Endurecer a matriz de papéis: Jair governance; Bruno executive/analytics sem técnica; Jiane/Daniel/Renato owners; platform admins sem ownership automático | AUTORIZADO / PENDENTE |
| C04-IMP-07 | Tornar permanente o teste adversarial contra elevação de owner/role/version/authority via payload | AUTORIZADO / PENDENTE |
| C04-IMP-08 | Criar gate de coerência entre UI, REST/Data API, RPC, grants e RLS para impedir nova divergência de superfície | AUTORIZADO / PENDENTE |
| C04-IMP-09 | Manter `anon` deny-by-default como gate explícito de recertificação | AUTORIZADO / PENDENTE |

### 8.2 Regra da fila

A execução é estrita:

1. **ITEM 1 — C02-AUD / PR #10** deve concluir;
2. **ITEM 2 — C03-AUD** deve ser recertificado, ficar verde no head final e concluir;
3. **ITEM 3 — C04-AUD** pode então ser reconciliado com `main`, preservando C02 + C03, e iniciar as melhorias acima.

Se ITEM 1 ou ITEM 2 estiver bloqueado por GitHub Actions/CI, a C04 não deve ser adiantada nem mesclada por bypass.

Antes do merge da C04:

- mudanças estruturais de banco devem ser migration versionada;
- PRIMARY Lovable Cloud deve ser reverificado após mudanças;
- App Smoke e Database Disposable devem passar no head final;
- a documentação C04-AUD deve registrar resultado por melhoria;
- END/CANCEL continuam fora do escopo funcional desta onda.

### 8.3 Regra para novos achados

Novos achados detectados antes da execução podem ser adicionados a esta branch e a este backlog **somente quando pertencerem ao escopo Identidade/RBAC/RLS**. Mudanças de domínio, SLA, UX funcional, END/CANCEL ou outras fases devem continuar em seus blocos próprios do roadmap.


## 9. Bloco A — execução corretiva

**Executado em:** 28/09/2026 às 08:01 BRT  
**Escopo autorizado:** C04-AUD-02, C04-AUD-03 e C04-AUD-07  
**Branch:** `audit/c04-identity-rbac-rls-2026-09-28`  
**PRIMARY:** Lovable Cloud / PostgreSQL-Supabase

### 9.1 C04-AUD-02 — JWT expirado -> START negado -> zero efeito

Teste reversível executado no PRIMARY com uma sessão corporativa real como referência de identidade e `exp` forçado para o passado dentro de transação controlada.

Resultado observado:

```text
safra_is_corporate_user() = false
SQLSTATE = 42501
erro = SAFRA_START_FORBIDDEN
treatments antes = 0
treatments depois = 0
treatment_events antes = 0
treatment_events depois = 0
RESULT = PASS
```

O teste permanente foi versionado em:

`supabase/tests/database/c04_reaudit_identity_rbac_rls.test.sql`

**Estado:** CLOSED / PASS.

### 9.2 C04-AUD-03 — START atual; END/CANCEL deferidos

A auditoria confirmou novamente que:

- START está implementado e governado por `public.safra_start_treatment`;
- `safra_end_treatment` não existe;
- `safra_cancel_treatment` não existe;
- a ausência é deliberada e permanece vinculada às fases F01/F02;
- nenhuma implementação funcional de END/CANCEL foi antecipada nesta onda.

A semântica do `PROJECT_PROFILE` foi corrigida para separar capacidade atual de regra futura aprovada:

- `can_start = true`;
- `can_end = false` no estado atual;
- `can_cancel = false` no estado atual;
- autorização futura de END/CANCEL permanece documentada como regra aprovada, ainda não implementada.

O pgTAP C04 também passa a falhar caso END/CANCEL apareçam prematuramente.

**Estado:** CLOSED / PASS_DOCUMENTAL_AND_SURFACE.

### 9.3 C04-AUD-07 — retirada do REST legacy de applications/incidents

Foi criada a migration canônica:

`supabase/migrations/20260928075934_c04_reaudit_legacy_surface_hardening.sql`

A migration:

- revoga todos os privilégios de `anon` e `authenticated` em `public.applications`;
- revoga todos os privilégios de `anon` e `authenticated` em `public.incidents`;
- remove `safra_c04_applications_select`;
- remove `safra_c04_incidents_select`;
- remove `safra_c04_incidents_insert`;
- remove `safra_c04_incidents_update`;
- preserva as tabelas e seus dados;
- preserva RLS;
- preserva acesso confiável de `service_role`.

Antes da promoção, a migration foi simulada integralmente no PRIMARY dentro de `BEGIN/ROLLBACK`. Todos os asserts passaram.

Depois disso, o mesmo SQL versionado foi promovido ao PRIMARY e a migration foi registrada em `supabase_migrations.schema_migrations`.

Validação pós-promoção:

```text
authenticated SELECT applications = false
authenticated SELECT incidents = false
legacy policies applications/incidents = 0
service_role read applications = true
service_role read incidents = true
migration 20260928075934 tracked = true
```

O teste permanente `c04_reaudit_identity_rbac_rls.test.sql` foi executado contra o PRIMARY após a promoção.

**Estado:** CLOSED / PASS_PRIMARY.

### 9.4 Resultado do Bloco A

```text
C04-AUD-02 = CLOSED/PASS
C04-AUD-03 = CLOSED/PASS
C04-AUD-07 = CLOSED/PASS
OPEN_MATERIAL_FINDINGS = 0
BLOCK_A = COMPLETE
C04_AUD_RECERTIFICATION = PENDING_PREVENTIVE_IMPROVEMENTS_AND_FINAL_CI
```

---

## 10. Melhorias preventivas planejadas — 6 itens

Estas melhorias **não são defeitos abertos**. Elas formam a próxima camada de proteção contra regressão e ficam reservadas para o ITEM 3 da fila.

| ID | Melhoria preventiva | Objetivo | Estado |
|---|---|---|---|
| PREV-01 | Teste automático de binding `principal -> auth.user` | Garantir primeiro login Microsoft correto para Bruno, Jiane, Daniel e Renato, sem alterar role/ownership | **DONE / PASS** |
| PREV-02 | Matriz completa de papéis como regressão | Fixar Jair=governance, Bruno=executive/analytics, Jiane/Daniel/Renato=owners e platform admins=técnicos | **DONE / PASS** |
| PREV-03 | Invariante permanente `PAPEL != OWNERSHIP` | Impedir qualquer herança automática de ownership por papel administrativo | **DONE / PASS** |
| PREV-04 | Teste adversarial de privilege escalation | Rejeitar/neutralizar tentativas de enviar owner, role, version, user_id, authority ou clocks pelo client | **DONE / PASS** |
| PREV-05 | Gate UI x REST x RPC x grants x RLS | Detectar automaticamente divergência entre superfície visível e superfície de API | QUEUED |
| PREV-06 | `anon` deny-by-default como gate permanente | Tornar CRUD/EXECUTE anônimo negado uma condição obrigatória de recertificação | QUEUED |

### Regra de execução das preventivas

As seis melhorias acima permanecem no **ITEM 3** da fila. O Bloco A não deve ser reexecutado nessa etapa, salvo como smoke de recertificação. O ITEM 3 deve implementar PREV-01..PREV-06, rodar App Smoke + Database Disposable no head final e então recertificar a C04-AUD.


## 11. Bloco B — identidade e autoridade preventiva

**Executado em:** 28/09/2026 às 08:15 BRT  
**Escopo:** PREV-01, PREV-02, PREV-03 e PREV-04  
**Branch:** `audit/c04-identity-rbac-rls-2026-09-28`  
**Resultado:** **22/22 PASS no PRIMARY**, com rollback integral

Arquivo permanente criado:

`supabase/tests/database/c04_preventive_identity_authority.test.sql`

### 11.1 PREV-01 — binding `principal -> auth.user`

Foi criado um principal sintético pré-provisionado dentro de transação controlada, com role governada, seguido da criação de um `auth.user` Microsoft/Azure com o mesmo e-mail corporativo.

Comprovado:

- o trigger `trg_bind_safra_principal_from_auth_user` vinculou apenas `user_id`;
- role pré-existente permaneceu inalterada;
- nenhum ownership foi criado ou reescrito;
- nenhum grant adicional foi criado;
- o trigger permanece instalado em `auth.users`.

Também foi validado no PRIMARY que Bruno, Jiane, Daniel e Renato continuam com principals ativos, roles/ownership corretos e sem `auth.user` real no momento da auditoria. Isso confirma que o primeiro login futuro utilizará o mesmo mecanismo já testado, sem necessidade de criar contas fictícias permanentes.

**Estado:** DONE / PASS.

### 11.2 PREV-02 — matriz de papéis

A regressão fixa explicitamente a matriz atual:

- Kaue, Amanda, Vinicius e João -> `safra_platform_admin`;
- Jair -> `safra_governance_admin`;
- Bruno -> `safra_executive_admin`;
- Daniel, Jiane e Renato -> `scenario_owner`.

O teste exige exatamente **9 grants ativos para os 9 principals governados**, sem role extra silenciosa.

Checks adicionais:

- Bruno possui somente `safra_executive_admin`;
- Jair possui somente `safra_governance_admin`.

A capacidade futura de analytics de Bruno continua fora do escopo funcional atual; o que foi recertificado aqui é a autoridade RBAC.

**Estado:** DONE / PASS.

### 11.3 PREV-03 — PAPEL != OWNERSHIP

A suíte agora exige permanentemente:

- platform/governance/executive admins com zero ownership por herança;
- nenhum principal administrativo com `scenario_owner` silencioso;
- 11/11 cenários com vínculo explícito ativo;
- 11/11 owners com role `scenario_owner` independente;
- Daniel = 6 cards;
- Jiane = 4 cards;
- Renato = 1 card.

Resultado pós-teste no PRIMARY:

```text
active_owner_links = 11
active_roles_nine_principals = 9
```

**Estado:** DONE / PASS.

### 11.4 PREV-04 — privilege escalation

O ambiente bloqueou um ensaio de chamada sintética mais agressiva antes de alcançar o banco; nenhuma tentativa de contorno foi realizada.

A fronteira foi então recertificada por controles seguros e permanentes:

- existe apenas **1 overload** de `safra_start_treatment`;
- assinatura exata:
  `p_scenario_id, p_idempotency_key, p_impact_summary, p_impacted_area_ids`;
- não existem parâmetros para owner, role, version, actor, criticality ou timestamp;
- `authenticated` não pode UPDATE principals;
- `authenticated` não pode INSERT/UPDATE role grants;
- `authenticated` não pode INSERT/UPDATE scenario_owners;
- `authenticated` não pode UPDATE scenario_versions;
- função START continua derivando ator de `auth.uid()`;
- owner/version continuam resolvidos do estado server-side do cenário;
- a regressão funcional C08 já preserva snapshots server-side.

**Estado:** DONE / PASS.

### 11.5 Integridade pós-teste

Após o `ROLLBACK`:

```text
synthetic_auth_users = 0
synthetic_principals = 0
synthetic_role_grants = 0
active_owner_links = 11
active_roles_nine_principals = 9
```

Nenhuma fixture sintética permaneceu no PRIMARY.

### 11.6 Resultado do Bloco B

```text
PREV-01 = DONE/PASS
PREV-02 = DONE/PASS
PREV-03 = DONE/PASS
PREV-04 = DONE/PASS
BLOCK_B = COMPLETE
PREVENTIVE_IMPROVEMENTS_REMAINING = 2
NEXT = BLOCK_C_PREV_05_PREV_06
```

A C04-AUD continua sem achados materiais abertos. A recertificação final depende apenas de PREV-05, PREV-06 e CI final.
