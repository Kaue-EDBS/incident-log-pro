# STATUS — incident-log-pro / Painel Safra

> Atualizado em: 24/09/2026  
> Fase atual: **SAFRA-C05 — Schema v2, migrations e invariantes**  
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
