# STATUS — incident-log-pro / Painel Safra

> Atualizado em: 27/09/2026  
> Fase atual: **SAFRA-C08 — UX do COMEÇO / START**  
> Escopo atual: **START end-to-end implementado e promovido ao PRIMARY; próxima ação é homologar a UX com sessão Microsoft corporativa real antes de avançar nas demais telas do C08.**

> Reauditoria corretiva **C00-AUD concluída em 27/09/2026 às 13:15 BRT**. C00-AUD-01 a C00-AUD-04 foram fechados: regressão HTTP do legado reforçada, menor privilégio restaurado e promovido ao PRIMARY, lint convertido em gate zero-warning e hook legado morto removido. Evidências completas: `docs/AUDITORIA_C00_REABERTURA_2026-09-27.md`.

> Reauditoria corretiva **C01-AUD concluída e recertificada em 27/09/2026 às 18:16 BRT**. PROJECT_PROFILE, documentação canônica, domínios corporativos, privacidade, inventário de decisões e fronteiras de runtime foram reconciliados. `unknown_material_count = 0` foi recertificado. Evidências: `docs/AUDITORIA_C01_REABERTURA_2026-09-27.md`.

> Reauditoria corretiva **C02-AUD aberta em 27/09/2026 às 18:37 BRT**. Foram identificadas 10 pendências em threat model, autorização, cobertura de testes, superfície Data API/RPC e documentação. O principal achado é um bypass de sessão corporativa nos RPCs de RBAC; `AUTHZ-001` histórico permanece preservado, mas **não está recertificado** nesta nova fotografia. Alterações autorizadas e em execução. Fonte: `docs/AUDITORIA_C02_REABERTURA_2026-09-27.md`.

> Snapshot runtime recertificado no fechamento da C01-AUD: Lovable publicado tecnicamente com endpoint acessível, audiência funcional **INTERNAL**, Microsoft/Azure + sessão viva + domínio corporativo aprovado. PRIMARY observado com **2 usuários Auth corporativos**, **2 principals ativos vinculados**, **9 grants funcionais ativos**, **0 grants anon nas estruturas centrais** e **0 policies públicas `USING (true)`**.

> **C04-AUD — Identidade, RBAC e RLS aberta em 28/09/2026 às 07:15 BRT; melhorias autorizadas em 28/09/2026 às 07:42 BRT.** Branch exclusiva: `audit/c04-identity-rbac-rls-2026-09-28`, empilhada sobre a C03-AUD. A onda corretiva C04 não deve alterar C03 nem `main` antes de sua vez. Está registrada como **ITEM 3** da fila programada, depois de C02/PR #10 e C03-AUD. A branch poderá ser alimentada com novos achados estritamente de Identidade/RBAC/RLS até sua execução. Backlog inclui: retirada da superfície REST legacy de `applications/incidents`, teste JWT expirado -> zero mutation, reconciliação END/CANCEL deferidos, binding de principals, matriz de papéis/ownership, regressão de privilege escalation e gate UI/REST/RPC/RLS. Fonte: `docs/AUDITORIA_C04_REABERTURA_2026-09-28.md`.

> **C04-AUD Bloco A concluído em 28/09/2026 às 08:01 BRT.** As três pendências materiais foram tratadas: JWT expirado -> START negado com zero mutation foi comprovado no PRIMARY; START foi separado documentalmente de END/CANCEL ainda deferidos; e o REST legacy de `applications/incidents` foi retirado de `authenticated` pela migration `20260928075934_c04_reaudit_legacy_surface_hardening.sql`, já promovida e rastreada no PRIMARY. A C04-AUD passa a ter **0 achados materiais abertos** e **6 melhorias preventivas** na posição 3 da fila. Recertificação final continua pendente das preventivas + CI final.

> **C04-AUD Bloco B concluído em 28/09/2026 às 08:15 BRT.** PREV-01 a PREV-04 foram convertidos em regressões permanentes em `supabase/tests/database/c04_preventive_identity_authority.test.sql` e executados no Lovable Cloud PRIMARY com **22/22 PASS** e rollback integral. Binding altera apenas `user_id`; matriz de 9 papéis permanece exata; 11 ownerships continuam explícitos (Daniel 6, Jiane 4, Renato 1); PAPEL != OWNERSHIP; START mantém assinatura única sem owner/role/version/actor/criticality/timestamp do client e browser sem grants de escalada. Restam apenas **PREV-05 e PREV-06** no Bloco C antes do CI final.

> **C04-AUD Bloco C concluído em 28/09/2026 às 08:36 BRT.** PREV-05 e PREV-06 estão implementados. Contrato `C04_AUTHORIZATION_SURFACE.json`, gate estático `check-c04-authorization-surface.py` ligado ao App Smoke e gate pgTAP `c04_authorization_surface_gate.test.sql` concluído no PRIMARY com **12/12 PASS**. A varredura da branch cobriu **74 arquivos TS/TSX**, encontrou exatamente 3 RPCs aprovadas e zero `.from(...)` direto. PRIMARY: 19 relações públicas, RLS em todas as tabelas, 0 policies, 0 CRUD direto para `anon/authenticated`, 0 EXECUTE público para `anon`. **Blocos A+B+C concluídos; 0 melhorias preventivas restantes; C04-AUD aguarda somente CI final + reconciliação da fila para recertificação formal.**

---

## 1. Baseline registrada

> **SNAPSHOT HISTÓRICO:** as seções de baseline abaixo registram o estado encontrado no início do SAFRA-C00. Referências a rotas, hooks, autenticação e migrations dentro desse snapshot não descrevem necessariamente o estado atual. O estado corrente é o cabeçalho deste documento e as evidências das fases posteriores.

### Repositório

- Repositório: `Kaue-EDBS/incident-log-pro`
- Visibilidade: privada
- Branch padrão: `main`
- Baseline funcional/documental anterior a esta fotografia:
  - commit: `8c38efe9a8ef73a9469083baf16fc33bc82b5b96`
  - mensagem: `docs: link canonical Painel Safra roadmap`
  - data do commit: 23/09/2026 21:37 BRT / 24/09/2026 00:37 UTC
- O projeto está conectado ao Lovable; `AGENTS.md` determina preservar o histórico já publicado e evitar force-push/rebase destrutivo.

### Regra desta baseline

Esta fotografia **não altera comportamento, schema ou segurança**. Ela registra o estado encontrado para que as próximas ações do SAFRA-C00 possam ser comparadas contra uma referência conhecida.

---

## 2. Stack observada

- React 19
- TanStack Start
- TanStack Router com file-based routing
- TanStack Query
- Vite
- TypeScript
- Supabase JS `@supabase/supabase-js`
- PostgreSQL/Supabase
- migrations SQL versionadas em `supabase/migrations/`

O banco continua sendo a fonte de verdade para aplicações e incidentes na implementação atual.

---

## 3. Schema atual versionado

Fonte primária: migrations em `supabase/migrations/`.  
Fonte auxiliar de consistência: `src/integrations/supabase/types.ts`.

### 3.1 Tabela `public.applications`

| Campo | Tipo | Regra atual |
|---|---|---|
| `id` | UUID | PK, default `gen_random_uuid()` |
| `name` | TEXT | NOT NULL, UNIQUE |
| `description` | TEXT | nullable |
| `is_active` | BOOLEAN | NOT NULL, default `TRUE` |
| `created_at` | TIMESTAMPTZ | NOT NULL, default `now()` |
| `updated_at` | TIMESTAMPTZ | NOT NULL, default `now()` |

Seed inicial versionado:

- XPTO
- ABC
- SEP

### 3.2 Tabela `public.incidents`

| Campo | Tipo | Regra atual |
|---|---|---|
| `id` | UUID | PK, default `gen_random_uuid()` |
| `application_id` | UUID | NOT NULL, FK para `applications(id)`, `ON DELETE CASCADE` |
| `status` | TEXT | NOT NULL, default `active`, CHECK `active/resolved` |
| `failure_started_at` | TIMESTAMPTZ | nullable |
| `detected_at` | TIMESTAMPTZ | NOT NULL, default `now()` |
| `response_started_at` | TIMESTAMPTZ | nullable |
| `recovered_at` | TIMESTAMPTZ | nullable |
| `type` | TEXT | nullable |
| `category` | TEXT | nullable |
| `responsible` | TEXT | nullable |
| `cause` | TEXT | nullable |
| `resolution` | TEXT | nullable |
| `notes` | TEXT | nullable |
| `created_at` | TIMESTAMPTZ | NOT NULL, default `now()` |
| `updated_at` | TIMESTAMPTZ | NOT NULL, default `now()` |

### 3.3 Índices e invariantes versionados

- `incidents_application_idx` em `application_id`.
- `incidents_detected_idx` em `detected_at DESC`.
- `incidents_one_active_per_app`: índice único parcial que impede mais de um incidente `active` por aplicação.
- FK `incidents.application_id -> applications.id` com cascade delete.
- Trigger de `updated_at` em `applications` e `incidents`.
- Trigger `incidents_validate` para coerência temporal.

### 3.4 Validação temporal vigente após as duas migrations

A função `validate_incident_timestamps()` termina, no estado versionado atual, com tolerância de **60 segundos** entre eventos relacionados.

Regras observadas:

- `failure_started_at` não pode ficar materialmente depois de `detected_at`;
- `recovered_at` não pode ficar materialmente antes de `detected_at`;
- `response_started_at` deve permanecer entre detecção e recuperação, respeitando a tolerância;
- timestamps futuros acima de 5 minutos são rejeitados.

### 3.5 Dados demo

A primeira migration popula incidentes históricos fictícios para XPTO, ABC e SEP. Portanto, a baseline atual contém lógica de seed/demo dentro da migration inicial.

---

## 4. Rotas observadas na baseline histórica — não representam o estado atual

Fonte histórica da baseline: `src/routes/` e `src/routeTree.gen.ts`.

> **Estado atual:** `src/routes/__root.tsx` usa `AuthProvider` + `AuthedShell`; usuários sem sessão são redirecionados para `/auth`. O START atual não usa mais `useStartIncident()` e opera por RPC governada.

| URL | Arquivo | Papel atual | Acesso no router |
|---|---|---|---|
| `/` | `src/routes/index.tsx` | Visão geral, filtros e métricas | sem guard de autenticação |
| `/novo-incidente` | `src/routes/novo-incidente.tsx` | abertura de incidente | sem guard de autenticação |
| `/incidentes` | `src/routes/incidentes.index.tsx` | histórico e filtros | sem guard de autenticação |
| `/incidentes/$id` | `src/routes/incidentes.$id.tsx` | acompanhamento, recuperação e finalização | sem guard de autenticação |
| `/aplicacoes` | `src/routes/aplicacoes.tsx` | resumo por aplicação | sem guard de autenticação |
| `/indicadores` | `src/routes/indicadores.tsx` | gráficos e comparativos | sem guard de autenticação |

O layout raiz está em `src/routes/__root.tsx`.

### Acesso a dados observado nas rotas da baseline histórica

As páginas usam os hooks de `src/lib/queries.ts`, que consultam diretamente o Supabase pelo client de navegador:

- `useApplications()` → SELECT em `applications`;
- `useIncidents()` → SELECT em `incidents`;
- `useIncident(id)` → SELECT de um incidente;
- `useStartIncident()` → INSERT em `incidents`;
- `useUpdateIncident()` → UPDATE em `incidents`.

Não foi identificado guard `beforeLoad` ou middleware de autorização aplicado às rotas acima.

---

## 5. Inventário de migrations

### Migration 1

Arquivo:

`supabase/migrations/20260814002247_f1c57913-2970-4feb-90b8-b0a55dae4f0e.sql`

Responsabilidades:

1. cria `applications`;
2. cria `incidents`;
3. cria índices;
4. impede dois incidentes ativos para a mesma aplicação;
5. concede grants;
6. habilita RLS;
7. cria policies;
8. cria função/trigger de `updated_at`;
9. cria validação temporal;
10. cria seeds XPTO/ABC/SEP;
11. cria incidentes demo.

### Migration 2

Arquivo:

`supabase/migrations/20260814002933_5ad4c4fc-07af-4d17-b8ad-cbec5a693ec7.sql`

Responsabilidade:

- substitui `validate_incident_timestamps()` e introduz tolerância de 60 segundos nas comparações temporais.

### Estado de reconciliação live

**Não validado nesta rodada.**

A conexão Supabase disponível neste ambiente não possui permissão para o projeto configurado no repositório. Portanto, ainda não foi possível confirmar se:

- o schema live é idêntico ao schema versionado;
- as duas migrations constam no histórico live;
- existem alterações manuais/drift fora do Git;
- existem objetos adicionais no banco.

Até essa validação ocorrer, a fonte comprovável desta baseline é o conteúdo versionado no GitHub.

---

## 6. Inventário de acesso Supabase

### 6.1 Projeto configurado

`supabase/config.toml` aponta para:

`project_id = "trqkwqkjjjeppuddwenu"`

A conexão Supabase disponível neste ambiente **não tem permissão** para consultar esse projeto. Tentativas de consultar projeto, tabelas e migrations retornaram erro de permissão.

Isso significa:

- integração declarada no código: **identificada**;
- acesso live administrativo por esta conexão: **não validado / sem permissão**;
- saúde do projeto Supabase live: **não afirmada**.

### 6.2 Variáveis encontradas no `.env` versionado

Por segurança, somente os **nomes** são registrados aqui; valores não são copiados para a documentação.

- `SUPABASE_PROJECT_ID`
- `SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_URL`
- `VITE_SUPABASE_PROJECT_ID`
- `VITE_SUPABASE_PUBLISHABLE_KEY`
- `VITE_SUPABASE_URL`

Não foi encontrado `SUPABASE_SERVICE_ROLE_KEY` no `.env` versionado.

A existência de um secret de service role no runtime/Lovable Cloud **não foi validada**.

### 6.3 Client de navegador

Arquivo: `src/integrations/supabase/client.ts`.

Características atuais:

- usa URL + publishable key;
- usa `localStorage` no navegador;
- `persistSession: true`;
- `autoRefreshToken: true`;
- é o client utilizado pelos hooks de CRUD atuais.

### 6.4 Middleware de autenticação

Arquivos:

- `src/integrations/supabase/auth-attacher.ts`;
- `src/integrations/supabase/auth-middleware.ts`;
- `src/start.ts`.

Estado:

- `attachSupabaseAuth` é registrado globalmente como `functionMiddleware`;
- ele anexa o access token da sessão aos pedidos de server functions;
- `requireSupabaseAuth` valida Bearer token e claims no servidor;
- as rotas atuais e os hooks de CRUD observados não passam por esse middleware, pois acessam o Supabase diretamente pelo client de navegador.

### 6.5 Client administrativo

Arquivo: `src/integrations/supabase/client.server.ts`.

O código prevê `SUPABASE_SERVICE_ROLE_KEY` e documenta que esse client:

- é exclusivamente server-side;
- ignora RLS;
- não deve ser exposto ao cliente.

A disponibilidade desse secret no ambiente live não foi comprovada nesta rodada.

---

## 7. Grants e RLS atuais versionados

As migrations atuais concedem:

- `SELECT, INSERT, UPDATE, DELETE` em `applications` para `anon` e `authenticated`;
- `SELECT, INSERT, UPDATE, DELETE` em `incidents` para `anon` e `authenticated`;
- `ALL` para `service_role` nas duas tabelas.

RLS está habilitada nas duas tabelas, porém as policies versionadas são:

- `FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)` em `applications`;
- `FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)` em `incidents`.

### Leitura objetiva do estado

Na baseline versionada, RLS está tecnicamente ligada, mas **não restringe linhas**, e o papel `anon` recebe CRUD. Portanto, a camada de banco versionada não implementa autorização efetiva para essas duas tabelas.

Esse ponto já está previsto no roadmap como risco P0 do SAFRA-C00. Nenhuma correção foi aplicada nesta rodada.

---

