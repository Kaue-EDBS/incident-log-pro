# ARQUITETURA — Painel Safra

> Documento canônico de arquitetura.
> Atualizado em: 24/09/2026
> Estado: **SAFRA-C01 — consolidado, com decisões materiais ainda abertas**

## 1. Objetivo

Registrar a arquitetura real e a arquitetura alvo, separando o que já existe, o que foi aprovado, o que é transitório e o que depende de decisão humana.

## 2. Princípio arquitetural

O Painel Safra evolui o projeto existente. Não criar aplicação paralela.

```text
GitHub <-> Lovable
          |
          v
    Lovable Cloud
       PRIMARY
          |
          +-- PostgreSQL
          +-- Auth
          +-- RLS / Policies
          +-- Data API
          +-- stack Supabase
```

**Lovable Cloud é o provedor do backend e governa o PRIMARY.**
Supabase é a stack técnica utilizada pelo banco, Auth e Data API.

## 3. Estado atual confirmado

### Aplicação

- React 19;
- TanStack Start / Router / Query;
- TypeScript;
- Vite;
- Tailwind;
- Recharts.

### Banco

- backend provider: **Lovable Cloud**;
- database role: **PRIMARY**;
- engine: PostgreSQL;
- database stack: Supabase;
- RLS habilitada;
- `anon` sem acesso após SAFRA-C00;
- autorização transitória via `app_metadata.safra_access`.

### Tooling de banco

O repositório hoje contém:

1. `supabase/migrations/` — migrations históricas e hardening do C00;
2. `drizzle.config.ts` — PostgreSQL via `LOVABLE_DB_MIGRATION_URL`.

A convivência é estado de transição. O SAFRA-C05 deve definir uma estratégia canônica e impedir duas autoridades concorrentes para migrations.

### Git

- branch canônica: `main`;
- GitHub e Lovable compartilham a mesma linha de commits;
- force push, rebase destrutivo, amend ou squash de commits já sincronizados são proibidos.

## 4. Arquitetura funcional atual

```text
Browser
  |
  v
TanStack / React
  |
  v
src/lib/queries.ts
  |
  v
Supabase client
  |
  v
Lovable Cloud PRIMARY
  |
  +-- applications
  +-- incidents
```

As rotas atuais representam o Reliability Monitor legado e serão preservadas apenas onde fizer sentido para o domínio de TI.

## 5. Arquitetura alvo

```text
[Browser / TV]
      |
      v
[TanStack / React]
      |
      v
[Auth + autorização]
      |
      v
[Lovable Cloud PRIMARY]
      |
      +-- catálogo Safra
      |     +-- operational_areas
      |     +-- systems
      |     +-- scenarios
      |     +-- scenario_versions
      |     +-- scenario_owners
      |     +-- scenario_slas
      |     +-- protocol_step_definitions
      |
      +-- operação
      |     +-- treatments
      |     +-- treatment_steps
      |     +-- treatment_events
      |     +-- treatment_escalations
      |
      +-- governança
      |     +-- scenario_proposals
      |     +-- governance_issues
      |     +-- rule_versions
      |     +-- notifications_log
      |
      +-- RPC / funções transacionais
            +-- start_treatment
            +-- close_treatment
            +-- cancel_treatment
            +-- change_escalation
```

Operações críticas não devem depender apenas de `.insert()` ou `.update()` genérico no navegador.

## 6. Trust boundaries

### Navegador

Pode renderizar, coletar entrada e solicitar operações. Não pode decidir autorização, elevar papel ou usar secret/service role.

### Auth

Responsável por identidade.

Decisão aprovada:

```text
Microsoft Entra ID corporativo
        |
        v
      SSO
        |
        v
Lovable Cloud / Supabase Auth
        |
        v
identidade autenticada
```

Não haverá login local por senha como caminho funcional do produto.

Autenticação responde **quem é o usuário**. RBAC/RLS do Painel Safra responde **o que ele pode fazer**.

### Modelo RBAC aprovado

Papéis funcionais:

- `safra_admin`;
- `scenario_owner`.

Não existirão papéis funcionais separados para updater, gestor, diretoria ou viewer.

Modelo:

```text
user
 -> safra_admin
    ou
 -> scenario_owner + vínculos explícitos de cenário
```

`safra_admin` não recebe ownership de cenário automaticamente.

### Banco / RLS

Barreira obrigatória para dados expostos pela Data API.

Regra transitória do C00:

```text
authenticated
+ auth.uid presente
+ is_anonymous != true
+ app_metadata.safra_access = true
```

O SAFRA-C04 substituirá isso pelo RBAC definitivo.

### Integrações externas

No MVP nenhuma fonte cria tratativa automaticamente.

```text
external source
 -> adapter
 -> normalized signal
 -> rule evaluation
 -> human confirmation
 -> treatment
```

## 7. Fontes de verdade técnicas

- roadmap: `docs/ROADMAP.md`;
- execução: `docs/STATUS.md`;
- arquitetura: `docs/ARQUITETURA.md`;
- perfil: `docs/PROJECT_PROFILE.yaml`;
- regras: `docs/REGRAS_NEGOCIO.md`;
- decisões: `docs/DECISOES.md`;
- paridade: `docs/MATRIZ_PARIDADE.md`;
- privacidade: `docs/PRIVACIDADE_THREAT_MODEL.md`.

## 8. Segurança atual

Fechado no C00:

- `.env` fora do Git;
- `anon` sem grants;
- policies permissivas removidas;
- RLS real ativa;
- acesso sem autorização testado e negado;
- histórico Git preservado.

Ainda aberto:

- login corporativo;
- identidade definitiva;
- papéis Safra;
- ownership por cenário;
- autorização START/END;
- governança definitiva de migrations.

## 9. REPLICA

`replica_enabled = WAITING_HUMAN_DECISION`.

Não criar REPLICA apenas para cumprir framework.

## 10. Observabilidade e auditoria

O produto deve preservar eventos de START, passos, alterações relevantes, escalonamento, notificações, END e CANCEL. A trilha não pode depender apenas do frontend.

## 11. Pendências arquiteturais

**WAITING_HUMAN_DECISION**:

- service class da aplicação — atributo técnico do Framework EBSA, não derivado dos cenários;
- criticidade técnica/operacional da aplicação — distinta da criticidade CRITICAL/HIGH/MODERATE dos cenários;
- matriz fina de permissões entre `safra_admin` e `scenario_owner`;
- tratamento de usuário autenticado sem papel funcional;
- replica;
- RTO/RPO;
- retenção;
- canal de notificação;
- estratégia canônica de migrations.

## 12.1 Separação obrigatória de criticidades

```text
domínio Safra
 -> scenario.criticality = CRITICAL | HIGH | MODERATE

governança técnica
 -> application.service_class = WAITING_HUMAN_DECISION
 -> application.criticality = WAITING_HUMAN_DECISION
```

Os SLAs dos protocolos medem resposta operacional do cenário. Eles não definem SLO, RTO ou RPO do software.

## 12. Regra de mudança

Mudança material de arquitetura deve atualizar ARQUITETURA, PROJECT_PROFILE, DECISOES e STATUS e reabrir gates afetados quando necessário.
