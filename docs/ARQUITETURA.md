# ARQUITETURA — Painel Safra

> Documento canônico de arquitetura.
> Atualizado em: 27/09/2026
> Estado: **SAFRA-C08 em execução — START end-to-end implementado; C01-AUD reconciliando documentação e domínios corporativos**

## 1. Objetivo

Registrar a arquitetura real do Painel Safra e o contrato entre identidade, catálogo, operação e governança.

O Painel Safra evolui o repositório existente. Não criar aplicação paralela e não criar estruturas duplicadas quando um conceito já possui fonte de verdade aprovada.

## 2. Arquitetura atual confirmada

~~~text
GitHub <-> Lovable
          |
          v
    Lovable Cloud
       PRIMARY
          |
          +-- PostgreSQL
          +-- Supabase Auth / Data API
          +-- RLS / grants / funções
          |
Microsoft Entra ID
          |
          v
  Lovable Cloud Auth
          |
          v
      Supabase Auth
          |
          v
       auth.uid()
~~~

Stack de aplicação:

- React 19;
- TanStack Start / Router / Query;
- TypeScript;
- Vite;
- Tailwind;
- Recharts.

Banco:

- backend provider: **Lovable Cloud**;
- database role: **PRIMARY**;
- PostgreSQL;
- stack Supabase;
- RLS habilitada;
- `anon` sem acesso aos dados internos;
- autenticação corporativa Microsoft homologada;
- acesso funcional restrito a `editoradobrasil.com.br` e `editoradobrasil1.onmicrosoft.com`;
- autorização interna governada pelo banco, com sessão viva e RBAC separado de domínio/ownership.

## 3. Autoridade de migrations

Decisão vigente:

~~~text
supabase/migrations = ÚNICA FONTE CANÔNICA DE MIGRATIONS
Drizzle = tooling/ORM auxiliar, sem autoridade de schema/deploy
~~~

A migration-base do domínio Safra é:

`supabase/migrations/20260925170000_c05_schema_v2_canonical_base.sql`

O histórico remoto de migrations foi reconciliado. Mudança futura de schema deve nascer em migration canônica e ser validada em banco descartável antes de produção.

## 4. Domínios canônicos

### 4.1 Identidade e papéis

Fonte de verdade já existente e reutilizada:

- `private.safra_principals`;
- `private.safra_role_grants`.

Papéis funcionais:

- `safra_platform_admin`;
- `safra_governance_admin`;
- `safra_executive_admin`;
- `scenario_owner`.

Regra estrutural:

~~~text
PAPEL != OWNERSHIP
administração != ownership automático
scenario_owner = elegibilidade funcional
scenario_owners = vínculo explícito pessoa <-> cenário
~~~

Não criar `safra_user_roles` concorrente.

### 4.2 Catálogo organizacional

#### `operational_areas`

Representa áreas operacionais reais.

Regras:
- código e nome únicos;
- `Geral` não é área operacional;
- pode ser ativada/desativada;
- cenário possui uma área responsável;
- versões podem declarar áreas potencialmente impactáveis;
- tratativas registram áreas efetivamente impactadas.

#### `systems`

Catálogo de sistemas/plataformas relevantes para os cenários.

Relação com cenário é versionada por `scenario_version_systems`, permitindo que uma nova versão altere os sistemas relacionados sem reescrever histórico.

### 4.3 Cenários e versionamento

#### `scenarios`

Identidade estável da contingência.

Contém:
- código;
- nome;
- lifecycle;
- área responsável;
- referência para a versão publicada corrente.

#### `scenario_versions`

Fotografia versionada do conteúdo operacional.

Contém:
- gatilho;
- detecção;
- protocolo;
- impacto esperado;
- criticidade;
- referência de fonte;
- estado DRAFT/PUBLISHED/RETIRED.

Regras:
- uma versão publicada não é reescrita;
- uma versão retired é imutável;
- apenas uma versão PUBLISHED pode estar corrente por cenário;
- criticidade pode permanecer nula enquanto houver governance issue aberta;
- valores não nulos: `CRITICAL | HIGH | MODERATE`.

#### Relações versionadas

- `scenario_version_impacted_areas`;
- `scenario_version_systems`;
- `scenario_slas`.

Essas relações pertencem à **versão**, não ao cenário estável, para preservar a fotografia histórica.