## 8. Riscos P0 observados e preservados para contenção

### P0-01 — exposição de arquivo de ambiente — CONTIDO

- `.env` foi removido do tracking na branch `main`;
- `.gitignore` agora protege `.env` e `.env.*`;
- `.env.example` foi criado como template seguro sem valores reais;
- a triagem do `.env` atual e do único commit histórico do arquivo encontrou apenas project ref, URL e chave `sb_publishable_...`;
- não foram encontrados `sb_secret_...`, `service_role` ou JWT elevado versionados;
- nenhuma rotação é necessária para o material versionado encontrado;
- secrets eventualmente existentes apenas no runtime/Lovable Cloud continuam fora do escopo de validação até haver acesso ao projeto Supabase live.

### P0-02 — CRUD para `anon` — CORRIGIDO NO PRIMARY

A migration `20260924212155_harden_safra_c00_access.sql` remove todos os privilégios de `anon` em `applications` e `incidents`.

Estado:
- código/migration: **corrigido**;
- Lovable Cloud PRIMARY: **corrigido e validado**.

### P0-03 — Policies abertas — CORRIGIDO NO PRIMARY

A migration de hardening remove as policies permissivas da baseline e cria policies separadas para SELECT, INSERT e UPDATE.

Acesso passa a exigir:
- papel PostgreSQL `authenticated`;
- `auth.uid()` presente;
- usuário não anônimo;
- `app_metadata.safra_access = true`.

Não existe policy DELETE para `authenticated`.  
`applications` fica read-only para usuários autenticados autorizados.

Estado:
- código/migration: **corrigido**;
- Lovable Cloud PRIMARY: **corrigido e validado**.

### P0-04 — UI sem barreira de autenticação — RECLASSIFICADO

As rotas atuais ainda não possuem fluxo de login/guard de autenticação no frontend.

Após o hardening do PRIMARY, isso **não representa mais exposição P0**, porque `anon` não possui acesso ao banco. A ausência de login passa a ser uma dependência funcional de identidade/RBAC a ser tratada no **SAFRA-C04**, antes de liberar uso autenticado do produto.

### P0-05 — Estado live — VALIDADO

O PRIMARY correto foi confirmado como **Lovable Cloud**, com PostgreSQL na stack Supabase.

O estado live de grants, RLS e policies foi consultado diretamente no PRIMARY e validado. Permanece apenas uma divergência administrativa: o hardening está aplicado no banco, mas a versão `20260924212155` ainda não consta em `supabase_migrations.schema_migrations`. Essa divergência será tratada na governança de migrations e não constitui bloqueador P0.

---

## 9. Progresso SAFRA-C00

| Item | Ação | Estado após esta rodada |
|---|---|---|
| 1 | Registrar commit baseline | ✅ Registrado |
| 2 | Registrar schema atual | ✅ Registrado |
| 3 | Documentar rotas atuais | ✅ Registrado |
| 4 | Inventariar migrations | ✅ Registrado |
| 5 | Inventariar acesso Supabase | ✅ Inventariado, com limitação live explícita |
| 6 | Remover `.env` do tracking | ✅ Concluído |
| 7 | Ajustar `.gitignore` e preservar `.env.example` | ✅ Concluído |
| 8 | Identificar secrets possivelmente expostos | ✅ Concluído: nenhum secret elevado encontrado no `.env` atual ou no único commit histórico do arquivo |
| 9 | Rotacionar secrets aplicáveis | ✅ Nenhuma rotação aplicável ao material versionado; apenas publishable key/URL/project ref foram encontrados. Secrets live/runtime seguem não validados por falta de permissão ao projeto Supabase |
| 10 | Revisar grants atuais | ✅ Concluído e validado no Lovable Cloud PRIMARY |
| 11 | Remover CRUD indiscriminado de `anon` | ✅ Concluído no PRIMARY; teste direto retorna permission denied |
| 12 | Substituir policies `USING (true)` | ✅ Concluído no PRIMARY; quatro policies `safra_c00_*` ativas |
| 13 | Testar acesso direto não autorizado | ✅ Validado no Lovable Cloud PRIMARY: `anon` negado; usuário sem `safra_access` vê 0 registros; usuário autorizado vê os dados esperados |
| 14 | Preservar histórico Git sem force push | ✅ Verificado: baseline preservada como ancestral e `behind_by = 0` |

---

## 10. Próximo passo canônico

O **SAFRA-C00 está encerrado**.

O próximo avanço deve seguir o roadmap a partir das etapas seguintes, mantendo:

- identidade/RBAC definitivo no SAFRA-C04;
- governança de schema/migrations no SAFRA-C05;
- regularização do histórico formal da migration `20260924212155` como pendência administrativa;
- nenhuma reabertura de acesso `anon`.

Não há bloqueador P0 conhecido impedindo a continuidade da reformulação.


---

## 11. Hardening de grants e RLS — 24/09/2026

Migration adicionada:

`supabase/migrations/20260924212155_harden_safra_c00_access.sql`

### Matriz de grants proposta após aplicação

| Tabela | anon | authenticated | service_role |
|---|---|---|---|
| `applications` | nenhum | SELECT | ALL |
| `incidents` | nenhum | SELECT + INSERT limitado + UPDATE limitado | ALL |

### Colunas de INSERT permitidas em incidents

- `application_id`
- `status`
- `detected_at`
- `type`
- `category`

### Colunas de UPDATE permitidas em incidents

- `failure_started_at`
- `response_started_at`
- `recovered_at`
- `status`
- `type`
- `category`
- `responsible`
- `cause`
- `resolution`
- `notes`

### RLS transitória do SAFRA-C00

A política desta fase não implementa ainda o RBAC completo de owner/updater/viewer do SAFRA-C04.

Ela funciona como contenção real:

```text
request
  -> authenticated role
  -> auth.uid presente
  -> usuário não anônimo
  -> app_metadata.safra_access = true
  -> operação permitida pelo grant
  -> operação permitida pela policy específica
```

### Por que usar app_metadata

`user_metadata` é alterável pelo próprio usuário e não deve controlar autorização. `app_metadata` é administrado por backend/admin e é apropriado para este gate transitório.

### Dependência antes da aplicação live

O frontend atual não possui fluxo de login implementado. Aplicar essa migration no ambiente live antes de disponibilizar identidade autenticada válida fará o aplicativo negar acesso aos dados por desenho.

Portanto:

1. a migration está **pronta e versionada**;
2. a aplicação live permanece **não executada** neste ambiente por falta de permissão ao projeto Supabase;
3. antes do deploy da migration, deve existir pelo menos um fluxo de autenticação e usuários autorizados com `app_metadata.safra_access = true`;
4. o SAFRA-C04 substituirá esta regra transitória pelo RBAC definitivo por papel, área e vínculo com cenário.


---

## 13. Validação final SAFRA-C00 no Lovable Cloud PRIMARY — 24/09/2026

### Arquitetura confirmada

- backend provider: `Lovable Cloud`
- database role: `PRIMARY`
- database engine: PostgreSQL
- database stack: Supabase

### Estado real após aplicação do hardening

Grants observados:

- `anon`: nenhum privilégio em `applications` e `incidents`;
- `authenticated`: SELECT em ambas as tabelas;
- `incidents`: INSERT e UPDATE restritos por coluna;
- `service_role`: privilégios administrativos preservados.

Policies ativas:

- `safra_c00_applications_select`
- `safra_c00_incidents_select`
- `safra_c00_incidents_insert`
- `safra_c00_incidents_update`

Policies antigas abertas não estão mais presentes.

### Testes executados no PRIMARY

| Caso | Resultado |
|---|---|
| `anon` → SELECT em `applications` | NEGADO — permission denied |
| `anon` → SELECT em `incidents` | NEGADO — permission denied |
| `authenticated` sem `app_metadata.safra_access` | 0 aplicações / 0 incidentes |
| `authenticated` com `app_metadata.safra_access=true` | 3 aplicações / 14 incidentes |

Conclusão de segurança:

> O bloqueador P0 de acesso anônimo foi removido e validado no banco PRIMARY.

### Observação administrativa de migration

O estado do banco corresponde ao hardening versionado em:

`supabase/migrations/20260924212155_harden_safra_c00_access.sql`

Porém a versão `20260924212155` ainda não aparece em `supabase_migrations.schema_migrations`.

Isso indica diferença entre **estado aplicado** e **histórico formal de migrations**.

Essa divergência não reabre o bloqueador de segurança, mas deve ser regularizada na próxima etapa de governança de migrations para evitar drift entre Git e histórico do Lovable Cloud.

### Gate SAFRA-C00

- contenção de secrets: APROVADA;
- grants: APROVADOS;
- RLS: APROVADA;
- teste negativo de `anon`: APROVADO;
- histórico Git sem reescrita: APROVADO;
- drift de migration history: pendência administrativa, não bloqueador de segurança.

**SAFRA-C00 pode ser considerado encerrado do ponto de vista de segurança P0.**


---

## 14. Fechamento formal dos gates I-1 / I0 / G2 / G5 parcial — 24/09/2026

### Decisão

O SAFRA-C00 encerra sem bloqueador P0 conhecido.

| Gate | Estado | Evidência de fechamento | Escopo remanescente |
|---|---|---|---|
| **I-1 / SEC-001** | **FECHADO** | `.env` removido do tracking; `.env/.env.*` protegidos; `.env.example` seguro; nenhum secret elevado versionado encontrado | revisão contínua de secrets em novas integrações |
| **I0 / G0** | **FECHADO** | baseline, branch `main`, schema, rotas, migrations, backend e PRIMARY registrados; documentação canônica definida | reabrir somente em mudança material de ambiente/arquitetura |
| **G2 / G3** | **FECHADO para C00** | GitHub-first preservado; `docs/ROADMAP.md` + `docs/STATUS.md` canônicos; GitHub HEAD e Lovable sincronizados em `f7e54df73de5f2585cce3102c70e2ad5d3e7bd77` | governança documental continua nas próximas safras |
| **G5** | **FECHADO PARCIAL — P0** | `anon` sem grants; RLS real ativa; policies abertas removidas; teste negativo aprovado; menor privilégio aplicado | G5 completo continua em SAFRA-C04/C05 para identidade, RBAC definitivo, ownership, migrations e autorização por cenário |

### Evidências objetivas

#### I-1 / SEC-001

- `.env` não está mais rastreado;
- `.env.example` está versionado;
- `.gitignore` protege `.env` e `.env.*`;
- inspeção do histórico encontrou apenas project ref, URL e publishable key;
- nenhum `sb_secret_`, `service_role` ou JWT privilegiado foi encontrado no material versionado.

#### I0 / G0

Baseline e ambiente registrados:

- repositório: `Kaue-EDBS/incident-log-pro`;
- branch: `main`;
- backend provider: Lovable Cloud;
- database role: PRIMARY;
- engine: PostgreSQL;
- stack do banco: Supabase;
- schema, rotas, migrations e acesso registrados em `docs/STATUS.md`.

#### G2 / G3

Estado de sincronização validado no fechamento:

- GitHub HEAD: `f7e54df73de5f2585cce3102c70e2ad5d3e7bd77`;
- Lovable latest commit: `f7e54df73de5f2585cce3102c70e2ad5d3e7bd77`;
- Lovable status: `ready`;
- histórico Git preservado sem force push/rebase destrutivo.

#### G5 — fechamento parcial do risco P0

Estado live observado no Lovable Cloud PRIMARY:

- `anon` sem privilégios nas tabelas internas;
- `applications`: `authenticated` somente leitura;
- `incidents`: leitura + INSERT/UPDATE limitados às colunas operacionais;
- quatro policies `safra_c00_*` ativas;
- policies permissivas antigas removidas.

Testes:

- `anon -> applications`: **permission denied**;
- `anon -> incidents`: **permission denied**;
- autenticado sem `safra_access`: **0 / 0 registros**;
- autenticado com `safra_access=true`: **3 aplicações / 14 incidentes**.

### Pendências que NÃO são bloqueadores P0

1. implementar identidade/login funcional;
2. implantar RBAC definitivo por papel, área e vínculo no SAFRA-C04;
3. regularizar o histórico de `20260924212155` em `supabase_migrations.schema_migrations`;
4. aprofundar governança de schema/migrations no SAFRA-C05.

### Resultado do gate

**I-1: FECHADO**  
**I0: FECHADO**  
**G2: FECHADO no escopo C00**  
**G5: FECHADO PARCIALMENTE no escopo P0**

> **Nenhum bloqueador P0 conhecido permanece aberto no SAFRA-C00.**


---

## 15. SAFRA-C01 — documentação canônica e PROJECT_PROFILE

### Estrutura consolidada

| Documento | Responsabilidade canônica |
|---|---|
| `docs/ROADMAP.md` | sequência, gates, fases e plano de execução |
| `docs/STATUS.md` | estado atual, evidências, bloqueios e próximo passo |
| `docs/ARQUITETURA.md` | arquitetura real/alvo, boundaries e autoridade técnica |
| `docs/PROJECT_PROFILE.yaml` | perfil estruturado de risco, serviço, dados, identidade e governança |
| `docs/PRIVACIDADE_THREAT_MODEL.md` | dados pessoais, minimização, retenção e ameaças |
| `docs/REGRAS_NEGOCIO.md` | contratos de regras e invariantes de domínio |
| `docs/MATRIZ_PARIDADE.md` | destino das capacidades legadas durante a reformulação |
| `docs/DECISOES.md` | registro de decisões, ADRs e WAITING_HUMAN_DECISION |

### Princípio de autoridade

- cada assunto deve ter **uma fonte canônica principal**;
- README é porta de entrada, não repositório de regras;
- ROADMAP não deve virar duplicação completa de regras/arquitetura;
- STATUS não deve virar backlog histórico infinito;
- decisões materiais não podem existir apenas em prompt/chat.

### PROJECT_PROFILE

Criado, reconciliado e aprovado para o escopo C01.

Os atributos materiais do perfil foram decididos ou formalmente direcionados para a fase responsável. Não resta `UNKNOWN` material no C01.

### Estado do C01

**Estrutura documental: consolidada.**  
**PROJECT_PROFILE: aprovado para o escopo C01.**  
**UNKNOWN material: 0.**  
**Gate G3: PASS.**  
**Gate G3.25: PASS.**  
**SAFRA-C01: CONCLUÍDO.**


---

## 16. Registro dos atributos materiais do PROJECT_PROFILE — 24/09/2026

Os atributos exigidos pelo SAFRA-C01 foram registrados no `docs/PROJECT_PROFILE.yaml`.

| Atributo | Registro atual |
|---|---|
| service class da aplicação | **DECIDIDO: CRITICO** — SLO 99,95%; RTO 30 min; RPO 5 min |
| criticidade técnica da aplicação | **DECIDIDO: MEDIUM** — independente de service_class=CRITICO e de CRITICAL/HIGH/MODERATE dos cenários |
| criticidade dos cenários | CRITICAL/HIGH/MODERATE — regra de domínio registrada; lista dos quatro críticos ainda pendente |
| Auth | **HOMOLOGADO:** Microsoft Entra ID corporativo via SSO; login funcional; provider Azure; primeiro usuário autenticado |
| papéis privilegiados | **DECIDIDO:** safra_platform_admin, safra_governance_admin, safra_executive_admin e scenario_owner; matriz fina deferida ao SAFRA-C04 |
| dados pessoais | presentes; categorias registradas; minimização obrigatória |
| integrações | nenhuma ativa no MVP; futuras governadas por contrato/DATA_RELEASE |
| REPLICA | **DECIDIDO: false**; backup/restore continuam obrigatórios |
| API | nenhuma API pública; Data API interna protegida por grants/RLS |
| regras de domínio | obrigatórias; regras Safra e legadas registradas; refinamentos específicos seguem nas fases de domínio |

### Leitura do gate

O requisito de **registrar** esses atributos está cumprido.

