# STATUS — incident-log-pro / Painel Safra

> Atualizado em: 24/09/2026  
> Fase atual: **SAFRA-C00 — Congelar baseline e conter riscos P0**  
> Escopo desta rodada: registrar **baseline, schema, rotas, migrations e acesso Supabase atuais**, sem evolução funcional.

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

### P0-01 — `.env` versionado

- `.env` está atualmente tracked pelo Git.
- `.gitignore` atual não contém regra para ignorar `.env`.
- valores não foram reproduzidos neste documento.

Ações 6 a 9 do SAFRA-C00 permanecem necessárias.

### P0-02 — CRUD para `anon`

O papel `anon` possui CRUD nas tabelas principais.

### P0-03 — Policies abertas

As policies atuais usam `USING (true) WITH CHECK (true)`.

### P0-04 — UI sem barreira de autenticação observada

As rotas do produto não têm guard de autenticação no router.

### P0-05 — Drift live ainda desconhecido

Sem acesso ao projeto `trqkwqkjjjeppuddwenu` pela conexão Supabase atual, não é possível certificar que Git e banco live estão sincronizados.

---

## 9. Progresso SAFRA-C00

| Item | Ação | Estado após esta rodada |
|---|---|---|
| 1 | Registrar commit baseline | ✅ Registrado |
| 2 | Registrar schema atual | ✅ Registrado |
| 3 | Documentar rotas atuais | ✅ Registrado |
| 4 | Inventariar migrations | ✅ Registrado |
| 5 | Inventariar acesso Supabase | ✅ Inventariado, com limitação live explícita |
| 6 | Remover `.env` do tracking | ⏳ Pendente |
| 7 | Ajustar `.gitignore` e preservar `.env.example` | ⏳ Pendente |
| 8 | Identificar secrets possivelmente expostos | ⏳ Pendente |
| 9 | Rotacionar secrets aplicáveis | ⏳ Pendente |
| 10 | Revisar grants atuais | ⏳ Pendente |
| 11 | Remover CRUD indiscriminado de `anon` | ⏳ Pendente |
| 12 | Substituir policies `USING (true)` | ⏳ Pendente |
| 13 | Testar acesso direto não autorizado | ⏳ Pendente |
| 14 | Preservar histórico Git sem force push | ✅ Regra mantida |

---

## 10. Próximo passo canônico

O próximo bloco do SAFRA-C00 deve começar pela **contenção do `.env` e revisão de secrets**, seguindo a ordem já definida no `docs/ROADMAP.md`.

Não avançar para redesign funcional antes de fechar os bloqueadores P0 desta fase.
