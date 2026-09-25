# STATUS — incident-log-pro / Painel Safra

> Atualizado em: 24/09/2026  
> Fase atual: **SAFRA-C03 — Glossário e modelo de domínio**  
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