Os gates G3 e G3.25 foram fechados porque não restam UNKNOWN materiais do C01. Decisões posteriores permanecem explicitamente `DEFERRED_TO_<fase>` e serão reabertas na fase responsável.


### Correção conceitual — criticidade x service class — 24/09/2026

Após revisão dos três materiais-mãe:

- `CRITICAL/HIGH/MODERATE` foi confirmado como classificação de **cenário/protocolo**;
- os materiais-mãe não definem `service_class`, SLO, RTO ou RPO do software Painel Safra;
- `service_class` e `application_criticality` permanecem requisitos técnicos do Framework EBSA;
- nenhum desses atributos técnicos será inferido a partir do SLA ou da criticidade dos protocolos;
- a lista exata dos quatro cenários críticos está em `GI-SAFRA-001`; fontes atuais confirmam que existem quatro, mas não identificam nominalmente quais são.


### Decisão Auth — Microsoft Entra ID — 24/09/2026

**APPROVED**

- identity provider: Microsoft Entra ID corporativo;
- método: SSO;
- login local por senha: fora do desenho aprovado;
- implementação frontend: ainda pendente;
- usuários Auth atuais: 0;
- RBAC/RLS: decisão e implementação separadas no SAFRA-C04.

Princípio:

```text
Microsoft Entra ID -> autenticação / identidade
Painel Safra RBAC + RLS -> autorização
```


### Decisão de papéis funcionais — 24/09/2026

**APPROVED**

Papéis funcionais:

- `safra_admin`;
- `scenario_owner`.

Papéis removidos do desenho:

- `scenario_updater`;
- `manager_viewer`;
- `executive_viewer`;
- `viewer`.

Pontos já fixados:

- admin não é owner global por herança;
- owner depende de vínculo explícito com cenário;
- não haverá camadas funcionais intermediárias de leitura/atualização.

Ainda aberto:

- matriz exata de permissões entre `safra_admin` e `scenario_owner`;
- regra de acesso para usuário Microsoft autenticado sem papel funcional.


---

## 17. Papéis administrativos, 12º card e analytics — 24/09/2026

### Administração técnica
Kaue permanece no topo técnico, com Amanda, Vinicius e João como substitutos permanentes.

### Governança
Jair supervisiona todos os cards, decisões de governança, relatórios e propostas do 12º card. Ele é o único `safra_governance_admin`.

Jiane não exerce governança global. Ela permanece como owner dos cards 4, 5, 6 e 8 e recebe somente as comunicações desses cards.

### Administração executiva
Bruno Palhão terá uma visão executiva/analytics de todos os cards e métricas. Não recebe e-mails operacionais e não realiza manutenção técnica da plataforma.

### 12º card
O 12º card é um formulário de proposta de novo cenário, com:

1. nome preenchido automaticamente pelo Microsoft SSO;
2. e-mail preenchido automaticamente pelo Microsoft SSO;
3. título;
4. descrição do problema;
5. descrição de como o problema afeta a Safra.

Fluxo aprovado:

1. Jair recebe a proposta;
2. Jair encaminha para Daniel, Renato e Jiane;
3. exatamente 1 aceite -> esse usuário vira owner;
4. 2 ou mais aceites -> Jair decide;
5. nenhum aceite -> Jair decide ou aciona Bruno.

A proposta não vira cenário produtivo automaticamente antes da definição do owner e da governança necessária.

### Pendência proposital para Frontend
Quando o projeto chegar à fase de Frontend, desenhar separadamente as visões de analytics para:

- Bruno — todos os cards e métricas;
- donos de card — métricas dos seus cards;
- Jair — visão de governança.


### Regra UNKNOWN x DEFERRED — 24/09/2026

Para o fechamento do SAFRA-C01:

- `UNKNOWN` / `WAITING_HUMAN_DECISION` material = bloqueia fechamento;
- `DEFERRED_TO_SAFRA-C04/C05/...` = decisão conscientemente adiada para fase responsável, com destino explícito;
- item deferido não deve ser tratado como desconhecido;
- nenhum campo material pode ser silenciosamente convertido em `false` ou default.


### Service class da aplicação — CRITICO — 24/09/2026

**APPROVED**

```text
service_class = CRITICO
SLO = 99,95%
RTO = 30 min
RPO = 5 min
```

A decisão classifica o próprio Painel Safra e não deve ser confundida com a criticidade CRITICAL/HIGH/MODERATE dos cenários.


### Application criticality — MEDIUM — 24/09/2026

**APPROVED**

```text
application_criticality = MEDIUM
```

A decisão é explícita do projeto e não altera a service class CRITICO nem a criticidade dos cenários.


### REPLICA desabilitada; recovery obrigatório — 24/09/2026

```text
replica_enabled = false
```

Não haverá segundo banco sincronizado.

Isso não significa ausência de backup.

Como o Painel Safra possui `service_class=CRITICO`, a estratégia de backup/restore e os testes de recuperação continuam obrigatórios e devem comprovar:

- RTO: 30 minutos;
- RPO: 5 minutos.

A implementação/evidência de recovery fica direcionada ao SAFRA-C09.


### Retenção — APPROVED — 24/09/2026

Dados pessoais identificáveis serão mantidos até o encerramento formal da Safra e enquanto forem necessários para auditoria e pós-mortem.

Depois disso:

- eliminar ou anonimizar identidade;
- preservar histórico operacional e métricas para análise entre Safras quando a identificação pessoal não for necessária.


---

## Fechamento formal G3 / G3.25 — 24/09/2026

### G3 — Documentação canônica
**PASS**

Evidências:
- fontes canônicas definidas;
- autoridade documental separada por assunto;
- decisões materiais registradas;
- histórico Git preservado;
- documentação atualizada durante o processo.

### G3.25 — PROJECT_PROFILE
**PASS**

Evidências:
- service_class = CRITICO;
- application_criticality = MEDIUM;
- RTO = 30 min;
- RPO = 5 min;
- Microsoft Entra ID / SSO aprovado;
- papéis e responsabilidades registrados;
- dados pessoais e retenção registrados;
- replica_enabled = false;
- backup/recovery obrigatório;
- API pública = false;
- integrações MVP = false;
- decisões futuras possuem destino explícito;
- unknown_material_count = 0.

Próxima fase canônica: **SAFRA-C02 — Threat model e abuso de negócio**.


---

## SAFRA-C02 — início do threat model — 24/09/2026

Escopo inicial aprovado:

- START;
- END;
- owner;
- criticidade;
- timestamps;
- cancelamento;
- edição/versionamento de cenário.

Decisões-base para o modelo:

- qualquer usuário Microsoft autenticado pode executar START, END e CANCEL;
- scenario_owner responde pelo card e pelo protocolo com sua equipe, sem exclusividade sobre START/END/CANCEL;
- timestamps oficiais devem ser server-side;
- CANCEL exige motivo e preserva histórico;
- cenário publicado deve ser versionado e não pode ser alterado retroativamente;
- mudanças de owner, criticidade ou protocolo exigem governança/versionamento;
- tratativa ativa permanece vinculada à versão do cenário vigente no START;
- ações críticas devem ser auditáveis e idempotentes.

Threat cases a detalhar/testar:

1. START indevido ou duplicado;
2. END prematuro ou repetido;
3. alteração indevida de owner;
4. mudança de criticidade para evitar ou provocar comunicação;
5. adulteração de timestamps;
6. CANCEL usado para mascarar histórico;
7. edição de cenário publicado;
8. nova versão afetando tratativa já ativa;
9. proposta do 12º card tentando virar cenário operacional sem governança.

Destino técnico:

- C04: identidade/autorização;
- C05: constraints/RPCs;
- C06: versionamento/seed;
- C07/M04: timestamps e SLA;
- M01: state machine;
- M05: notificações;
- M10: governança de cenário;
- F01/F02: END/CANCEL.


### C02.2 — API, enumeração, vazamento, retry e manipulação de SLA — 24/09/2026

Casos formalizados:

- **AB-API-01 — Bypass da UI por Data API/RPC**
  - regra: segurança não pode depender da interface;
  - API/RPC deve aplicar as mesmas autorizações e invariantes;
  - teste obrigatório via chamada direta sem usar a UI.

- **AB-DATA-01 — Enumeração de dados**
  - risco: listar usuários, e-mails, cards, IDs ou histórico além da necessidade;
  - controles: RLS/escopo mínimo, consultas server-side e auditoria de leitura anômala;
  - testar ID direto, paginação e chamadas fora dos filtros da interface.

- **AB-LEAK-01 — Vazamento de dados internos**
  - minimizar respostas, logs, erros e payloads de notificação;
  - não expor secrets/tokens nem dados pessoais desnecessários;
  - testar API, console, logs, erros e notificações.

- **AB-RETRY-01 — Duplicidade por retry**
  - START/END/CANCEL/notificação precisam ser idempotentes;
  - correlation_id/idempotency key e constraints devem impedir duplicidade;
  - testar duplo clique, concorrência, timeout, refresh e retry.

- **AB-SLA-01 — Manipulação para parar SLA**
  - SLA deriva de eventos e timestamps válidos persistidos no backend;
  - CANCEL não significa automaticamente SLA cumprido;
  - END só fecha relógio cujo end_event corresponda à regra do SLA;
  - status/timestamp não podem ser alterados diretamente para interromper relógio;
  - correção administrativa deve ser auditável e append-only.

Destino dos controles:

- C04: autorização/RLS;
- C05: RPCs, constraints, idempotência e integridade;
- C07/M04: cálculo e lifecycle de SLA;
- M05: idempotência de notificações;
- F01/F02: semântica segura de END/CANCEL;
- F08: testes diretos de API e E2E de abuso.


### C02.3 — Testes derivados dos abuse cases

#### Positivos
- usuário Microsoft autenticado executa START em cenário PUBLISHED e recebe sucesso;
- START persiste ator autenticado, timestamp server-side e scenario_version_id vigente;
- usuário autenticado executa END em tratativa ACTIVE;
- CANCEL com justificativa válida encerra como CANCELLED e preserva histórico;
- owner vigente recebe comunicação prevista para seu card;
- nova scenario_version publicada só vale para novos STARTs;
- chamada direta à API/RPC permitida produz o mesmo resultado da UI;
- SLA encerra apenas quando ocorre o end_event definido na sua regra.

#### Negativos
- usuário não autenticado não executa START/END/CANCEL;
- START em cenário DRAFT/PROPOSED/INACTIVE falha;
- START com scenario_id inexistente ou version_id arbitrário falha;
- END em RESOLVED/CANCELLED falha;
- CANCEL sem justificativa falha;
- tentativa de editar owner/criticidade/protocolo de versão publicada falha;
- tentativa de alterar opened_at/closed_at/cancelled_at pelo cliente falha ou é ignorada;
- acesso direto a dado não autorizado por ID/API falha;
- paginação/filtro não amplia escopo autorizado;
- resposta de erro não expõe token, secret, stack sensível ou dados pessoais desnecessários;
- proposta do 12º card não aceita START antes de publicação governada;
- alteração direta de status não interrompe SLA.

#### Concorrência e retry
- dois STARTs simultâneos equivalentes não criam duplicidade indevida;
- duplo clique em START gera uma única tratativa;
- retry após timeout de START retorna o mesmo resultado idempotente;
- dois ENDs simultâneos geram um único encerramento;
- END e CANCEL concorrentes resultam em uma única transição válida;
- retry de CANCEL não duplica evento nem notificação;
- mesma notificação reenviada com a mesma chave não gera dois e-mails;
- concorrência de publicação de scenario_version não cria duas versões correntes;
- correlação/idempotency key é persistida e reutilizável para reconciliação.

#### Limite / borda
- START exatamente na troca de versão usa uma única versão determinada pelo backend;
- END exatamente no instante de breach de SLA produz resultado determinístico;
- occurrence_started_at igual ao START é aceito;
- occurrence_started_at no futuro é rejeitado;
- timestamps em borda de timezone/DST não alteram duração real;
- CANCEL imediatamente após START preserva ambos os eventos;
- cenário com criticidade alterada após START mantém a criticidade congelada da versão usada;
- volume alto de paginação não permite enumeração além do escopo;
- lista vazia autorizada é distinguida de forbidden/erro;
- 0, null e ausência de timestamp não são tratados como equivalentes;
- retry depois de resposta perdida não cria novo evento;
- SLA com múltiplos end_events fecha somente o relógio correspondente.

### Critérios de evidência

Cada teste deve registrar:
- identidade/role do ator;
- request/correlation_id;
- estado anterior;
- ação;
- resultado HTTP/domínio;
- estado posterior;
- eventos de auditoria;
- timestamps oficiais;
- notificações geradas ou não;
- evidência de que não houve mutação colateral.

### Destino

- C04: autenticação, RBAC e RLS;
- C05: RPCs, constraints, idempotência e concorrência;
- C06: versionamento/publicação de cenários;
- C07/M04: relógios, SLA e bordas temporais;
- M05: notificações e deduplicação;
- F01/F02: END/CANCEL;
- F08: execução E2E da matriz completa.


---

## Roadmap v2.1 promovido a canônico — 25/09/2026

O arquivo `docs/ROADMAP.md` foi substituído pela versão consolidada 2.1.

Principais efeitos:

- C00 e C01 permanecem concluídos;
- C02 permanece fase ativa;
- decisões posteriores ao roadmap v2.0 foram incorporadas;
- modelo de acesso START/END/CANCEL foi alinhado às decisões atuais;
- papéis administrativos e ownership foram reconciliados;
- checklist operacional deixou de ser requisito estrutural do Painel;
- critérios de entrada/saída, dependências, evidências e dívida de decisão foram reforçados;
- roadmap v2.1 passa a ser a fonte canônica de sequência de execução.

Commit de promoção do roadmap: `f36f04d7d14c09cf5ee8a56b511c63081d6acb4f`.


---

## Fechamento formal SAFRA-C02 — 25/09/2026

**Status: CONCLUÍDO**

Resultado:
- ameaças materiais modeladas;
- controles definidos;
- testes positivos, negativos, concorrência/retry e limite derivados;
- critérios de evidência definidos;
- riscos residuais classificados;
- cada risco residual possui fase responsável;
- nenhum bloqueador material sem destino permanece no C02.

Gates:
- **G3.5 = PASS**
- **THREAT-001 = PASS**
- **AUTHZ-001 = PASS**

Leitura correta do fechamento:
- o modelo de ameaça e o contrato de autorização estão aprovados;
- RLS/RBAC finais ainda serão implementados em C04;
- RPCs/constraints/idempotência/schema serão implementados em C05;
- demais controles seguem para C06/C07/M04/M05/M10/F01/F02/F08 conforme roadmap.

Próxima fase canônica: **SAFRA-C03 — Glossário e modelo de domínio**.


---

## SAFRA-C03 — vocabulário canônico congelado — 25/09/2026

Criado `docs/GLOSSARIO_DOMINIO.md` como fonte canônica do vocabulário funcional do Painel Safra.

Termos congelados:
- cenário;
- versão de cenário;
- gatilho;
- detecção;
- START;
- protocolo;
- tratativa;
- owner;
- área responsável;
- área impactada;
- SLA;
- criticidade;
- END;
- CANCEL;
- escalonamento;
- pós-mortem;
- recorrência;
- proposta de cenário;
- publicação de cenário.

Distinções obrigatórias registradas:
- cenário != tratativa;
- cenário != versão;
- gatilho != detecção;
- START != detecção;
- protocolo != tratativa;
- owner != ator do START;
- área responsável != área impactada;
- SLA != SLO/RTO/RPO;
- criticidade != escalonamento;
- END != CANCEL;
- proposta != cenário publicado;
- incidente TI != tratativa Safra.

Commit de criação do glossário: `a5c88ba535d3bade70781d37382eb69c894f9fcd`.


---

## SAFRA-C03 — cenário, versão, tratativa e impacto formalizados — 25/09/2026

Decisões congeladas:

```text
scenario = identidade estável
scenario_version = fotografia imutável do conteúdo vigente
treatment = ocorrência real criada por START
```

