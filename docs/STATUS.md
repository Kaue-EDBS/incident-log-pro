# STATUS — incident-log-pro / Painel Safra

> Atualizado em: 24/09/2026  
> Fase atual: **SAFRA-C01 — Documentação canônica e PROJECT_PROFILE**  
> Escopo atual: consolidar fontes canônicas, perfil estruturado do projeto, arquitetura, privacidade, regras, paridade e decisões.

---

## 1. Baseline registrada

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

## 4. Rotas atuais

Fonte: `src/routes/` e `src/routeTree.gen.ts`.

| URL | Arquivo | Papel atual | Acesso no router |
|---|---|---|---|
| `/` | `src/routes/index.tsx` | Visão geral, filtros e métricas | sem guard de autenticação |
| `/novo-incidente` | `src/routes/novo-incidente.tsx` | abertura de incidente | sem guard de autenticação |
| `/incidentes` | `src/routes/incidentes.index.tsx` | histórico e filtros | sem guard de autenticação |
| `/incidentes/$id` | `src/routes/incidentes.$id.tsx` | acompanhamento, recuperação e finalização | sem guard de autenticação |
| `/aplicacoes` | `src/routes/aplicacoes.tsx` | resumo por aplicação | sem guard de autenticação |
| `/indicadores` | `src/routes/indicadores.tsx` | gráficos e comparativos | sem guard de autenticação |

O layout raiz está em `src/routes/__root.tsx`.

### Acesso a dados usado pelas rotas

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

Criado como `IN_PROGRESS`.

Isso é intencional: ainda existem decisões materiais marcadas como `WAITING_HUMAN_DECISION`, especialmente:

- service class;
- criticidade;
- identity provider;
- papéis definitivos;
- REPLICA;
- RTO/RPO;
- retenção;
- estratégia canônica de migrations.

### Estado do C01

**Estrutura documental: consolidada.**  
**PROJECT_PROFILE: criado e utilizável.**  
**Gate G3/G3.25: ainda não fechado**, pois o próprio roadmap exige não concluir enquanto houver UNKNOWN/WAITING_HUMAN_DECISION material.