### 4.4 Owners

`scenario_owners` representa o vínculo explícito entre cenário e principal responsável.

Regras:
- no máximo um owner ativo por cenário;
- owner ativo precisa ser principal elegível com role `scenario_owner`;
- troca de owner preserva histórico por `valid_from/valid_to`;
- platform/governance/executive admin não herdam ownership.

O START grava snapshot de owner e área responsável na tratativa para impedir reescrita histórica quando o cenário mudar depois.

### 4.5 SLAs

`scenario_slas` pertence a `scenario_version`.

Cada SLA define:
- código;
- rótulo;
- `start_event`;
- `end_event`;
- alvo estruturado quando aplicável;
- texto-alvo;
- regra de aplicabilidade.

Princípios:
- um cenário pode ter múltiplos SLAs;
- duração é derivada de eventos/timestamps;
- SLA operacional não é SLO/RTO/RPO da aplicação;
- thresholds não aprovados permanecem ausentes, nunca inventados.

### 4.6 Treatments

`treatments` representa uma ocorrência real criada por START.

Estados canônicos:

~~~text
ACTIVE
RESOLVED
CANCELLED
~~~

O treatment congela no START:
- `scenario_id`;
- `scenario_version_id`;
- `owner_id_at_start`;
- `responsible_area_id_at_start`;
- ator;
- timestamp;
- `correlation_id`;
- `idempotency_key`.

Relações:
- `treatment_impacted_areas` — áreas efetivamente impactadas;
- `treatment_impact_measurements` — impacto quantitativo com métrica, valor, unidade, fonte e data.

Regras:
- tratamento encerrado não reabre;
- CANCEL usa campos próprios e justificativa;
- END e CANCEL não são delete;
- múltiplos ACTIVE do mesmo cenário continuam sem bloqueio estrutural até decisão M01.

### 4.7 Eventos

`treatment_events` é a trilha append-only da ocorrência.

Eventos canônicos iniciais:

- `TREATMENT_OPENED`;
- `NOTE_ADDED`;
- `IMPACT_AREA_ADDED`;
- `IMPACT_AREA_REMOVED`;
- `ESCALATION_CHANGED`;
- `SLA_BREACHED`;
- `TREATMENT_RESOLVED`;
- `TREATMENT_CANCELLED`;
- `ADMIN_CORRECTION_RECORDED`.

Cada evento registra:
- treatment;
- tipo;
- ator;
- timestamp server-side;
- correlation id;
- idempotency key quando aplicável;
- payload contextual.

Eventos não são editados para corrigir histórico. Correções administrativas geram novo evento.

### 4.8 Escalonamentos

`treatment_escalations` representa elevação formal da governança da ocorrência.

Níveis:

~~~text
NONE
TECHNICAL_CRISIS
BUSINESS_CRISIS
EXECUTIVE
~~~

Regras:
- escalonamento não altera o status do treatment;
- criticidade de cenário não é escalonamento;
- no máximo um escalonamento vigente por treatment;
- histórico é preservado por validade temporal.

### 4.9 Notificações

`notifications_log` registra intenção/entrega de comunicação operacional.

Pode se relacionar a:
- treatment;
- proposal.

Campos estruturais incluem:
- tipo;
- destinatário;
- canal;
- provider;
- estado de entrega;
- idempotency key;
- correlation id;
- timestamps de fila/envio/falha;
- motivo de falha.

Provider e canal produtivos permanecem decisão de M05.

A mesma idempotency key não pode gerar duas entregas lógicas.

### 4.10 Propostas

O 12º card persiste em `scenario_proposals`.

A proposta:
- nasce de usuário Microsoft autenticado;
- preserva snapshot de nome/e-mail;
- registra título, problema e impacto na Safra;
- **não é cenário produtivo**;
- **não aceita START**.

`scenario_proposal_owner_responses` registra aceite/recusa dos candidatos a owner.

A publicação de um novo cenário ocorre somente após o fluxo de governança previsto para M10.

### 4.11 Governance issues

`governance_issues` registra decisões materiais ainda abertas.

Exemplo vigente:
- `GI-SAFRA-001` — identificação formal dos quatro cenários CRITICAL.

Regra:
- questão aberta não pode ser convertida em default de implementação;
- resolução exige ator, timestamp e texto de resolução;
- somente após resolução a decisão pode alimentar nova versão/seed/regra.