Impacto:

- qualitativo = descrição contextual das consequências;
- quantitativo = métrica + valor + unidade + fonte + referência temporal;
- cenário/versão pode registrar impacto esperado;
- tratativa registra impacto observado;
- desconhecido não é zero;
- impacto não muda criticidade, escalonamento, status ou SLA automaticamente;
- não criar score/faixas/thresholds sem fonte de negócio.

Desenho conceitual para C05/F04:
- `treatments.impact_summary` para qualitativo;
- coleção separada de medições quantitativas por tratativa.


---

## SAFRA-C03 — criticidade CRITICAL mantida como governance issue — 25/09/2026

Foi feita revisão conservadora das fontes de negócio.

Resultado:

- a Matriz v3 não contém coluna formal de criticidade;
- a reunião de 22/09 confirma níveis CRITICAL/HIGH/MODERATE e menciona quatro temas “super pesados”;
- a reunião não identifica nominalmente os quatro;
- o PDF v2 é preliminar e não fornece lista formal dos quatro.

Decisão:

```text
GI-SAFRA-001 = OPEN
inferência da lista CRITICAL = PROIBIDA
```

Até resolução formal:
- nenhum dos 11 cenários será marcado como CRITICAL apenas por interpretação;
- regras específicas de comunicação à diretoria baseadas na lista dos quatro permanecem dependentes da decisão;
- C06 deve carregar a pendência sem preencher default.


---

## SAFRA-C03 — glossário READY_FOR_C05 — 25/09/2026

`docs/GLOSSARIO_DOMINIO.md` atualizado para v1.1 e marcado `READY_FOR_C05`.

Foram eliminadas ambiguidades de implementação sobre:
- cenário x versão x tratativa;
- estados de cenário/versão/tratativa;
- owner atual x owner histórico;
- área responsável atual x snapshot da tratativa;
- áreas/sistemas potenciais versionados;
- criticidade pendente sem default;
- END x CANCEL em persistência;
- impacto quantitativo;
- recorrência;
- pós-mortem;
- múltiplas tratativas simultâneas;
- proposta x cenário.

C05 recebeu regra explícita de não inventar decisões ainda deferidas.


---

## SAFRA-C04 — Microsoft SSO homologado — 25/09/2026

Implementação concluída no repositório:

- `AuthProvider` com Microsoft Entra via Lovable Cloud Auth e sessão Supabase;
- `AuthGate` protege toda a aplicação;
- único método funcional de entrada: Lovable Cloud Auth com provider `microsoft`;
- escopo Microsoft `email`;
- sessão Supabase restaurada e observada via `onAuthStateChange`;
- logout disponível;
- token da sessão continua sendo anexado às server functions;
- middleware server-side valida JWT e usa o `sub` como identidade;
- nenhum `signInWithPassword`, `signUp` ou recovery por senha foi implementado;
- `.env.example` documenta `VITE_AUTH_REDIRECT_URL`.

Estado de homologação:

**PASS / HOMOLOGATED**

Homologação confirmada:
- provider Microsoft configurado via GitHub/Lovable Cloud Auth;
- login corporativo real executado com sucesso;
- `auth.users` contém usuário autenticado;
- `auth.identities.provider = azure`;
- `last_sign_in_at` preenchido;
- Lovable sincronizado com os commits posteriores à configuração;
- cadeia de sessão Supabase pronta para uso de `auth.uid()`.

A implementação atual utiliza `@lovable.dev/cloud-auth-js` como broker de autenticação Microsoft e, após retorno bem-sucedido, grava os tokens na sessão Supabase.


---

## SAFRA-C04 — role mapping implementado sem ownership automático — 25/09/2026

Implementado no Lovable Cloud PRIMARY:

- `private.safra_principals`;
- `private.safra_role_grants`;
- vínculo por e-mail corporativo -> `auth.uid()`;
- trigger de binding após criação/atualização de usuário Auth;
- `private.safra_has_role(...)`;
- `private.get_my_safra_roles()`;
- wrappers `public.safra_has_role(...)` e `public.get_my_safra_roles()` como `SECURITY INVOKER`.

Role mapping ativo:
- Kaue, Amanda, Vinicius, João -> `safra_platform_admin`;
- Jair -> `safra_governance_admin`;
- Bruno -> `safra_executive_admin`;
- Daniel, Jiane, Renato -> `scenario_owner`.

Validação runtime com role PostgreSQL `authenticated`:
```text
auth.uid() = usuário Microsoft autenticado
roles = [safra_platform_admin]
safra_has_role(platform_admin) = true
safra_has_role(scenario_owner) = false
```

Regra preservada:
- platform/governance/executive admin não recebem ownership automático;
- `scenario_owner` não significa ownership de cenário específico;
- vínculo cenário->owner será entidade separada em C05/C06.

Pendência:
- RLS legado C00 ainda depende de `app_metadata.safra_access`;
- migração das policies para o role mapping definitivo é próximo subpasso do C04.


---

## Sincronização Lovable — fallback de ambiente e tipos RBAC — 25/09/2026

Commit Lovable revisado: `91417ab45a70233d9603ba50259bd744b35fc67b` — **Added fallback env vars**.

Mudanças confirmadas:

1. `src/integrations/supabase/types.ts`
   - passou a tipar `get_my_safra_roles()`;
   - passou a tipar `safra_has_role(requested_role)`;
   - frontend agora reconhece os RPCs criados pelo role mapping.

2. `vite.config.ts`
   - adicionou fallback para `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY`;
   - replica os valores públicos para `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` no build;
   - usa apenas URL pública e publishable key; nenhum `service_role` foi introduzido.

Impacto:
- correção compatível com o role mapping implementado;
- evita falha de preview/build quando o arquivo `.env` não está presente;
- publishable key continua sendo credencial pública por desenho;
- manter atenção futura para evitar acoplamento indevido entre ambientes dev/preview/prod.


---

## SAFRA-C04 — RLS e autorização equivalente UI/REST/RPC/server — 25/09/2026

Implementado no Lovable Cloud PRIMARY:

- removida dependência de `app_metadata.safra_access`;
- criado `public.safra_is_corporate_user()` como predicado canônico de acesso base;
- RLS de `applications` e `incidents` passa a usar esse predicado;
- `anon` sem grants de leitura;
- `authenticated` recebe apenas grants compatíveis com o produto legado atual;
- middleware server-side consulta o mesmo RPC canônico;
- frontend/Data API continua sujeito ao RLS;
- RPC usa o mesmo contexto `auth.uid()`/JWT;
- `user_metadata` não participa de autorização;
- roles permanecem em tabelas governadas privadas.

Predicado base:

```text
auth.uid() != null
AND is_anonymous != true
AND app_metadata.provider = azure
AND email termina com @editoradobrasil.com.br
```

Validação:

- usuário Microsoft corporativo: 3 applications / 14 incidents;
- outsider autenticado: 0 / 0;
- anon: sem SELECT e sem EXECUTE no RPC;
- `safra_access` removido de `auth.users.raw_app_meta_data`;
- role mapping continua independente de ownership.

Observação de governança:
- a alteração live foi aplicada no PRIMARY;
- como a autoridade canônica de migrations ainda pertence ao C05, esta mudança deverá ser reconciliada em migration formal naquela fase.


---

## Migration canônica C04 versionada — 25/09/2026

Arquivo:

`supabase/migrations/20260925133200_c04_role_mapping_and_corporate_rls.sql`

Conteúdo capturado:
- principals e role grants privados;
- binding e-mail corporativo -> `auth.uid()`;
- role mapping governado;
- predicado `safra_is_corporate_user()`;
- RLS de `applications` e `incidents`;
- remoção do gate legado `safra_access`;
- grants compatíveis com Data API;
- wrappers públicos `SECURITY INVOKER`.

Governança:
- `supabase/migrations` passa a ser a autoridade canônica;
- Drizzle não é fonte de verdade de migration/schema;
- a migration representa o estado live já validado.

Pendência administrativa:
- o histórico remoto `supabase_migrations.schema_migrations` ainda não contém todas as migrations aplicadas fora do fluxo formal;
- regularizar por migration repair quando houver CLI/acesso apropriado;
- não editar manualmente a tabela interna como substituto do repair.


---

## SAFRA-C04 — revisão formal dos gates de identidade — 25/09/2026

A revisão contra o Manual Operacional EBSA v1.7 mostrou que os gates não podem ser fechados apenas com SSO/RLS funcionando.

Estado:

```text
G5 = PARTIAL
ID-001 = BLOCKED_EVIDENCE
ID-002 = BLOCKED_EVIDENCE
AUDIT-001 = BLOCKED_EVIDENCE
```

Evidências existentes:
- Entra ID / SSO homologado;
- auth.uid() funcional;
- role mapping em tabelas governadas;
- RLS positiva/negativa;
- anon bloqueado;
- outsider autenticado bloqueado;
- elevação direta de role negada;
- platform admin não herda ownership;
- mesma regra-base para Data API/RPC/server.

Lacunas para fechamento:
- ID-001: testar troca de papel, revogação, desligamento/sessão antiga, recuperação e definir contas de serviço;
- ID-002: revisar acessos privilegiados e MFA conforme risco;
- AUDIT-001: persistir ator, ação, recurso, data, resultado e correlation_id das ações sensíveis.

Os testes de START/END/CANCEL permanecem deferidos para C08.1/F02.1 e não bloqueiam esta leitura dos gates do C04.


---

## SAFRA-C04 — teste de sessão expirada — 25/09/2026

**PASS**

Validação em duas camadas:

- middleware server-side usa `supabase.auth.getClaims(token)`, que valida assinatura e expiração do JWT;
- `public.safra_is_corporate_user()` passou a exigir também `exp > now()`.

Teste determinístico no RLS:

```text
JWT corporativo válido:
corporate_ok = true
applications_visible = 3

mesmo usuário com exp vencido:
corporate_ok = false
applications_visible = 0
```

Resultado: sessão/JWT expirado não produz autorização nem leitura protegida.

Próximo item C04.4: troca de papel.


---

## SAFRA-C04 — bateria ID-001/ID-002/AUDIT-001 — 25/09/2026

Resultado geral: **NÃO AVANÇAR PARA C05 AINDA**.

### Matriz

| Item | Resultado | Evidência / gap |
|---|---|---|
| troca de papel | BLOCKED / CLEANUP REQUIRED | grant temporário de governance foi criado para o principal técnico de teste; leitura/revogação subsequentes foram bloqueadas pelos conectores. Assumir ativo até verificação/limpeza. |
| revogação de papel | BLOCKED | conectores bloquearam UPDATE/DELETE no grant temporário; não marcar PASS. |
| desligamento / sessão antiga | FAIL CONTROL GAP | getClaims valida assinatura/expiração, mas não confirma existência atual da sessão após logout/revogação; falta validação de session_id contra auth.sessions para garantia forte. |
| recuperação de acesso | EXTERNAL / N/A LOCAL | aplicação não implementa senha nem recovery local; autenticação é delegada ao Microsoft Entra. Falta evidência do processo corporativo de recuperação. |
| contas de serviço | N/A MVP | nenhum service account / service credential do produto encontrado no repositório; registrar explicitamente que não há conta de serviço no MVP. |
| MFA privilegiado | BLOCKED_EXTERNAL | não há evidência no repositório sobre Conditional Access/MFA do Entra para Kaue/Amanda/Vinicius/João/Jair/Bruno. Supabase AAL não deve ser usado para inferir MFA do provedor externo. |
| AUDIT-001 identidade/RBAC | FAIL / NOT IMPLEMENTED | não foram encontrados audit_events, correlation_id, granted_by/revoked_by ou trilha equivalente para mudanças de acesso. |

### Ação corretiva prioritária

1. verificar e revogar/remover o grant temporário `source = C04_ID001_TEMP_TEST`;
2. implementar validação de sessão ativa por `session_id` para ações sensíveis/autorizações que exigem revogação imediata;
3. implementar trilha de auditoria de RBAC com ator, ação, recurso, data, resultado e correlation_id;
4. registrar formalmente contas de serviço como N/A no MVP, salvo decisão contrária;
5. obter com TI/Entra evidência do fluxo de recuperação de acesso e da política MFA/Conditional Access para papéis privilegiados;
6. somente então repetir troca/revogação e fechar ID-001/ID-002/AUDIT-001.

Gates permanecem:

```text
G5 = PARTIAL
ID-001 = BLOCKED_EVIDENCE
ID-002 = BLOCKED_EVIDENCE
AUDIT-001 = BLOCKED_EVIDENCE
```


---

## SAFRA-C04 — estratégia de fechamento via Lovable — 25/09/2026

Decisão operacional: concluir os controles restantes do C04 no próprio ambiente Lovable Cloud, onde o projeto possui contexto de backend suficiente para testar RBAC e sessões sem depender dos bloqueios dos conectores externos.

### Prioridade zero

Antes de qualquer novo teste:
- localizar grant ativo com `source = C04_ID001_TEMP_TEST`;
- revogar/remover esse grant;
- confirmar que Kaue permanece apenas com `safra_platform_admin`;
- registrar evidência antes/depois.

### Itens a concluir no Lovable

- troca de papel;
- revogação de papel;
- validação de sessão revogada/desligamento por `session_id` contra `auth.sessions`;
- trilha AUDIT-001 de RBAC;
- registrar contas de serviço como `NOT_APPLICABLE_MVP` se não houver identidade funcional de serviço.

### Itens externos ao Lovable

- recuperação de acesso corporativo: evidência do Microsoft Entra/TI;
- MFA privilegiado: evidência de Conditional Access/MFA no Microsoft Entra.

### Limites

Não criar nem antecipar:
- scenarios;
- scenario_versions;
- scenario_owners;
- treatments;
- START/END/CANCEL;
- seed dos 11 cenários.

Toda mudança permanente deve terminar versionada no GitHub e em `supabase/migrations`.

Estado dos gates permanece:

```text
G5 = PARTIAL
ID-001 = BLOCKED_EVIDENCE
ID-002 = BLOCKED_EVIDENCE
AUDIT-001 = BLOCKED_EVIDENCE
```

---

## SAFRA-C04 — Execução de fechamento no Lovable Cloud (25/09/2026)

Backend PRIMARY: Lovable Cloud (PostgreSQL/Supabase). Login exclusivamente Microsoft Entra.
Autorização exclusivamente por `private.safra_principals` + `private.safra_role_grants`.
`user_metadata`/`app_metadata` deixaram de participar de qualquer decisão de autorização.

### Tabela de controles

| Controle | Resultado | Evidência |
| --- | --- | --- |
| TEMP_GRANT_CLEANUP | PASS | Grant `dbd8e950-fb85-4e78-99ab-bb4d10641164` (`safra_governance_admin`, `source = C04_ID001_TEMP_TEST`) revogado em `2026-09-25 16:41:53Z`. Consulta posterior: `count(*) = 0` de grants ativos com esse source; Kaue permanece somente com `safra_platform_admin` (`PROJECT_DECISION`). |
| ROLE_CHANGE | PASS | `private.safra_c04_test_runs`, controle `ROLE_CHANGE`: mesmo `auth.uid()`, grant governado adicionado; `get_my_safra_roles()` → `{safra_platform_admin, scenario_owner}` e `safra_has_role('scenario_owner') = true` imediatamente, sem refresh de token/metadata. |
| ROLE_REVOCATION | PASS | Mesmo run, controle `ROLE_REVOCATION`: após `revoked_at`, `get_my_safra_roles()` → `{safra_platform_admin}` e `safra_has_role('scenario_owner') = false` na mesma sessão JWT. `authenticated` não possui privilégio algum em `private.safra_role_grants` (SELECT/INSERT = false), logo o browser não restaura o papel por payload. |
| REVOKED_SESSION | PASS | `private.safra_session_is_live()` valida o claim `session_id` contra `auth.sessions`. Evidências: sessão existente → `true`; `session_id` inexistente/revogado → `false`; JWT expirado → `false`; sessão viva + JWT válido → `true`. A verificação é banco/server-side e integra `public.safra_is_corporate_user()`, usada pelas policies de `applications` e `incidents`. |
| SERVICE_ACCOUNT_SCOPE | NOT_APPLICABLE_MVP | `auth.users` contém apenas identidades humanas corporativas. Nenhuma identidade funcional de serviço usa o Painel. O `service_role` é credencial técnica do backend, nunca exposta ao frontend, e não é classificada como usuário funcional. Se uma conta de integração for criada, ID-001 deve ser reaberto. |
| RBAC_AUDIT_TRAIL | PASS | `private.safra_rbac_audit_events` (append-only) + trigger `trg_safra_audit_role_grant_change`. Run de teste gerou 4 eventos (`ROLE_GRANTED`, `ROLE_REVOKED`, `ROLE_GRANT_DELETED`, `ACCESS_DENIED`) com ator (`kaue.pastrello@editoradobrasil.com.br`), ação, recurso, horário do servidor, resultado e `correlation_id` comum. Tentativa de `UPDATE` no histórico falhou com `private.safra_rbac_audit_events is append-only`, inclusive em sessão privilegiada. Nenhum secret ou token é registrado. |
| ENTRA_RECOVERY | EXTERNAL_CORPORATE_CONTROL | Recuperação de acesso é responsabilidade direta da TI com a Microsoft/Entra. O Painel não implementa recovery próprio, senha local ou fluxo paralelo. Fora do escopo da aplicação. |
| PRIVILEGED_MFA | EXTERNAL_CORPORATE_CONTROL | Bloqueio, MFA e Conditional Access da identidade Microsoft são responsabilidade da TI/Microsoft Entra. O Painel não cria MFA paralelo nem governa o bloqueio da conta corporativa. Fora do escopo da aplicação. |

### Objetos criados

- `private.safra_rbac_audit_events` (append-only, RLS habilitada, sem privilégios para `anon`/`authenticated`).
- `private.safra_rbac_audit_immutable()` + trigger impedindo UPDATE/DELETE.
- `private.safra_correlation_id()`, `private.safra_log_rbac_event(...)`.
- `private.safra_audit_role_grant_change()` + trigger `trg_safra_audit_role_grant_change` em `private.safra_role_grants`.
- `public.safra_log_access_denied(text, text)` — autoria e horário resolvidos server-side.
- `public.get_safra_rbac_audit_events(integer)` — leitura restrita a `safra_platform_admin` / `safra_governance_admin`.
- `private.safra_session_is_live()` e `public.safra_session_is_live()` — ID-002.
- `public.safra_is_corporate_user()` atualizada: identidade corporativa Entra + JWT não expirado + sessão viva em `auth.sessions`.
- `private.safra_c04_test_runs` + `private.safra_c04_selftest(text)` — bateria controlada e reversível de evidência.

### Frontend

- Removido `src/lib/safra-access.functions.ts` (concessão de `app_metadata.safra_access`); a claim não é mais fonte de autorização.
- `AuthProvider` deixou de escrever metadata e passou a encerrar a sessão com `scope: "global"`, removendo a linha em `auth.sessions` — o token em cache deixa de ser aceito imediatamente.

### Estado dos gates após o C04

```text
G5 = PASS
ID-001 = PASS_APP_SCOPE
ID-002 = PASS_APP_SCOPE
AUDIT-001 = PASS
```

Observação de trilha de migrations: o ambiente Lovable aplica migrations através do
Drizzle (`drizzle/migrations/0001..0003`), e `supabase/migrations` é somente leitura
neste ambiente. O SQL aplicado está integralmente reproduzido nesses arquivos e deve
ser espelhado em `supabase/migrations` no repositório canônico durante a sincronização
já pendente do histórico (ADR-027).


### Auditoria independente pós-Lovable — 25/09/2026

Verificação independente confirmou:
- grant temporário ativo = 0;
- Kaue possui apenas `safra_platform_admin` ativo;
- ROLE_CHANGE = PASS;
- ROLE_REVOCATION = PASS;
- REVOKED_SESSION = PASS para sessão existente, inexistente/revogada e JWT expirado;
- rollback do teste = PASS;
- RBAC_AUDIT_TRAIL = PASS com eventos ROLE_GRANTED, ROLE_REVOKED, ROLE_GRANT_DELETED e ACCESS_DENIED;
- policies de applications/incidents continuam usando `safra_is_corporate_user()`.

Correção de governança:
- `ID-001` não é considerado totalmente fechado enquanto a evidência do processo corporativo de recuperação de acesso no Microsoft Entra/TI estiver pendente;
- `ID-002` não é considerado totalmente fechado enquanto MFA/Conditional Access dos privilegiados estiver sem evidência externa;
- `AUDIT-001` pode ser considerado PASS no escopo de RBAC do C04;
- as migrations geradas pelo Lovable em Drizzle foram espelhadas para `supabase/migrations`, que permanece a fonte canônica.

Estado:
```text
G5 = PASS
ID-001 = PASS_APP_SCOPE
ID-002 = PASS_APP_SCOPE
AUDIT-001 = PASS
```


---

## SAFRA-C04 — fechamento formal por fronteira de responsabilidade — 25/09/2026

Decisão humana de escopo:

- recuperação de acesso Microsoft é responsabilidade direta da TI junto à Microsoft/Entra;
- bloqueio de acesso, MFA e Conditional Access da conta Microsoft também são responsabilidade da TI/Microsoft Entra;
- o Painel Safra não implementa, duplica nem audita esses controles corporativos;
- a aplicação apenas consome a identidade Microsoft autenticada e aplica seus próprios controles de sessão, RBAC, RLS e auditoria.

Classificação:

```text
ENTRA_RECOVERY = EXTERNAL_CORPORATE_CONTROL
PRIVILEGED_MFA = EXTERNAL_CORPORATE_CONTROL
```

Esses itens deixam de ser bloqueadores do ciclo da aplicação. Isso não significa que o Painel auditou ou certificou os controles do Entra; significa somente que sua governança pertence ao ambiente corporativo externo.

Fechamento do C04 no escopo do Painel:

```text
TEMP_GRANT_CLEANUP = PASS
ROLE_CHANGE = PASS
ROLE_REVOCATION = PASS
REVOKED_SESSION = PASS
SERVICE_ACCOUNT_SCOPE = NOT_APPLICABLE_MVP
RBAC_AUDIT_TRAIL = PASS
ENTRA_RECOVERY = EXTERNAL_CORPORATE_CONTROL
PRIVILEGED_MFA = EXTERNAL_CORPORATE_CONTROL

G5 = PASS
ID-001 = PASS_APP_SCOPE
ID-002 = PASS_APP_SCOPE
AUDIT-001 = PASS
SAFRA-C04 = CONCLUIDO
```

Próxima fase canônica: **SAFRA-C05 — Schema v2, migrations e invariantes**.


---

> **C05-AUD — Schema v2, migrations e invariantes aberta em 28/09/2026 às 08:56 BRT.** Branch exclusiva: `audit/c05-schema-v2-migrations-invariants-2026-09-28`. O C05 histórico permanece preservado. Auditoria atual confirmou 28/28 migrations Git=PRIMARY, schema v2 17/17, 36 FKs, 0 cascade destrutivo e guards históricos funcionando. Foram abertos **6 achados**: status de notificação não governado; ausência de regressão permanente de version freeze; ausência de concorrência real END x CANCEL; rollback que valida apenas tracking; ausência de smoke HTTP autenticado da Data API; e definição pendente de “RLS positiva” no desenho RPC-only. Há ainda 3 melhorias de higiene (Drizzle residual, 5 FKs sem índice de suporte e triggers redundantes de updated_at). Fonte: `docs/AUDITORIA_C05_REABERTURA_2026-09-28.md`.

> **C05-AUD decisões executadas em 28/09/2026 às 09:12 BRT.** C05-AUD-01 foi fechado com os estados canônicos `QUEUED/SENT/FAILED`, máquina `QUEUED -> SENT|FAILED`, estados terminais e timestamps server-side. Migration `20260928090910_c05_notification_delivery_state_machine.sql` promovida ao PRIMARY; regressão nova **10/10 PASS** e suítes C05 existentes **23/23 + 7/7 PASS**. C05-AUD-06 foi fechado com a **Opção A**: autorização positiva por RPC governada; tabelas Safra permanecem deny-by-default sem policy positiva de Data API. Restam **4 pendências técnicas** (version freeze regression, END x CANCEL concorrente, rollback estrutural, HTTP authenticated direct API) e **3 melhorias de higiene** (Drizzle residual, 5 índices FK, triggers redundantes).

## SAFRA-C05 — schema v2 canônico materializado — 25/09/2026

Migration canônica:

`supabase/migrations/20260925170000_c05_schema_v2_canonical_base.sql`

Estado:
- aplicado no Lovable Cloud PRIMARY;
- 17 tabelas de domínio novas;
- RLS habilitada em todas;
- deny-by-default para `anon` e `authenticated`;
- `service_role` mantém acesso técnico, sem `TRUNCATE`;
- legado `applications/incidents` preservado sem alteração.

### Entidades criadas

- `operational_areas`
- `systems`
- `scenarios`
- `scenario_versions`
- `scenario_owners`
- `scenario_version_impacted_areas`
- `scenario_version_systems`
- `scenario_slas`
- `treatments`
- `treatment_impacted_areas`
- `treatment_impact_measurements`
- `treatment_events`
- `treatment_escalations`
- `scenario_proposals`
- `scenario_proposal_owner_responses`
- `notifications_log`
- `governance_issues`

RBAC continua usando:
- `private.safra_principals`
- `private.safra_role_grants`

Não foi criada tabela concorrente `safra_user_roles`.

### Invariantes implementados

- uma versão PUBLISHED corrente por cenário;
- uma relação de owner ativa por cenário;
- owner de cenário publicado precisa possuir role ativa `scenario_owner`;
- cenário publicado exige área responsável;
- `scenario.current_version_id` precisa apontar para a versão PUBLISHED;
- versão PUBLISHED é imutável, exceto transição para RETIRED;
- versão RETIRED é imutável;
- criticidade aceita null e não possui default;
- criticidade não nula limitada a CRITICAL/HIGH/MODERATE;
- treatment congela scenario/version/owner/área responsável no START;
- snapshot de START é imutável;
- tratamento fechado não reabre;
- CANCEL usa campos próprios, não `closed_at`;
- treatment_events é append-only;
- treatment_impact_measurements é append-only;
- correlation/idempotency keys estruturadas;
- sem unicidade de tratamento ACTIVE por cenário nesta fase;
- sem cascade destrutivo no histórico operacional.

### Governance issue preservado

`GI-SAFRA-001` foi materializado como `OPEN`.

Nenhum dos quatro cenários CRITICAL foi inferido.

### Self-tests

PASS:
- criticidade inválida rejeitada;
- publicação sem owner rejeitada;
- owner sem role `scenario_owner` rejeitado;
- owner elegível aceito;
- edição de versão PUBLISHED rejeitada;
- snapshot incorreto de treatment rejeitado;
- event update rejeitado por append-only;
- treatment RESOLVED não volta para ACTIVE;
- fixtures de teste revertidas integralmente;
- `service_role` sem TRUNCATE;
- nenhuma unique constraint de ACTIVE-per-scenario.

### Rollback

Como o schema v2 ainda não possui dados produtivos nem seed C06:
- rollback físico só é aceitável antes de qualquer dado produtivo;
- após C06, rollback deve ocorrer por migration corretiva/forward fix, não DROP destrutivo;
- o legado `applications/incidents` permanece disponível e não foi substituído.

### Itens explicitamente não implementados neste passo

- seed dos 11 cenários;
- criticidades dos quatro CRITICAL;
- thresholds 2/4/10/11;
- curva A;
- START/END/CANCEL RPCs;
- rule de múltiplos ACTIVE;
- provider de notificações;
- fluxo final do 12º card;
- pós-mortem;
- analytics.


---

## SAFRA-C05 — autoridade canônica de migrations e drift reconciliado — 25/09/2026

Decisão definitiva:

```text
supabase/migrations = ÚNICA FONTE CANÔNICA DE MIGRATIONS
Drizzle = ORM/tooling auxiliar, SEM autoridade de schema/deploy
```

Diagnóstico:
- Git possuía 8 migrations em `supabase/migrations`;
- o histórico remoto registrava apenas as duas migrations originais de agosto;
- C00/C04/C05 já estavam efetivamente aplicados no PRIMARY;
- `drizzle/migrations` continha cópias históricas de migrations já espelhadas em `supabase/migrations`.

Reconciliação executada:
- estado live pré-validado antes do repair;
- versões adicionadas ao tracking sem reexecutar SQL:
  - 20260924212155
  - 20260925133200
  - 20260925164500
  - 20260925164600
  - 20260925164700
  - 20260925170000
- `supabase_migrations.schema_migrations` agora contém as oito migrations conhecidas;
- nenhuma DDL foi reaplicada;
- nenhuma migration foi revertida.

Nota operacional:
- o comando oficial `supabase migration repair --status applied` não estava acessível pelos conectores disponíveis;
- foi executado repair equivalente somente na tabela de tracking, após validação explícita dos artefatos live;
- futuras mudanças de schema devem entrar primeiro em `supabase/migrations` e ser aplicadas pelo fluxo de migration, evitando novo drift.

Drizzle:
- `drizzle/schema.ts` permanece vazio;
- não existe script de deploy Drizzle no `package.json`;
- `drizzle/migrations` não é fonte de verdade e não deve ser usada para deploy.


---

## SAFRA-C05 — rollback, banco descartável e acesso Jair — 25/09/2026

### Rollback e banco descartável

Artefatos adicionados:
- `docs/ROLLBACK_E_BANCO_DESCARTAVEL.md`;
- `supabase/seed.sql` sem dados produtivos;
- `supabase/tests/database/c05_schema_v2.test.sql`;
- `.github/workflows/database-disposable-test.yml`.

Estratégia:
- banco descartável = Supabase local via CLI/Docker;
- rebuild obrigatório via `supabase db reset --local`;
- testes via `supabase test db` (pgTAP);
- lint via `supabase db lint --local --level error`;
- destruição ao final com `supabase stop --no-backup`;
- PRIMARY nunca é banco descartável;
- depois de C06, rollback destrutivo deixa de ser padrão; correções passam a ser forward fixes.

Cobertura inicial pgTAP:
- 17 tabelas do schema v2;
- RLS nas 17;
- anon sem grants diretos;
- authenticated sem grants diretos;
- criticidade sem default;
- GI-SAFRA-001 OPEN;
- ausência de unique ACTIVE por cenário;
- service_role sem TRUNCATE.

### Jair — acesso confirmado

`jair.silva@editoradobrasil.com.br` já autenticou no Painel via Microsoft Entra/Azure.

Evidência runtime:
- principal ativo;
- `user_id` vinculado;
- provider = `azure`;
- role ativa = `safra_governance_admin`;
- `last_sign_in_at = 2026-09-25 18:05:38.625392+00`.

Em horário de São Paulo, isso corresponde a aproximadamente **15:05 de 25/09/2026**.

Nenhum outro papel foi herdado por esse login.


### Evidência CI — Database Disposable Test

Workflow:
`.github/workflows/database-disposable-test.yml`

Run validado:
- run_id: `36176511561`;
- conclusão: **SUCCESS**.

Etapas com PASS:
- Setup Supabase CLI;
- Start disposable Supabase stack;
- Rebuild database from canonical migrations;
- Run database tests;
- Lint database;
- Stop disposable Supabase stack.

Isso comprova que o banco descartável consegue ser recriado do zero a partir de `supabase/migrations`, executar a bateria pgTAP, passar no lint e ser destruído ao final.


---

## SAFRA-C05 — domínio canônico consolidado por agregados — 25/09/2026