## 5. Relações centrais

~~~text
private.safra_principals
        |
        +--> private.safra_role_grants
        |
        +--> scenario_owners
                  |
                  v
operational_areas --> scenarios --> scenario_versions
                          |              |
                          |              +--> scenario_version_impacted_areas
                          |              +--> scenario_version_systems --> systems
                          |              +--> scenario_slas
                          |
                          +--> treatments
                                  |
                                  +--> treatment_impacted_areas
                                  +--> treatment_impact_measurements
                                  +--> treatment_events
                                  +--> treatment_escalations
                                  +--> notifications_log

scenario_proposals
        |
        +--> scenario_proposal_owner_responses
        +--> notifications_log

governance_issues
        |
        +--> decisões pendentes que NÃO viram default
~~~

## 6. Invariantes de arquitetura

1. `scenario` é identidade; `scenario_version` é conteúdo; `treatment` é ocorrência.
2. START sempre congela a versão usada.
3. Ownership é vínculo explícito, nunca herança de papel administrativo.
4. Histórico operacional usa `ON DELETE RESTRICT`; não usar cascade destrutivo.
5. Versão PUBLISHED não é reescrita.
6. Eventos e medições históricas são append-only.
7. Timestamps oficiais de ações críticas vêm do backend/banco.
8. Idempotência e correlation id são obrigatórios nas mutações críticas.
9. Proposta não é cenário publicado.
10. Governance issue aberta não pode virar regra/default por inferência.
11. `Geral` é visão, não área.
12. REPLICA permanece desabilitada; backup/restore continua obrigatório.

## 7. Segurança e exposição

As 17 tabelas novas do domínio C05 foram criadas com:
- RLS habilitada;
- deny-by-default para `anon` e `authenticated`;
- acesso técnico de `service_role` sem `TRUNCATE`.

Isso é deliberado: a criação do schema não antecipa as policies de operação que serão abertas somente junto às RPCs/regras autorizadas.

Para tabelas expostas pela Data API, grants e RLS são controles distintos e ambos precisam estar corretos.

## 8. Operações críticas

Estado atual:

- START está implementado no C08 por `public.safra_start_treatment(...)` e catálogo governado `public.safra_get_start_catalog()`;
- END/CANCEL permanecem para as fases de fechamento correspondentes e não devem ser antecipados;
- escalonamento e mutações auxiliares continuam sujeitos às fases próprias;
- o browser não recebe acesso direto às tabelas Safra para substituir RPCs governadas.

As operações críticas implementadas/devem ser implementadas de forma transacional e concentrar:
- autenticação/autorização;
- validação de estado;
- timestamp server-side;
- idempotência;
- correlation id;
- mutação;
- evento de auditoria;
- preparação de notificação.

Operações críticas não devem depender de `.insert()`/`.update()` genérico no navegador.

## 9. Legado TI

`applications` e `incidents` continuam preservados como domínio legado de confiabilidade de TI.

Eles não são substitutos de `scenarios`/`treatments`.

Ponte futura entre incidentes TI e tratativas Safra só deve ser criada quando houver regra explícita de integração.

## 10. REPLICA, backup e recovery

~~~text
replica_enabled = false
~~~

Não haverá segundo banco sincronizado.

A aplicação permanece com:
- service_class = CRITICO;
- RTO = 30 minutos;
- RPO = 5 minutos.

Backup, restore e recovery testado serão fechados no SAFRA-C09.

## 11. Fontes de verdade

- arquitetura: `docs/ARQUITETURA.md`;
- vocabulário: `docs/GLOSSARIO_DOMINIO.md`;
- regras: `docs/REGRAS_NEGOCIO.md`;
- decisões: `docs/DECISOES.md`;
- execução: `docs/STATUS.md`;
- sequência: `docs/ROADMAP.md`;
- schema: `supabase/migrations`;
- perfil: `docs/PROJECT_PROFILE.yaml`.

## 12. Regra de mudança

Mudança material de domínio/arquitetura deve:
1. registrar decisão quando alterar contrato aprovado;
2. atualizar documentação canônica;
3. criar migration quando alterar persistência;
4. atualizar testes derivados;
5. validar em banco descartável;
6. preservar histórico já publicado.