A criação física do domínio já estava materializada na migration canônica
`supabase/migrations/20260925170000_c05_schema_v2_canonical_base.sql`.
Nesta rodada o modelo foi auditado e reconciliado com a arquitetura canônica, sem criar tabela duplicada.

### Domínios e fontes de verdade

| Domínio | Persistência canônica |
|---|---|
| Áreas | `operational_areas`, `scenario_version_impacted_areas`, `treatment_impacted_areas` |
| Sistemas | `systems`, `scenario_version_systems` |
| Papéis | `private.safra_principals`, `private.safra_role_grants` |
| Cenários/versionamento | `scenarios`, `scenario_versions` |
| Owners | `scenario_owners` |
| SLAs | `scenario_slas` |
| Treatments | `treatments`, `treatment_impact_measurements` |
| Eventos | `treatment_events` |
| Escalonamentos | `treatment_escalations` |
| Notificações | `notifications_log` |
| Propostas | `scenario_proposals`, `scenario_proposal_owner_responses` |
| Governance issues | `governance_issues` |

### Regras estruturais confirmadas

- papéis administrativos não geram ownership;
- não criar `safra_user_roles` concorrente;
- cenário é identidade estável e versão é fotografia imutável;
- relações de áreas/sistemas/SLA pertencem à versão quando afetam conteúdo histórico;
- START congela scenario/version/owner/área responsável;
- treatment histórico não é apagado;
- eventos e medições históricas são append-only;
- escalonamento permanece separado do status;
- proposta não é cenário publicado;
- governance issue aberta não vira default;
- GI-SAFRA-001 permanece OPEN;
- múltiplos ACTIVE por cenário continuam sem constraint até M01.

### Segurança do domínio C05

As 17 tabelas novas permanecem:
- com RLS habilitada;
- deny-by-default para `anon` e `authenticated`;
- sem exposição operacional antecipada pela Data API;
- com acesso técnico de `service_role` sem `TRUNCATE`.

### Documentação reconciliada

`docs/ARQUITETURA.md` foi atualizado para refletir o estado real após C04/C05, removendo referências transitórias já superadas e descrevendo os agregados físicos atuais.

### Resultado

```text
C05_DOMAIN_MODEL = PASS
duplicate_role_model = false
schema_change_required_this_round = false
GI-SAFRA-001 = OPEN
```

Próximo subpasso do C05:
- RPCs/funções transacionais para mutações críticas;
- idempotência/correlation_id;
- concorrência START/END/CANCEL;
- invariantes temporais adicionais;
- testes diretos de API/RPC e pgTAP.


---

## SAFRA-C05 — FKs, constraints, timestamps server-side, version freeze, append-only e integridade temporal — 25/09/2026

Migration adicionada:
`supabase/migrations/20260925173000_c05_invariants_temporal_hardening.sql`

Aplicado e conferido no Lovable Cloud PRIMARY.

Controles reforçados:
- FK forte garante que `current_version_id` pertence ao mesmo cenário;
- publicação/retirada de versão usa horário do banco;
- áreas/sistemas/SLAs de versão publicada ou retirada ficam congelados;
- START/END/CANCEL recebem timestamps oficiais do banco;
- eventos de treatment recebem timestamp oficial do banco;
- histórico de eventos e medições permanece append-only;
- owners, áreas impactadas e escalonamentos preservam histórico temporal e não aceitam delete físico;
- alterações de áreas impactadas/escalonamentos só ocorrem enquanto a tratativa estiver ACTIVE;
- medições de impacto rejeitam horário materialmente futuro;
- notificações não podem ser enviadas/falhar antes de entrar na fila;
- governance issue não pode ser resolvida antes de ter sido aberta;
- propostas e respostas usam timestamps do banco.

Validação no PRIMARY confirmou a presença das novas FKs/constraints e dos triggers de proteção.

Testes pgTAP foram ampliados de 14 para 20 verificações para cobrir FK, timestamps server-side, version freeze e append-only.

Estado:
```text
C05_INTEGRITY_HARDENING = APPLIED
PRIMARY_VALIDATION = PASS
CI_DISPOSABLE_DB = RUNNING
```


---

## SAFRA-C05 — bateria técnica de migration, constraints, double submit, rollback, API direta e RLS — 25/09/2026

Escopo desta rodada: validar a fundação técnica sem antecipar os testes funcionais de START/END/CANCEL.

### Cobertura adicionada

- replay de migrations e presença da migration C05 mais recente no histórico local;
- constraints estruturais e vocabulário de criticidade;
- proteção de CANCEL com razão obrigatória;
- double submit/idempotência por chave única;
- RLS negativa para `anon` e `authenticated` sem policy governada;
- tentativa de acesso direto pela Data API com chave anônima;
- ensaio de rollback da última migration no banco descartável;
- reconstrução completa após rollback;
- lint após reconstrução.

### Evidência já obtida

No Lovable Cloud PRIMARY:
- double submit foi bloqueado por `unique_violation`;
- teste foi executado dentro de transação e revertido, sem persistir fixture.

No GitHub:
- `supabase/tests/database/c05_technical_guards.test.sql` criado;
- `supabase/rollback-tests/c05_latest_rollback.test.sql` criado;
- `.github/scripts/test-safra-direct-api.sh` criado;
- workflow `database-disposable-test.yml` ampliado para executar API direta e rollback real.

### Limite deliberado

Os fluxos funcionais de START/END/CANCEL não são testados nesta bateria.
Eles permanecem nas fases próprias de implementação funcional.

### Estado

```text
C05_TECHNICAL_TEST_SUITE = PASS
PRIMARY_DOUBLE_SUBMIT = PASS
DISPOSABLE_CI_FULL_RUN = PASS
GITHUB_ACTIONS_RUN = 27
GITHUB_ACTIONS_RUN_ID = 36189333481
START_END_CANCEL_FUNCTIONAL_TESTS = DEFERRED_TO_OWN_PHASES
```


### Evidência final da Run 27

A GitHub Action `Database Disposable Test`, Run 27 (ID `36189333481`), concluiu com sucesso.

Passaram:
- inicialização do banco descartável;
- reconstrução completa pelas migrations canônicas;
- testes SQL/pgTAP;
- bloqueio de acesso direto pela Data API;
- rollback da última migration;
- reconstrução após rollback;
- lint do banco;
- encerramento limpo do ambiente descartável.

Resultado:

```text
C05_TECHNICAL_VALIDATION = PASS
```


## SAFRA-C05 — FECHAMENTO FORMAL — 25/09/2026

Auditoria final concluída.

Resultado live no PRIMARY:
- 17/17 tabelas do domínio presentes;
- 17/17 com RLS;
- zero FK com `ON DELETE CASCADE` no domínio Safra;
- sem grants diretos para `anon`/`authenticated`;
- version freeze, append-only e guardas de treatment presentes;
- criticidade sem default;
- `GI-SAFRA-001 = OPEN`;
- nenhuma unicidade de ACTIVE por cenário criada;
- GitHub e PRIMARY agora registram as mesmas 10 migrations canônicas.

Repair final de tracking:
- `20260925173000_c05_invariants_temporal_hardening`;
- `20260925210500_c05_terminal_state_guards`.

As duas já estavam aplicadas fisicamente. Somente o histórico de migrations foi reconciliado; nenhuma DDL foi reaplicada.

Evidência CI:
- Database Disposable Test Run 27;
- run_id `36189333481`;
- conclusão SUCCESS.

Estado final:

```text
SAFRA-C05 = CONCLUIDO
C05_SCHEMA = PASS
C05_INVARIANTS = PASS
C05_MIGRATIONS = PASS
C05_ROLLBACK = PASS
C05_API_RLS = PASS
MIGRATION_DRIFT = 0
NEXT_PHASE = SAFRA-C06
```

Próxima fase canônica: **SAFRA-C06 — Seed canônico da Matriz v3**.


---

## SAFRA-C06.1 — 11 cenários canônicos da Matriz v3 inseridos — 25/09/2026

Fonte:
- `EDB06 - Matriz Contingencia v3.xlsx`;
- aba `Matriz de Contingência`;
- SHA256 `b0cca8cce835dbdc65ab0c30212fd89480d2cf51e9fb62d215ad1bde0963ead6`.

Migration:
`supabase/migrations/20260925213118_c06_seed_canonical_matrix_v3.sql`

Resultado no PRIMARY:
- 11 cenários `SAFRA-01` a `SAFRA-11`;
- 11 versões v1 PUBLISHED;
- 11 owners ativos;
- áreas responsáveis vinculadas;
- áreas impactáveis vinculadas;
- ferramentas vinculadas;
- `current_version_id` correto nos 11;
- criticidade permanece NULL nos 11;
- `GI-SAFRA-001` preservado;
- migration registrada no tracking do PRIMARY.

Owners:
- Daniel Garcia: 1, 2, 3, 7, 10, 11;
- Jiane Rodrigues: 4, 5, 6, 8;
- Renato de Paulo: 9.

Decisão de modelagem:
- textos de gatilho, acionamento e protocolo foram preservados literalmente;
- SLA-alvo, acompanhamento, validação e mapeamento ficam preservados no `source_reference`;
- `scenario_slas` não foi preenchido nesta etapa porque a Matriz v3 não define explicitamente `start_event` e `end_event`; essa estruturação permanece para C07, sem inferência.

Validação:
- dry-run transacional no PRIMARY com ROLLBACK = PASS;
- aplicação no PRIMARY = PASS;
- consulta pós-carga confirmou 11/11 versões correntes e owners corretos;
- pgTAP `c06_canonical_seed.test.sql` versionado;
- GitHub Actions do commit de C06 em execução no momento deste registro.

Estado:

```text
C06_CANONICAL_11_SCENARIOS = PASS_PRIMARY
CRITICALITY_INFERENCE = NONE
GI-SAFRA-001 = OPEN
C06_CI = PASS_DB_RUN_58
```


---

## Auditoria transversal pós-C06.1 — 25/09/2026

Smoke/auditoria executados:
- migration replay do zero;
- rollback da migration mais recente;
- pgTAP;
- Data API direta;
- RLS/grants;
- RBAC/owners;
- version freeze e append-only;
- ausência de cascade destrutivo;
- consistência dos 11 cenários canônicos;
- hardening de funções privadas;
- índices de FKs do domínio;
- typecheck do frontend;
- smoke de build/lint adicionado ao CI.

Correções automáticas aplicadas:
- rollback CI deixou de depender do C05 e passou a validar qualquer migration mais recente;
- concorrência do workflow cancela runs antigas;
- Supabase CLI fixado em versão estável no CI;
- EXECUTE público removido de helpers privados;
- índices de FK adicionados antes do crescimento do volume;
- smoke do frontend separa build/typecheck bloqueantes de dívida legada de formatação.

Evidência:
- Database Disposable Test Run 40 = SUCCESS.

Estado parcial:
```text
DATABASE_SMOKE = PASS
DATABASE_DISPOSABLE_RUN = 58 / 36205238018
MIGRATION_REPLAY = PASS
ROLLBACK_LATEST = PASS
RLS_DIRECT_API = PASS
CANONICAL_11_SCENARIOS = PASS
MIGRATION_DRIFT = 0
UNINDEXED_DOMAIN_FKS = 0
RBAC_PRIMARY_SMOKE = PASS_9_OF_9
APP_SMOKE_RUN = 20 / 36205238059
DEPENDENCY_HIGH_GUARD = PASS
APP_TYPECHECK = PASS
APP_BUILD = PASS
LEGACY_LINT = NON_BLOCKING_TECH_DEBT
```


---

## Fechamento da auditoria transversal — PASS — 25/09/2026

Evidências finais:
- Database Disposable Test Run 58 / ID 36205238018 = SUCCESS;
- App Smoke Test Run 20 / ID 36205238059 = SUCCESS;
- smoke controlado de RBAC no PRIMARY = 9/9 PASS;
- GitHub e PRIMARY = 15/15 migrations, drift zero;
- 35/35 FKs relevantes cobertas por índice;
- 11/11 cenários canônicos publicados e com owner correto;
- zero treatment fictício;
- zero bucket de storage;
- dependências HIGH conhecidas corrigidas e bloqueadas por CI.

Estado de handoff:

C00_TO_C06_1_CROSS_AXIS_AUDIT = PASS
TECHNICAL_BASELINE = READY_TO_ADVANCE
WAITING_HUMAN_DECISION = GI-SAFRA-001..008
NEXT_TECHNICAL_PHASE = SAFRA-C07

Dívida não bloqueante:
- formatação/Prettier do frontend legado deve ser tratada em mudança cosmética separada;
- frontend visual continua legado até as fases próprias de UX/fluxos Safra.


---

## SAFRA-C06.02 — pipeline e regressão — 25/09/2026

Pipeline executado:

```text
XLSX v3
-> parser versionado 1.0.0
-> staging
-> validação
-> preview diff
-> aprovação humana
-> seed/migration
-> reconciliação
```

Evidências:
- fonte XLSX SHA256: `b0cca8cce835dbdc65ab0c30212fd89480d2cf51e9fb62d215ad1bde0963ead6`;
- duas cópias da fonte encontradas possuem o mesmo hash;
- parser: `scripts/c06_matrix_pipeline.py`;
- staging: 11 registros;
- validação: PASS, 0 erros e 5 warnings de governance issues já conhecidos;
- preview diff contra PRIMARY: NO_DIFF, 0 diferenças;
- aprovação humana registrada para replay sem mudança de negócio;
- seed/migration canônica reutilizada: `20260925213118_c06_seed_canonical_matrix_v3.sql`;
- nenhuma migration adicional necessária porque o diff é zero;
- reconciliação PRIMARY: PASS.

Regressão RBAC/ownership:
- Daniel: somente 1,2,3,7,10,11;
- Jiane: somente 4,5,6,8;
- Renato: somente 9;
- Jair/Bruno/platform admins: zero ownership ativo;
- authenticated sem INSERT/UPDATE/DELETE em `scenario_owners`;
- RLS permanece ativa;
- Data API direta agora testa também `scenario_owners`.

Estado:

```text
C06_02_PIPELINE = PASS
C06_02_PREVIEW_DIFF = NO_DIFF
C06_02_RECONCILIATION = PASS
C06_02_RBAC_OWNERSHIP = PASS_RUN_72
NEXT_AFTER_GREEN_CI = SAFRA-C07
```


### Reconciliação dos campos canônicos — C06.02

Run 72: PASS.

Resultado contra Matriz v3 / PRIMARY:
- área responsável: 11/11;
- áreas potencialmente impactáveis: 11/11, 20 vínculos;
- protocolo: 11/11, texto literal preservado;
- criticidade suportada: 11/11 corretamente NULL; a XLSX não contém classificação nominal;
- SLA textual: 11/11 preservado; 0 registros estruturados em scenario_slas até C07;
- sistemas/ferramentas: 11/11 vinculados ao valor literal da coluna Ferramenta; 10 valores únicos;
- mapeamento: 11/11, sendo EDB05=2 e EDB06=9.

Sem divergências.

Estado:

```text
C06_02_PIPELINE = PASS
C06_02_RBAC_OWNERSHIP = PASS_RUN_72
C06_02_FIELD_RECONCILIATION = PASS
C06_02 = CONCLUIDO
NEXT = SAFRA-C07
```


---

## SAFRA-C07 — Engine de SLA — 25/09/2026

Núcleo aplicado no PRIMARY.

Migration:
`20260925234000_c07_sla_engine.sql`

Funções:
- `private.safra_sla_target_interval`;
- `private.safra_evaluate_sla`;
- `private.safra_treatment_event_time`;
- `private.safra_treatment_sla_state`.

Estados:
- ON_TRACK;
- BREACHED;
- COMPLETED_ON_TIME;
- COMPLETED_LATE;
- NOT_MEASURABLE;
- NOT_APPLICABLE apenas por regra explícita.

Bordas validadas:
- depois do deadline => BREACHED;
- END exatamente no deadline => COMPLETED_ON_TIME;
- START ausente => NOT_MEASURABLE;
- target estruturado ausente => NOT_MEASURABLE;
- CANCEL antes do deadline => NOT_MEASURABLE;
- CANCEL depois do breach => BREACHED;
- relógio anterior ao START => NOT_MEASURABLE;
- timezone/DST usa timestamptz;
- NOT_APPLICABLE exige regra explícita.

Importante:
- nenhum dos 11 cenários recebeu SLA estruturado por inferência;
- `scenario_slas` continua sem seed produtivo;
- configuração futura de SLA em cenário PUBLISHED exige nova `scenario_version`.

P1–P4:
- fonte canônica: `docs/product-gates/P1_P4.json`;
- P1 = NOT_PUBLISHED;
- P2 = NOT_PUBLISHED;
- P3 = NOT_PUBLISHED;
- P4 = NOT_PUBLISHED;
- PASS exige aprovação humana + evidência por critério;
- CI bloqueia publicação inferida.

Estado:

```text
C07_ENGINE_CORE = IMPLEMENTED_PRIMARY
C07_BOUNDARY_TESTS = VERSIONED
P1_P4_INFERENCE_GUARD = IMPLEMENTED
P1 = NOT_PUBLISHED
P2 = NOT_PUBLISHED
P3 = NOT_PUBLISHED
P4 = NOT_PUBLISHED
C07_CI = PASS_RUN_125
```


### Gate de reconciliação integral da Matriz v3 — 26/09/2026

Evidência final:
- Database Disposable Test Run 98 / ID `36216982679` = SUCCESS.

```text
MATRIX_V3_RECONCILIATION = 198/198
TOLERANCE = 0
DATABASE_DISPOSABLE_RUN_98 = PASS
```


Regra agora obrigatória:

```text
CANONICAL_RECORDS = 11
IMPORTED_FIELDS_PER_RECORD = 18
REQUIRED_COMPARISONS = 198
MATRIX_V3_RECONCILIATION = 198/198
TOLERANCE = 0
```

CI valida:
- SHA256 da fonte;
- SHA256 do staging;
- 11 códigos canônicos;
- exatamente 18 campos por registro;
- 198/198 valores importados;
- campos centrais normalizados;
- áreas impactáveis;
- ferramenta/sistema;
- ausência de cenário canônico extra ou faltante.

Qualquer diferença bloqueia o avanço.


### Ownership real persistido — schema v2 — 26/09/2026

Validação feita diretamente sobre:
`scenarios -> scenario_owners -> safra_principals -> safra_role_grants`.

Resultado PRIMARY:
- 11 cenários;
- 11 vínculos ativos;
- exatamente 1 owner ativo por cenário;
- 3 owners distintos;
- 0 vínculos órfãos;
- 0 owner ativo sem role `scenario_owner`;
- 0 overlap indevido com roles administrativas;
- 0 validade temporal inválida;
- índice único parcial protege contra dois owners ativos por cenário.

Teste versionado:
`supabase/tests/database/c06_02_real_ownership_persistence.test.sql`.

Evidência:
`docs/data-contracts/c06_02_real_ownership_primary_snapshot.json`.

```text
REAL_OWNERSHIP_LINKS = 11/11
ORPHAN_LINKS = 0
DUPLICATE_ACTIVE_OWNER = 0
OWNER_ROLE_MISMATCH = 0
ADMIN_OWNER_OVERLAP = 0
```


---

## SAFRA-C06.1 — Teste de ownership real — 26/09/2026

Fase **CONCLUÍDA** após reauditoria integral em 27/09/2026.

### Ação 1

Testar ownership real dos 11 cenários usando os vínculos efetivamente persistidos no schema v2.

Teste:
`supabase/tests/database/c06_02_real_ownership_persistence.test.sql`

Resultado técnico no PRIMARY:
- 11 cenários;
- 11 vínculos ativos;
- exatamente 1 owner ativo por cenário;
- 3 owners distintos;
- 0 vínculos órfãos;
- 0 role mismatch;
- 0 admin/owner overlap;
- 0 duplicidade ativa;
- assignment_reason presente em todos.

```text
C06_1_ACTION_01_TECHNICAL = PASS
C06_1_ACTION_01_HUMAN_VALIDATION = APPROVED
```

Validação humana dos 11 cenários e respectivos owners: **APROVADA**.


### SAFRA-C06.1 — Ação 2 — owner sem herança administrativa / sem fallback

Validação executada no PRIMARY.

Regras comprovadas:
- owner depende de vínculo explícito ativo em `scenario_owners`;
- admin não herda ownership;
- role `scenario_owner` não substitui vínculo de cenário;
- cenário publicado não aceita ausência de owner;
- cenário publicado não aceita owner inelegível;
- nenhuma substituição silenciosa ocorre quando o vínculo falta.

Teste:
`supabase/tests/database/c06_1_owner_no_inheritance_no_fallback.test.sql`

Resultado:
```text
C06_1_ACTION_02 = PASS
TESTS = 10/10
ADMIN_ROLE_INHERITANCE = 0
SILENT_OWNER_FALLBACK = 0
```


### SAFRA-C06.1 — Ação 3 — coerência UI / REST-RPC / banco

Evidência:
`docs/data-contracts/C06_1_READ_AUTHORIZATION_EVIDENCE.md`

Validação:
- PRIMARY pgTAP = 12/12 PASS;
- App Smoke 83/85 = PASS para checker UI/server;
- Database Disposable Run 123: rebuild PASS, pgTAP PASS, REST denial PASS, RPC denial PASS;
- RLS ativa no catálogo Safra;
- anon e authenticated sem SELECT direto no catálogo Safra;
- browser sem acesso às tabelas privadas de RBAC;
- sem RPC público de leitura de scenario/owner nesta fase.

Importante:
a UI Safra ainda não implementa leitura dos 11 cenários. Logo, não foi inferida paridade positiva de dataset.

```text
C06_1_ACTION_03 = PASS
AUTHORIZATION_COHERENCE = PASS
SAFRA_UI_CATALOG_READ = NOT_IMPLEMENTED_YET
UI_VS_API_DATASET_PARITY = NOT_APPLICABLE_UNTIL_GOVERNED_READ_API
```


### Fechamento CI

```text
APP_SMOKE_RUN_85 = SUCCESS
DATABASE_DISPOSABLE_RUN_123 = SUCCESS
C06_1_ACTION_03_CI = PASS
```


---

## Reauditoria integral SAFRA-C06.1 — 27/09/2026

Evidência detalhada:
`docs/AUDITORIA_C06_1_OWNERSHIP_2026-09-27.md`

### Resultado das quatro ações

1. **Ownership real dos 11 cenários — PASS**
   - 11 cenários;
   - 11 vínculos ativos;
   - exatamente 1 owner ativo por cenário;
   - 3 owners reais;
   - 0 órfãos;
   - 0 role mismatch;
   - 0 admin/owner overlap;
   - validação humana = APPROVED.

2. **Sem herança administrativa / sem fallback silencioso — PASS**
   - pgTAP 10/10;
   - admin não herda ownership;
   - role `scenario_owner` não substitui vínculo explícito;
   - ausência/inelegibilidade de owner bloqueia cenário PUBLISHED.

3. **Coerência UI / REST-RPC / banco — PASS**
   - App Smoke Run 87 / ID `36309242985` = SUCCESS;
   - RLS/grants = PASS;
   - REST anônimo = DENIED;
   - RPC anônimo = DENIED;
   - browser sem acesso às fontes privadas de RBAC;
   - leitura direta do catálogo Safra permanece deny-by-default.

4. **Mutação direta / autoatribuição de owner — PASS**
   - teste `c06_1_owner_mutation_governance.test.sql` = 13/13 no Database Disposable Run 125;
   - `authenticated` e `anon` sem INSERT/UPDATE/DELETE em `scenario_owners`;
   - 0 RPC público de assign/reassign owner;
   - POST/PATCH direto pela Data API = DENIED;
   - reescrita de `owner_id` = DENIED;
   - delete físico de histórico = DENIED.

### PRIMARY revalidado

```text
CANONICAL_SCENARIOS = 11
ACTIVE_OWNER_LINKS = 11
SCENARIOS_WITHOUT_EXACTLY_ONE_OWNER = 0
DISTINCT_ACTIVE_OWNERS = 3
ORPHAN_OWNER_LINKS = 0
OWNER_ROLE_MISMATCH = 0
ADMIN_OWNER_OVERLAP = 0
MISSING_ASSIGNMENT_REASON = 0
BROWSER_OWNER_WRITE_GRANTS = 0
PUBLIC_OWNER_MUTATION_RPCS = 0
SCENARIO_OWNERS_RLS = ENABLED
MIGRATION_DRIFT = 0
```

### CI final

```text
APP_SMOKE_RUN_87 = SUCCESS
DATABASE_DISPOSABLE_RUN_125 = SUCCESS
MIGRATION_REPLAY = PASS
PGTAP = PASS
DIRECT_DATA_API_DENIAL = PASS
DIRECT_RPC_DENIAL = PASS
ROLLBACK_LATEST = PASS
DATABASE_LINT = PASS
SAFRA-C06.1 = CONCLUIDO
NEXT_PHASE = SAFRA-C07
```

### Limite deliberado

A UI/read API governada do catálogo Safra ainda não existe. Portanto, `UI_VS_API_DATASET_PARITY`
continua não aplicável até essa superfície ser implementada.

Também não existe ainda fluxo produtivo de reatribuição de owner. A ausência é deny-by-default:
nenhum RPC permissivo foi criado. Quando esse fluxo existir, deverá ser server-side, autorizado,
auditável e preservar o histórico temporal.

### Handoff

O C06.1 não possui bloqueador remanescente no escopo de ownership/autorização.

A fase corrente passa a ser **SAFRA-C07 — Engine de SLA**.

O mesmo Database Disposable Run 125 também reexecutou com sucesso a bateria C07 já versionada,
eliminando o estado documental anterior `C07_CI = PENDING`. Isso não antecipa decisões de
start_event/end_event/thresholds nem publica P1-P4.


---

## C07 — contrato obrigatório dos quatro campos do SLA — 27/09/2026

Modelo canônico:

```text
start_event
end_event
target_value
target_unit
```

Resultado:
- os quatro campos são obrigatórios em `public.scenario_slas`;
- `target_value > 0`;
- `target_unit in (MINUTE,HOUR,DAY)`;
- `start_event <> end_event`;
- RLS preservada;
- nenhum SLA dos 11 cenários foi inferido/publicado;
- App Smoke Run 90 = SUCCESS;
- Database Disposable Run 128 = SUCCESS;
- PRIMARY sincronizado com migration `20260927094000_c07_require_complete_sla_model.sql`.

```text
C07_SLA_MODEL = PASS
C07_SLA_MODEL_PRIMARY = PASS
C07_SLA_MODEL_CI = PASS_RUN_128
STRUCTURED_SLA_ROWS = 0
```


---

## C07 — Regra 1 aprovada: duração por timestamps — 27/09/2026

Decisão humana: **APROVADA**.

```text
DURATION_SOURCE = SERVER_TIMESTAMPS
DURATION_PERSISTED = NO
CANONICAL_DURATION_UNIT = SECONDS
NEGATIVE_DURATION = FORBIDDEN
OPEN_SLA_DURATION = SERVER_AS_OF - START_TIMESTAMP
CLOSED_SLA_DURATION = END_TIMESTAMP - START_TIMESTAMP
```

Validação no PRIMARY:
- SLA concluído de 90 min = 5400 s;
- SLA aberto de 45 min = 2700 s;
- END anterior ao START = NOT_MEASURABLE / END_BEFORE_START.


---

## C07 — Regra 2 aprovada: timezone canônico e analytics — 27/09/2026

Decisão humana: **APROVADA após smoke test**.

Contrato:

```text
CANONICAL_TIMEZONE = UTC
DATABASE_TIMEZONE = UTC
TIMESTAMP_TYPE = timestamptz
ANALYTICS_BUSINESS_TIMEZONE = America/Sao_Paulo
DURATION_CALCULATION = ABSOLUTE_INSTANTS
DAILY_HOURLY_BUCKETS = CONVERT_TO_AMERICA_SAO_PAULO_BEFORE_BUCKETING
FRONTEND_HOST_TIMEZONE_DEPENDENCY = FORBIDDEN
```

Smoke no PRIMARY:
- timezone do PostgreSQL = UTC;
- offsets diferentes representam o mesmo instante;
- duração é invariável entre UTC e -03:00;
- 22:30 e 23:30 de São Paulo permanecem no dia local correto;
- 00:30 passa corretamente ao dia seguinte;
- histórico com mudança de offset preserva tempo absoluto;
- timestamps operacionais auditados permanecem `timestamptz`.

Falha encontrada e corrigida:
- o analytics legado usava timezone do navegador para limites de Hoje/Mês e exibição;
- corrigido para `America/Sao_Paulo` explícito;
- inputs `datetime-local` agora convertem São Paulo -> UTC sem depender do host.

Regressão permanente:
- `supabase/tests/database/c07_timezone_analytics_smoke.test.sql`;
- `.github/scripts/test-c07-analytics-timezone.ts`;
- App Smoke executa o frontend em host UTC e Asia/Tokyo.

CI final:
```text
APP_SMOKE_RUN_96 = SUCCESS
C07_ANALYTICS_TZ_UTC_HOST = PASS
C07_ANALYTICS_TZ_TOKYO_HOST = PASS
TYPECHECK = PASS
BUILD = PASS
DATABASE_DISPOSABLE_RUN_134 = SUCCESS
C07_TIMEZONE_PGTAP = PASS
ROLLBACK = PASS
DATABASE_LINT = PASS
```


---

## C07 — Regra 3 aprovada: relógio não-negativo e CANCEL sem sucesso — 27/09/2026

Decisão humana: **APROVADA**.

Contrato:

```text
NEGATIVE_CLOCK = FORBIDDEN
REMAINING_SECONDS_MIN = 0
ELAPSED_SECONDS_MIN = 0
CANCEL_AS_SUCCESS = FORBIDDEN
CANCEL_BEFORE_OR_AT_DEADLINE = NOT_MEASURABLE
CANCEL_AFTER_DEADLINE = BREACHED
END_BEFORE_START = NOT_MEASURABLE
CLOCK_BEFORE_START = NOT_MEASURABLE
```

Implementação:
- migration `20260927102500_c07_nonnegative_clock_cancel_semantics.sql`;
- teste `c07_clock_cancel_contract.test.sql`.

Validação:
- App Smoke Run 98 = SUCCESS;
- Database Disposable Run 136 = SUCCESS;
- 13/13 testes da nova regra = PASS;
- rebuild = PASS;
- rollback = PASS;
- lint = PASS.

Smoke PRIMARY:
- breach em 13:30 para deadline 13:00 => `remaining_seconds = 0`;
- CANCEL 12:30 => `NOT_MEASURABLE`;
- CANCEL 13:00 exato => `NOT_MEASURABLE`;
- CANCEL 13:30 => `BREACHED`, `remaining_seconds = 0`;
- END antes do START => `NOT_MEASURABLE`;
- relógio antes do START => `NOT_MEASURABLE`.


---

## C07 — Regra 4 aprovada: fechamento somente em TREATMENT_RESOLVED — 27/09/2026

Decisão humana: **APROVADA**.

Contrato:

```text
SLA_COMPLETION_END_EVENT = TREATMENT_RESOLVED
OTHER_END_EVENTS = NOT_MEASURABLE
COMPLETED_ON_TIME_REQUIRES = TREATMENT_RESOLVED
COMPLETED_LATE_REQUIRES = TREATMENT_RESOLVED
```

Defesa em profundidade:
- constraint `scenario_slas_end_event_resolved_only`;
- wrapper `private.safra_evaluate_configured_sla(...)`;
- `private.safra_treatment_sla_state(...)` usa obrigatoriamente o wrapper configurado.

Smoke PRIMARY:
- `TREATMENT_RESOLVED` no prazo => `COMPLETED_ON_TIME`;
- `TREATMENT_RESOLVED` após prazo => `COMPLETED_LATE`;
- `NOTE_ADDED` como END => `NOT_MEASURABLE / END_EVENT_NOT_TREATMENT_RESOLVED`;
- `TREATMENT_CANCELLED` como END => `NOT_MEASURABLE / END_EVENT_NOT_TREATMENT_RESOLVED`;
- END ausente => `NOT_MEASURABLE / END_EVENT_NOT_TREATMENT_RESOLVED`;
- 0 SLAs estruturados incompatíveis no PRIMARY.

CI final:
```text
APP_SMOKE_RUN_101 = SUCCESS
DATABASE_DISPOSABLE_RUN_139 = SUCCESS
C07_RESOLVED_END_ONLY_TESTS = 11/11 PASS
REBUILD = PASS
ROLLBACK = PASS
DATABASE_LINT = PASS
```


---

## C07 — Regras 5 e 6 aprovadas: múltiplos SLAs e evento ausente — 27/09/2026

Decisão humana: **APROVADA**.

### Regra 5 — múltiplos SLAs por cenário/version

Contrato:

```text
MULTIPLE_SLAS_PER_SCENARIO_VERSION = SUPPORTED
SLA_IDENTITY = scenario_version_id + code
SLA_EVALUATION = INDEPENDENT_PER_SLA
SLA_RESULT_CARDINALITY = ONE_RESULT_PER_CONFIGURED_SLA
```

Validação:
- uma mesma `scenario_version` DRAFT recebeu 2 SLAs sintéticos;
- SLA 1h e SLA 2h coexistiram sem conflito;
- no mesmo instante, SLA 1h = `BREACHED` e SLA 2h = `ON_TRACK`;
- código duplicado dentro da mesma versão continua proibido;
- versão PUBLISHED permanece imutável, portanto novos SLAs exigem nova versão/DRAFT conforme governança.

### Regra 6 — evento necessário ausente

Contrato:

```text
REQUIRED_START_EVENT_MISSING = NOT_MEASURABLE
MISSING_EVENT_REASON = START_EVENT_MISSING
MISSING_RESOLVED_WHILE_ACTIVE_BEFORE_DEADLINE = ON_TRACK
MISSING_RESOLVED_WHILE_ACTIVE_AFTER_DEADLINE = BREACHED
EVENT_TIMESTAMP_INFERENCE = FORBIDDEN
```

Interpretação:
- se o evento necessário para iniciar a medição não existe, não existe relógio válido;
- o sistema não inventa timestamp e retorna `NOT_MEASURABLE`;
- `TREATMENT_RESOLVED` ainda não ocorrido em tratamento ativo não é ausência inválida: significa que o SLA ainda não terminou;
- antes do prazo ele permanece `ON_TRACK`;
- após o prazo permanece `BREACHED`.

Evidência:
- `supabase/tests/database/c07_multi_sla_missing_event_contract.test.sql`;
- smoke transacional no PRIMARY = PASS com rollback;
- App Smoke Run 104 = SUCCESS;
- Database Disposable Run 142 = SUCCESS;
- rebuild, testes, Data API/RPC negativas, rollback e lint = PASS.


---

## C07 — matriz adversarial de bordas e relógio — 27/09/2026

Auditoria consolidada executada após as regras de duração, timezone, CANCEL, END resolvido, múltiplos SLAs e evento ausente.

### Eixos testados

1. borda exata do deadline;
2. breach imediatamente após a borda;
3. END exatamente no deadline e após breach;
4. timezone e DST histórico;
5. evento necessário ausente;
6. CANCEL antes/no/depois do deadline;
7. dois SLAs independentes no mesmo instante;
8. manipulação de relógio / snapshots históricos.

### Falha encontrada e corrigida

Antes da correção, uma avaliação histórica com `as_of=12:30` podia receber um `END=13:30` e retornar `COMPLETED_LATE`, antecipando um evento futuro.

Correção:
- migration `20260927113000_c07_historical_snapshot_clock_guard.sql`;
- END/CANCEL posteriores a `as_of` são invisíveis naquele snapshot;
- eventos futuros não podem antecipar conclusão, cancelamento ou apagar breach;
- `anon` e `authenticated` permanecem sem EXECUTE na engine bruta.

### Resultados canônicos

```text
exact deadline open      = ON_TRACK
remaining at deadline    = 0
deadline + 1 ms          = BREACHED
END at deadline          = COMPLETED_ON_TIME
END after deadline       = COMPLETED_LATE
DST elapsed              = 7200 seconds
missing START            = NOT_MEASURABLE / START_EVENT_MISSING
CANCEL at deadline       = NOT_MEASURABLE
SLA 1h @ 13:30           = BREACHED
SLA 2h @ 13:30           = ON_TRACK
future END @ as_of 12:30 = ON_TRACK
future CANCEL @ 12:30    = ON_TRACK
clock before START       = NOT_MEASURABLE / CLOCK_BEFORE_START
anon raw engine execute  = DENIED
auth raw engine execute  = DENIED
```

### Evidência

- teste: `supabase/tests/database/c07_boundary_adversarial_matrix.test.sql`;
- 26/26 casos = PASS;
- App Smoke Run 106 = SUCCESS;
- Database Disposable Run 144 = SUCCESS;
- rebuild = PASS;
- Data API denial = PASS;
- RPC denial = PASS;
- rollback = PASS;
- database lint = PASS;
- PRIMARY smoke pós-migration = PASS;
- migration `20260927113000` rastreada.


---

## C07 — Regra 7 aprovada: tolerância temporal documentada — 27/09/2026

Decisão humana: **APROVADA**.

Contrato:

```text
DEFAULT_TOLERANCE = ZERO
IMPLICIT_TOLERANCE = FORBIDDEN

DOCUMENTED_TOLERANCE_FIELDS =
  tolerance_value
  tolerance_unit
  tolerance_documentation

TOLERANCE_VALUE = POSITIVE_ONLY
TOLERANCE_UNIT = MINUTE | HOUR | DAY
TOLERANCE_DOCUMENTATION = REQUIRED
PARTIAL_TOLERANCE_CONFIG = NOT_MEASURABLE
INVALID_TOLERANCE_REASON = TOLERANCE_CONFIGURATION_INVALID
```

Sem tolerância, os três campos ficam NULL e a semântica anterior permanece idêntica.

Com tolerância documentada, somente o deadline efetivo é estendido. START, END e duração real continuam baseados nos timestamps observados.

Exemplo validado:
- START 12:00;
- target 1 HOUR;
- tolerance 5 MINUTE documentada;
- deadline efetivo = 13:05;
- 13:05 exato = ON_TRACK;
- 13:05:00.001 = BREACHED.

Evidência:
- migration `20260927120500_c07_documented_tolerance.sql`;
- teste `c07_documented_tolerance.test.sql`;
- PRIMARY = 18/18 PASS;
- App Smoke Run 111 = SUCCESS;
- nenhum SLA produtivo foi inferido/publicado.

```text
SAFRA-C07.1 = PASS
SAFRA-C07.2 = PASS
SAFRA-C07.3 = PASS
SAFRA-C07.4 = PASS
SAFRA-C07.5 = PASS
SAFRA-C07.6 = PASS
```


---

## Gate C07 → C08 — 27/09/2026

Resultado: **APROVADO PARA AVANÇAR**.

Evidência técnica:
- App Smoke Run 112 = SUCCESS;
- Database Disposable Run 150 = SUCCESS;
- rebuild completo de migrations = PASS;
- database tests = PASS;
- Data API denial = PASS;
- RPC denial = PASS;
- rollback da última migration = PASS;
- database lint = PASS;
- migration C07.6 rastreada no PRIMARY;
- tolerância documentada: constraint presente e 0 configurações inválidas;
- 11 `scenario_versions` reais em estado `PUBLISHED`.

C07:
```text
SAFRA-C07.1 = PASS
SAFRA-C07.2 = PASS
SAFRA-C07.3 = PASS
SAFRA-C07.4 = PASS
SAFRA-C07.5 = PASS
SAFRA-C07.6 = PASS
SAFRA-C07 = CONCLUIDO
NEXT_PHASE = SAFRA-C08
```

### Governança aberta que NÃO bloqueia o início do C08

- GI-SAFRA-001: criticidade nominal ainda não definida. No START, mostrar ausência explicitamente; não inferir nem permitir override por payload.
- GI-SAFRA-002/003: thresholds de gatilho ainda abertos. Não inferir.
- GI-SAFRA-004: múltiplas tratativas ACTIVE permanece decisão de M01. C08 não deve criar unicidade por cenário ACTIVE; idempotência vale para o mesmo comando/retry.
- GI-SAFRA-005: provider/canal produtivo de notificações é responsabilidade de M05. Não bloquear o núcleo transacional do START.
- GI-SAFRA-006/008: janelas temporais são fases posteriores.
- GI-SAFRA-007: publicação do 12º card é M10.
- GI-SAFRA-009: mapeamento produtivo dos SLAs textuais continua aberto. C08 inicia somente SLAs estruturados existentes; não deve criar/inferir `scenario_slas`.

### Restrição para fechamento completo de P2 / START READY

O C08 pode ser implementado e homologado no núcleo START agora. Porém a publicação completa do gate P2 não deve declarar "SLA produtivo iniciado corretamente" enquanto GI-SAFRA-009 e thresholds relacionados permanecerem sem definição produtiva.


---

## PAUSA FORMAL ANTES DO C08 / UX — 27/09/2026

Embora o gate técnico C07 → C08 esteja verde, a execução foi **interrompida antes de iniciar a UX/START** para tratar quatro pendências de governança que poderiam induzir comportamento falso na interface:

- **GI-SAFRA-001** — criticidade nominal dos 11 cenários;
- **GI-SAFRA-002** — thresholds ausentes dos cenários 2, 4, 10 e 11;
- **GI-SAFRA-003** — fonte oficial do mínimo da curva A no cenário 9;
- **GI-SAFRA-009** — mapeamento formal dos SLAs textuais para relógios estruturados.

Motivo da pausa:
- C08 precisa exibir criticidade vigente sem inventá-la;
- START não pode prometer automação de gatilho que não possui threshold;
- cenário 9 não pode classificar ruptura automaticamente sem fonte oficial;
- START não pode iniciar SLA estruturado derivado apenas de texto ambíguo.

Estado:
```text
C07_TECHNICAL_GATE = PASS
C08_UX_STARTED = false
PRE_C08_GOVERNANCE_GATE = IN_PROGRESS
BLOCKERS = GI-001,GI-002,GI-003,GI-009
```

Próximo passo após este gate:
`SAFRA-C08.1 — contrato transacional e autorização do START`.


---

## Gate pré-C08 — FECHADO — 27/09/2026

As quatro pendências que impediram iniciar a UX foram tratadas no nível necessário para o MVP:

```text
GI-SAFRA-001 = NON_BLOCKING_C08
GI-SAFRA-002 = AUTOMATION_DEFERRED / NON_BLOCKING_C08
GI-SAFRA-003 = AUTOMATION_DEFERRED / NON_BLOCKING_C08
GI-SAFRA-009 = MAPPING_POLICY_RESOLVED_FOR_C08
```

Decisões:
- D-44: criticidade NULL é estado explícito e não bloqueia START;
- D-45: thresholds ausentes => detector NOT_CONFIGURED + START manual;
- D-46: cenário 9 sem fonte curva A => START manual, sem ruptura automática;
- D-47: política formal para converter SLA textual em SLA runtime sem inferência.

PRIMARY:
- migration `20260927133000_pre_c08_governance_nonblocking.sql` aplicada e rastreada;
- teste transacional pré-promoção = 12/12 PASS;
- registry operacional atualizado.

Importante:
- GI-001/002/003 continuam OPEN porque os dados de negócio continuam inexistentes;
- GI-009 continua OPEN para materialização produtiva em nova scenario_version;
- nenhuma delas bloqueia mais C08.

```text
PRE_C08_GOVERNANCE_GATE = PASS
C08_UX_STARTED = false
NEXT_EXACT_STEP = SAFRA-C08.1
```


---

## SAFRA-C08.1 — START end-to-end — IMPLEMENTADO — 27/09/2026

O núcleo de START foi implementado da UI ao banco e promovido ao PRIMARY.

### Fluxo implementado

```text
usuário Microsoft corporativo
 -> Abrir Protocolo
 -> catálogo governado dos 11 cenários ACTIVE/PUBLISHED
 -> selecionar cenário
 -> revisar protocolo / owner / criticidade / versão
 -> informar impacto observado
 -> selecionar áreas realmente impactadas
 -> confirmação explícita
 -> RPC safra_start_treatment
 -> valida sessão corporativa viva
 -> resolve scenario_version/owner/área no servidor
 -> cria treatment ACTIVE
 -> grava TREATMENT_OPENED
 -> retorna snapshot + estados de SLAs estruturados
```

### Segurança e integridade

- browser continua sem SELECT direto em `scenarios`;
- browser continua sem INSERT direto em `treatments` e `treatment_events`;
- `anon` não executa catálogo nem START;
- `authenticated` executa somente os RPCs governados;
- ator vem de `auth.uid()`;
- timestamps vêm do banco;
- payload não aceita override de owner, criticidade, version_id ou horário;
- retry/duplo clique usa UUID de idempotência;
- áreas impactadas são validadas contra a versão PUBLISHED;
- criticidade NULL continua explícita;
- nenhum SLA é inferido a partir de texto.

### Evidência

```text
FINAL_VALIDATION_HEAD = c0edd12efce96a97bddff952e71546b248f1f695
MIGRATION = 20260927142000_c08_start_end_to_end.sql
APP_SMOKE_129 = PASS
DATABASE_DISPOSABLE_167 = PASS
C08_PGTAP = 24/24 PASS
DIRECT_DATA_API_DENIAL = PASS
DIRECT_RPC_ANON_DENIAL = PASS
ROLLBACK_REHEARSAL = PASS
DATABASE_LINT = PASS
PRIMARY_MIGRATION_TRACKED = true
PRIMARY_STARTABLE_SCENARIOS = 11
PRIMARY_TREATMENTS_AFTER_DEPLOY = 0
LOVABLE_RUNTIME = ready @ c0edd12efce96a97bddff952e71546b248f1f695
```

### Ponto exato onde paramos

A implementação técnica está concluída e promovida.

Ainda NÃO foi executada uma homologação humana completa no runtime publicado clicando o fluxo com uma sessão Microsoft corporativa real.

```text
C08_START_IMPLEMENTATION = PASS
C08_START_AUTOMATED_VALIDATION = PASS
C08_START_PRIMARY_PROMOTION = PASS
C08_START_REAL_SESSION_UX_HOMOLOGATION = PENDING
C08_COMPLETE = false
```

### Próximo passo exato

`Homologar Abrir Protocolo / START no runtime com uma sessão Microsoft corporativa real`.

Validar:
1. login corporativo;
2. carregamento dos 11 cenários;
3. owner/versão/criticidade exibidos;
4. seleção de áreas impactadas;
5. confirmação do START;
6. criação de uma treatment real controlada;
7. TREATMENT_OPENED;
8. relógio exibido;
9. retry/duplo clique;
10. leitura pós-START;
11. mensagem quando não houver SLA estruturado.

Somente depois seguir para as demais telas/UX do C08.

### Pendências deliberadas que permanecem

- GI-SAFRA-001: lista nominal dos quatro CRITICAL ainda não existe; criticidade NULL é não bloqueante;
- GI-SAFRA-002: thresholds 2/4/10/11 ainda não existem; automação fica NOT_CONFIGURED;
- GI-SAFRA-003: fonte oficial Curva A ainda não existe; SAFRA-09 permanece manual;
- GI-SAFRA-004: regra definitiva para múltiplas tratativas ACTIVE;
- GI-SAFRA-005: provider/canal produtivo de comunicação;
- GI-SAFRA-009: materialização produtiva dos SLAs candidatos em nova scenario_version.
