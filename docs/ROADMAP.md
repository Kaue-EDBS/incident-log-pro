# Roadmap de Reformulação - Painel Safra / incident-log-pro

**Versão:** 2.0  
**Data:** 23/09/2026  
**Status:** Roadmap canônico em execução — SAFRA-C00 concluído; SAFRA-C01 em andamento  
**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Destino do produto:** Painel Safra - Torre de Governança de Contingências  

---

## 0. Resumo executivo

O `incident-log-pro` nasceu como um monitor de confiabilidade de aplicações de TI, centrado em `applications`, `incidents`, MTTD, MTTR, MTBF, downtime e disponibilidade. Esse núcleo funciona como prova de persistência e de cálculo temporal, mas o produto desejado é maior e conceitualmente diferente.

O Painel Safra não deve ser transformado em um simples "incident manager multiárea". O produto-alvo é uma **torre corporativa de governança de contingências**, baseada em cenários pré-validados, donos definidos, protocolos padronizados, SLAs, criticidade, áreas impactadas, visibilidade executiva, trilha de auditoria e aprendizado operacional.

A decisão de negócio consolidada é:

```text
SINAL / OCORRÊNCIA
    -> identificação de um cenário elegível
    -> avaliação do dono do processo
    -> ativação humana do protocolo
    -> acompanhamento do protocolo
    -> escalonamento quando necessário
    -> encerramento humano
    -> histórico e governança
```

No MVP, as ferramentas de origem podem detectar problemas, mas **não devem criar automaticamente tratativas no Painel Safra**. A automação de integração fica como evolução posterior, porque a reunião de 22/09 explicitou a limitação de tempo, APIs e capacidade operacional.

Este roadmap reorganiza todo o projeto em três eixos de lógica de programação:

1. **COMEÇO** - tudo que precisa estar correto antes e no momento de iniciar um protocolo.
2. **MEIO** - tudo que acontece enquanto a contingência está ativa.
3. **FIM** - tudo que acontece no encerramento, histórico, aprendizado e governança.

O Framework EBSA v1.7 é útil, mas sua função é técnica: segurança, identidade, contratos, regras, testes, evidências, capacidade, recuperação e liberação. Ele **não substitui** a metodologia Safra e **não decide regras de negócio**.

---

# 1. Fontes de verdade e precedência

## 1.1 Fontes primárias do negócio

A implementação deve seguir esta precedência:

1. **`EDB06 - Matriz Contingencia v3.xlsx`**  
   Fonte principal para os 11 cenários validados, protocolos, área responsável, dono, áreas impactadas, SLA, ferramenta, acompanhamento, participantes de validação e mapeamento EDB05/EDB06.

2. **`Painel SAFRA.docx` - reunião de 22/09/2026**  
   Fonte principal para decisões posteriores sobre MVP, abertura manual, diferença entre chamado e protocolo, governança de acesso, criticidade, notificações, comitê de crise, novos cenários e limites de integração.

3. **`EDB06 - Protocolos de contingência v2.pdf`**  
   Material preliminar de desenho do conceito e protocolos. Usar como apoio quando não houver conflito com a Matriz v3 ou com decisões posteriores da reunião.

4. **`Plano de Ação - Metodologia do Painel Safra.md`**  
   Documento de consolidação metodológica. Útil como visão integrada, mas deve ser corrigido quando divergir das fontes primárias acima.

## 1.2 Fonte técnica atual

5. **Repositório `Kaue-EDBS/incident-log-pro`**  
   Fonte de verdade do estado implementado: banco, migrations, frontend, regras de métricas, integração Supabase e restrições reais do código.

## 1.3 Fonte de governança técnica

6. **Framework EBSA v1.7**  
   Fonte de padrões de engenharia, segurança, gates, evidências, contratos, dados, testes, capacidade e operação. Não possui autoridade para alterar a metodologia Safra.

## 1.4 Regra de resolução de conflito

Quando duas fontes divergirem:

```text
Matriz v3
    > decisão posterior explícita da reunião de 22/09
    > Protocolos v2 preliminar
    > consolidação metodológica
    > implementação legada
```

O Framework EBSA pode bloquear uma implementação insegura, mas não pode inventar conteúdo de negócio.

---

# 2. O que o produto é - e o que não é

## 2.1 Definição canônica

O Painel Safra é uma aplicação interna para:

- catalogar cenários de contingência;
- expor gatilho e contexto de cada cenário;
- permitir ao dono do processo ativar formalmente um protocolo;
- acompanhar o protocolo por marcos padronizados;
- controlar SLAs e tempo ativo;
- informar áreas impactadas;
- registrar escalonamentos e comitês de crise;
- dar visibilidade consolidada a gestão e diretoria;
- preservar histórico auditável;
- medir recorrência, duração, cumprimento de SLA e padrões de repetição;
- alimentar rituais de governança e revisão de processo.

## 2.2 O que ele não deve virar no MVP

O MVP não deve ser:

- ferramenta de observabilidade completa;
- substituto do OTRS;
- sistema de tickets;
- motor automático de incident response;
- sistema de monitoramento de todas as APIs da companhia;
- ferramenta que cria protocolos sem confirmação humana;
- orquestrador de remediações automáticas;
- repositório de números simulados apresentados como operação real.

## 2.3 Princípio central

> **A ferramenta de origem detecta ou ajuda a detectar. O Painel Safra governa a contingência.**

Portanto:

```text
DETECTION_MODE != ACTIVATION_MODE
```

Um cenário pode ter:

```text
detection_mode = AUTOMATIC | MANUAL | MIXED
protocol_activation_mode = MANUAL
```

No MVP, `protocol_activation_mode` será sempre manual.

---

# 3. Diagnóstico do incident-log-pro atual

## 3.1 O que já vale reaproveitar

- React 19 + TanStack Start/Router;
- Supabase/PostgreSQL;
- TanStack Query;
- estrutura de migrations;
- UUIDs;
- `created_at` / `updated_at`;
- trigger de atualização temporal;
- persistência de timestamps;
- cronômetro reconstruído a partir do banco;
- conceito de `application` e `incident` para TI;
- MTTD, MTTR, MTBF, downtime e disponibilidade;
- componentes como `MetricCard`, `StatusBadge`, `LiveTimer` e filtros;
- rotas e layout responsivo já existentes;
- integração GitHub <-> Lovable já estabelecida.

## 3.2 O que está fora do domínio-alvo

O domínio atual é aproximadamente:

```text
Application
   -> Incident
       -> timestamps
       -> MTTD / MTTR / MTBF
       -> resolução
```

O domínio Safra precisa ser:

```text
Área operacional
   -> Cenário versionado
       -> Dono
       -> Áreas impactáveis
       -> Ferramentas relacionadas
       -> SLAs
       -> Passos de protocolo
       -> Criticidade
       -> regras de elegibilidade
           -> Tratativa ativada
               -> áreas realmente impactadas
               -> versão congelada do cenário
               -> relógios
               -> passos/marcos
               -> eventos
               -> escalonamentos
               -> encerramento
               -> histórico
```

## 3.3 P0 de segurança identificado

Antes de ampliar o produto:

- `.env` está versionado no repositório;
- o `.gitignore` atual não bloqueia `.env`;
- migrations atuais concedem CRUD a `anon` e `authenticated`;
- policies atuais usam `USING (true)` e `WITH CHECK (true)`;
- a autorização por papel ainda não representa os donos e áreas do Safra.

Isso é bloqueador para expansão corporativa.

## 3.4 Regra de preservação do histórico Git

O repositório é conectado ao Lovable. Portanto:

- não fazer force push;
- não reescrever histórico publicado;
- não usar rebase/amend/squash destrutivo sobre commits já sincronizados;
- correções devem entrar em novos commits normais.

---

# 4. Avaliação do Framework EBSA v1.7

## 4.1 Veredito

**Sim, o framework tem alta utilidade para este projeto.**

Mas ele deve ser usado como **framework de engenharia**, não como método para desenhar o protocolo de contingência.

## 4.2 Onde ele ajuda muito

| Tema do Framework | Utilidade no Safra | Aplicação prática |
|---|---:|---|
| I-1 / SEC-001 | Muito alta | evitar exposição de secrets e tratar `.env` versionado |
| I0 / G0 | Alta | congelar repo, ambiente, intenção e responsáveis |
| G2 / G3 | Muito alta | GitHub-first e documentação canônica |
| G3.25 PROJECT_PROFILE | Muito alta | decidir criticidade do sistema, auth, dados, integrações e replica |
| G3.5 Threat Model | Alta | mapear abuse cases de protocolo, acesso e dados internos |
| G4 / G4.5 | Alta | jornada crítica, TV mode, responsividade e acessibilidade |
| G5 | Muito alta | RLS, autorização server-side, integridade e migrations |
| G5.25 | Alta | revisão, secrets, dependências e governança do repositório |
| G5.5 | Alta | RTO/RPO, restore, capacidade e pico da Safra |
| G6 | Muito alta | contratos para Intelipost, Protheus, WMS, Cockpit etc. |
| G6.5 | Muito alta | transformar cada regra em contrato versionado |
| DATA_RELEASE | Alta | controlar entrada de cada fonte real nova |
| G7 | Muito alta | testes de regra, RLS, fluxo e concorrência |
| G8 | Alta | candidata restrita para validação |
| G10 | Muito alta | homologação com donos do processo |
| G10.5 | Muito alta | auditoria antes de abrir para todos |
| G11 | Alta | rotina de operação, incidentes do próprio Painel, recuperação |
| G9 | Condicional | usar somente se `replica_enabled=true` |

## 4.3 Onde não aplicar mecanicamente

### A. G1 - projeto novo no Lovable

O projeto já existe e já possui base funcional. Não há razão para recriar scaffold.

A ação correta é:

```text
G1 = REVALIDAR BASE EXISTENTE
```

Não:

```text
G1 = CRIAR OUTRO PROJETO
```

### B. G9 - REPLICA

O framework é explícito: replica é condicional.

Portanto:

```text
replica_enabled = WAITING_HUMAN_DECISION
```

Se a decisão for `false`, G9 vira N/A justificado.

Não criar Supabase Replica apenas para "cumprir framework".

### C. Service class e criticidade técnica da aplicação

Esses atributos vêm do **Framework EBSA** e não dos três materiais-mãe do Painel Safra.

Os materiais-mãe tratam de **criticidade do cenário/protocolo**, não de classificação técnica do software:

```text
Matriz v3 / Protocolos v2 / reunião 22/09
    -> criticidade do CENÁRIO
       CRITICAL | HIGH | MODERATE
```

Já o Framework EBSA exige uma decisão separada sobre o próprio sistema:

```text
Framework EBSA
    -> service_class da APLICAÇÃO
    -> criticidade técnica / operacional da APLICAÇÃO
```

Portanto, é proibido derivar `service_class`, SLO, RTO ou RPO do Painel Safra a partir do SLA ou da criticidade de um protocolo.

Referências do Framework para service class:

- `INTERNO`: SLO 99,5%, RTO 240 min, RPO 1440 min;
- `OPERACIONAL`: SLO 99,9%, RTO 60 min, RPO 15 min;
- `CRITICO`: SLO 99,95%, RTO 30 min, RPO 5 min.

**Estado:** `WAITING_HUMAN_DECISION`.

A decisão deverá considerar o impacto de indisponibilidade do **próprio Painel Safra**, e não o impacto do cenário monitorado.

### D. DATA_RELEASE

O projeto já possui dados reais de incidentes de TI. O framework deve ser aplicado de forma de retrofit:

- validar o fluxo existente;
- bloquear novas fontes até contrato e autorização;
- emitir DATA_RELEASE para cada nova integração real.

### E. Não transformar gate em burocracia sem efeito

Gate só deve ser considerado concluído quando existir evidência útil.

Não criar documento apenas para marcar checkbox.

---

# 5. Perfil inicial recomendado - ainda não confirmado

Este é um **perfil candidato**, não uma decisão final.

```yaml
project_name: Painel Safra
project_type: internal_operational_control
service_class: WAITING_HUMAN_DECISION   # atributo técnico do Framework EBSA
exposure: internal
backend_type: lovable_cloud_postgres
primary_role: primary
application_criticality: WAITING_HUMAN_DECISION # atributo técnico; não é criticidade de cenário
scenario_criticality:
  values: [CRITICAL, HIGH, MODERATE]
  source: materiais_mae
  status: APPROVED
human_interface: true
replica_enabled: WAITING_HUMAN_DECISION
auth_required: true
identity_provider: MICROSOFT_ENTRA_ID
auth_method: CORPORATE_SSO
local_password_login: false
privileged_roles: true
personal_data: true   # identidade/nome/e-mail de usuários internos
sensitive_data: false # confirmar
children_or_adolescents_data: false
storage_files: false  # confirmar escopo futuro
external_integrations: false # MVP; true quando integração real entrar
public_api: false
payments_or_financial_impact: false # confirmar se algum fluxo futuro alterar isso
automated_decisioning: false # MVP: regra sugere, humano decide
domain_rules_required: true
```

Campos `WAITING_HUMAN_DECISION` não podem ser convertidos silenciosamente em `false`.

---

# 6. Decisões metodológicas já consolidadas

## D-01 - Evoluir o incident-log-pro

Não criar segundo aplicativo paralelo.

## D-02 - Preservar applications/incidents

Essas tabelas continuam atendendo o domínio de confiabilidade de TI.

Elas não devem ser forçadas a representar todo o Safra.

## D-03 - Geral é visão, não área operacional

Modelar:

- Logística;
- TI;
- E-commerce;
- PCP;
- Pós-Vendas;
- Comercial;
- Fiscal/DAF.

`Geral` deve ser uma visão agregadora do produto.

## D-04 - Detecção e ativação são conceitos separados

Uma origem pode detectar automaticamente, mas a tratativa só nasce após ação humana autorizada.

## D-05 - Protocolo != chamado

O chamado resolve uma ocorrência operacional.

O protocolo comunica e governa uma contingência relevante.

## D-06 - Dono do processo controla START/END

O líder/dono do processo pode:

- iniciar protocolo;
- encerrar protocolo;
- designar pessoas para atualizar acompanhamento.

Outros usuários não devem conseguir promover uma ocorrência a protocolo por conta própria.

## D-07 - Não apagar tratativa

Uma abertura errada vira `CANCELLED` com justificativa.

## D-08 - Novo cenário exige governança

Proposta não entra diretamente como cenário produtivo.

## D-09 - Criticidade tem três níveis

- `CRITICAL`;
- `HIGH`;
- `MODERATE`.

Lista dos quatro cenários críticos: **WAITING_HUMAN_DECISION**.

## D-10 - Recorrência não define crise sozinha

Quantidade de ocorrências é indicador, não gatilho automático de crise.

Também medir:

- duração acumulada;
- protocolos simultâneos;
- SLA breach;
- impacto;
- tempo em contingência;
- escalonamentos.

## D-11 - Comitê de crise é escalonamento, não status do protocolo

O protocolo continua ativo e pode possuir nível de escalonamento.

## D-12 - Papéis funcionais aprovados

O modelo foi simplificado para apenas dois papéis:

- `safra_admin`;
- `scenario_owner`.

Não existirão `scenario_updater`, `manager_viewer`, `executive_viewer` ou `viewer` como papéis funcionais.

Regras:

- admin não implica ownership automático;
- ownership depende de vínculo explícito com cenário;
- matriz detalhada de permissões entre os dois papéis: **WAITING_HUMAN_DECISION**;
- acesso de usuário Microsoft autenticado sem papel: **WAITING_HUMAN_DECISION**.

---

# 7. Modelo de domínio alvo

## 7.1 Entidades de catálogo

### `operational_areas`

Representa as sete áreas operacionais.

Campos mínimos:

```text
id
code
name
is_active
created_at
updated_at
```

### `systems`

Catálogo das ferramentas/sistemas associados aos cenários.

Exemplos:

- Protheus;
- GoDeep;
- Intelipost;
- WMS;
- Cockpit;
- Mensageria;
- monitoramento de TI;
- Painel de Protocolos / BI.

Campos:

```text
id
code
name
description
system_type
is_active
created_at
updated_at
```

### `scenarios`

Identidade estável do cenário.

Não concentrar toda regra mutável aqui.

Campos:

```text
id
code
name
responsible_area_id
lifecycle_status
current_version_id
created_at
updated_at
```

### `scenario_versions`

Versiona o conteúdo operacional.

Campos:

```text
id
scenario_id
version
trigger_description
detection_mode
activation_mode
criticality
monitoring_description
mapping_code
validation_notes
valid_from
valid_to
status
created_by
approved_by
approved_at
created_at
```

A tratativa deve apontar para uma versão específica.

### `scenario_owners`

Evita owner como texto solto.

```text
id
scenario_id
user_id
role
valid_from
valid_to
```

### `scenario_impacted_areas`

Relação N:N das áreas potencialmente impactáveis.

### `scenario_systems`

Relação N:N entre cenário e sistemas.

Campo `role`:

```text
DETECTION
SOURCE
OPERATIONAL_SUPPORT
MONITORING
COMMUNICATION
```

### `scenario_slas`

Um cenário pode possuir múltiplos compromissos temporais.

```text
id
scenario_version_id
code
name
start_event
end_event
target_value
target_unit
required
sort_order
```

### `protocol_step_definitions`

```text
id
scenario_version_id
step_number
title
description
required_for_close
created_at
```

`required_for_close` deve ser decidido por cenário ou política; não assumir que todo passo é bloqueante.

## 7.2 Entidades operacionais

### `treatments`

Representa uma ativação real de protocolo.

```text
id
scenario_id
scenario_version_id
status
opened_by
opened_at
closed_by
closed_at
cancelled_by
cancelled_at
cancellation_reason
scope_description
impact_summary
resolution_summary
current_escalation_level
related_incident_id
created_at
updated_at
```

Estados sugeridos:

```text
ACTIVE
RESOLVED
CANCELLED
```

Não usar estados de crise dentro do mesmo campo.

### `treatment_impacted_areas`

Áreas efetivamente impactadas naquela ocorrência.

### `treatment_steps`

Estado do checklist/marcos daquela tratativa.

```text
id
treatment_id
protocol_step_definition_id
status
completed_by
completed_at
notes
```

Status sugeridos:

```text
PENDING
IN_PROGRESS
DONE
NOT_APPLICABLE
```

### `treatment_events`

Trilha append-only de auditoria.

Eventos possíveis:

```text
TREATMENT_OPENED
STEP_STARTED
STEP_COMPLETED
STEP_MARKED_NA
IMPACT_AREA_ADDED
IMPACT_AREA_REMOVED
ESCALATION_CHANGED
NOTE_ADDED
SLA_BREACHED
TREATMENT_RESOLVED
TREATMENT_CANCELLED
```

Campos:

```text
id
treatment_id
event_type
actor_id
occurred_at
payload_json
correlation_id
```

### `treatment_escalations`

```text
id
treatment_id
level
reason
opened_by
opened_at
closed_by
closed_at
notes
```

Níveis:

```text
NONE
TECHNICAL_CRISIS
BUSINESS_CRISIS
EXECUTIVE
```

### `notifications_log`

Não depender de "e-mail enviado" apenas no client.

```text
id
treatment_id
notification_type
recipient_id
recipient_email
status
provider_message_id
sent_at
error
```

## 7.3 Governança

### `scenario_proposals`

Workflow:

```text
DRAFT
SUBMITTED
UNDER_REVIEW
APPROVED
REJECTED
PUBLISHED
```

Campos mínimos:

```text
name
trigger
proposed_area
proposed_owner
criticality
sla
impacted_areas
steps
justification
submitted_by
reviewed_by
reviewed_at
```

### `governance_issues`

Registra lacunas reais.

```text
id
entity_type
entity_id
issue_type
description
owner
status
due_date
resolution
```

### `rule_versions`

Opcional, caso regras sejam formalizadas separadamente de `scenario_versions`.

---

# 8. Matriz dos 11 cenários validados - baseline do seed

A carga inicial deve vir da Matriz v3, não ser redigitada manualmente.

| # | Cenário | Área responsável | Dono v3 | Áreas impactadas | SLA resumido | Ferramentas | Pendência conhecida |
|---:|---|---|---|---|---|---|---|
| 1 | Insucesso de entrega | Logística | Daniel Garcia | Pós-Vendas, E-commerce, Comercial | falha <=2h; tratativa <=48h | Intelipost + Painel | nenhuma estrutural |
| 2 | Transportadora fora do ar | Logística | Daniel Garcia | TI, Comercial | plano B <=4h; clientes comunicados | Intelipost + Painel | definir `X h` |
| 3 | Atraso (+48h) sem causa | Logística | Daniel Garcia | Pós-Vendas, Comercial | alerta 48h; retorno <=4h | Cockpit + Intelipost + Painel | regra já possui 48h |
| 4 | Pedido pago não integrado | TI | Jiane Rodrigues | E-commerce | tempo real; tratativa <=2h | Cockpit Protheus + Painel | definir `X min` da regra de detecção |
| 5 | Tracking falso | TI | Jiane Rodrigues | Logística, E-commerce | correção antes da comunicação; <=4h | Mensageria/Cockpit + Intelipost + Painel | modelar validação físico x sistêmico |
| 6 | ERP indisponível/travado no pico | TI | Jiane Rodrigues | Logística, Comercial | continuidade <=30min; pós-mortem <=48h | Monitoramento TI + comunicação | integrar semanticamente ao incident-log-pro |
| 7 | Divergência saldo físico x virtual | Logística | Daniel Garcia | TI, E-commerce | acerto <=24h; reprocesso no dia | WMS/Protheus + Cockpit + Painel | detecção é MIXED |
| 8 | Falha de NF-e / bloqueio fiscal | TI | Jiane Rodrigues | DAF | liberar NF <=4h; manter janela | Cockpit Protheus + Painel | corrigir material antigo que apontava DAF como dono |
| 9 | Ruptura de estoque curva A | PCP | Renato de Paulo | Logística, Comercial | reposição/realocação no dia | Protheus PCP + Painel | fonte do mínimo deve ser definida |
| 10 | Colapso fila picking/esteira | Logística | Daniel Garcia | Comercial | reforço imediato; normalizar no turno | Cockpit/Painel | definir limite de lead time/fila |
| 11 | Pico de volume acima da capacidade | Logística | Daniel Garcia | PCP, Comercial | plano de pico no dia | BI Protocolos + Cockpit | definir capacidade/limiar por safra |

## 8.1 Propostos P1-P4

A existência de quatro cenários propostos está documentada, porém o conteúdo final não aparece na Matriz v3.

Portanto:

```text
P1-P4 = NÃO PUBLICAR COMO VALIDADO
```

Devem entrar apenas quando houver fonte formal suficiente.

---

# 9. Pendências humanas que bloqueiam regra definitiva

Criar registros `WAITING_HUMAN_DECISION` para:

1. lista dos quatro cenários `CRITICAL`;
2. limiar `X h` do cenário 2;
3. limiar `X min` do cenário 4;
4. limite de lead time/fila do cenário 10;
5. capacidade/limiar do cenário 11;
6. origem oficial do mínimo da curva A do cenário 9;
7. regra de múltiplas tratativas simultâneas do mesmo cenário;
8. política de fechamento com passos incompletos ou `NOT_APPLICABLE`;
9. papéis exatos e delegação de atualização;
10. provedor de identidade e método de autenticação corporativa;
11. service class do Framework EBSA;
12. RTO e RPO aprovados;
13. `replica_enabled`;
14. provedor/canal de e-mail/notificação;
15. quem participa da aprovação formal de novos cenários;
16. retenção do histórico;
17. janela oficial do ritual semanal;
18. definição de impacto quantitativo quando aplicável.

Nenhuma dessas decisões deve ser preenchida por suposição da LLM.

---

# 10. Contratos de regras de negócio

Cada regra deve possuir `rule_id`, versão, fonte, owner, exemplos positivos/negativos e testes.

## RB-SAFRA-001 - Cenário validado

Somente cenário `VALIDATED/PUBLISHED` pode originar tratativa real.

## RB-SAFRA-002 - Ativação humana

Nenhum sinal externo cria automaticamente `treatments` no MVP.

## RB-SAFRA-003 - Autorização para START

Somente owner autorizado do cenário pode iniciar.

## RB-SAFRA-004 - Autorização para END

Somente owner autorizado pode resolver ou cancelar.

## RB-SAFRA-005 - Atualizadores delegados

Usuário designado pode atualizar andamento, passos e notas, mas não adquire automaticamente START/END.

## RB-SAFRA-006 - Cancelamento auditável

Tratativa incorreta é `CANCELLED`; exclusão física é proibida no fluxo normal.

## RB-SAFRA-007 - Versão congelada

Ao abrir uma tratativa, salvar `scenario_version_id` e não recalcular histórico contra versão futura.

## RB-SAFRA-008 - Área impactada real

A ocorrência possui conjunto próprio de áreas impactadas.

## RB-SAFRA-009 - Criticidade e notificação

- `CRITICAL`: comunicar diretoria conforme política aprovada;
- `HIGH`/`MODERATE`: comunicar gestão/áreas impactadas conforme política aprovada.

## RB-SAFRA-010 - Protocolo não é chamado

A ferramenta não deve exigir workflow de atendimento técnico para cada protocolo.

## RB-SAFRA-011 - Escalonamento separado

Comitê técnico/negócio/executivo é relação da tratativa, não substitui seu status.

## RB-SAFRA-012 - SLA múltiplo

Cada SLA é calculado de eventos definidos; não armazenar duração como fonte primária quando puder ser derivada.

## RB-SAFRA-013 - Fonte sem integração

Ausência de fonte real nunca aparece como verde/OK automático.

Usar estado explícito:

```text
NO_SOURCE
WAITING_INTEGRATION
STALE_DATA
UNKNOWN
```

## RB-SAFRA-014 - Novo cenário

Proposta precisa de revisão e aprovação antes de publicação.

## RB-SAFRA-015 - Recorrência

Recorrência é métrica; não promove automaticamente o nível de crise.

## RB-SAFRA-016 - Integridade temporal

Eventos não podem violar sequência temporal sem justificativa administrativa auditada.

## RB-SAFRA-017 - Idempotência

Duplo clique, retry ou refresh não pode duplicar abertura, conclusão de passo, encerramento ou e-mail.

---

# 11. EIXO 1 - COMEÇO

## Objetivo do eixo

Responder corretamente:

> **"Temos condições de abrir este protocolo, quem pode fazê-lo, com qual versão, qual escopo e quais compromissos?"**

O COMEÇO inclui a fundação técnica porque uma abertura incorreta ou não autorizada contamina todo o histórico.

---

## SAFRA-C00 - Congelar baseline e conter riscos P0 — CONCLUÍDO EM 24/09/2026

### Objetivo

Criar uma linha de base segura antes de qualquer expansão funcional.

### Ações

1. registrar commit baseline;
2. registrar schema atual;
3. documentar rotas atuais;
4. inventariar migrations;
5. inventariar acesso Supabase;
6. remover `.env` do tracking em novo commit;
7. adicionar `.env`, `.env.*` sensíveis ao `.gitignore` preservando `.env.example`;
8. identificar secrets possivelmente expostos;
9. rotacionar secrets aplicáveis fora do GitHub;
10. revisar grants atuais;
11. remover CRUD indiscriminado de `anon`;
12. substituir `USING (true)` por policies reais;
13. testar acesso direto à API como usuário não autorizado;
14. preservar histórico Git sem force push.

### Evidências

- commit de contenção;
- matriz de grants antes/depois;
- teste negativo de acesso;
- checklist de rotação de secret;
- `docs/STATUS.md`.

### Gate EBSA

Status de fechamento do SAFRA-C00:

- **I-1 / SEC-001 — FECHADO**;
- **I0 / G0 — FECHADO**;
- **G2 / G3 — FECHADO no escopo C00**;
- **G5 — FECHADO PARCIALMENTE no escopo P0**.

O G5 completo permanece aberto para SAFRA-C04/C05, onde serão tratados identidade, RBAC definitivo, ownership, autorização por cenário e governança de migrations. Isso não constitui bloqueador P0 para continuidade da reformulação.

### Saída

**Gate atingido em 24/09/2026.**

Nenhum bloqueador P0 conhecido permanece aberto para continuar a reformulação.

Evidências canônicas: `docs/STATUS.md`, seção **Fechamento formal dos gates I-1 / I0 / G2 / G5 parcial**.

---

## SAFRA-C01 - Documentação canônica e PROJECT_PROFILE — EM ANDAMENTO

### Objetivo

Evitar que decisões fiquem espalhadas entre README, prompts e materiais da Pragmatis.

### Estrutura canônica

Criados/consolidados:

```text
docs/ROADMAP.md
docs/STATUS.md
docs/ARQUITETURA.md
docs/PROJECT_PROFILE.yaml
docs/PRIVACIDADE_THREAT_MODEL.md
docs/REGRAS_NEGOCIO.md
docs/MATRIZ_PARIDADE.md
docs/DECISOES.md
```

Pastas reservadas para próximas etapas:

```text
docs/adr/
docs/evidence/
docs/data-contracts/
docs/data-releases/
```

Não criar documentação paralela quando um destes arquivos já for a autoridade adequada.

### Registrar no perfil

- classe de serviço;
- criticidade da aplicação;
- auth;
- papéis privilegiados;
- dados pessoais de identidade;
- integrações;
- replica;
- arquivos;
- API pública;
- decisão automatizada;
- regras de domínio.

### Não concluir

Enquanto houver `UNKNOWN` material.

### Gate EBSA

- G3;
- G3.25.

---

## SAFRA-C02 - Threat model e abuso de negócio

### Ameaças específicas

- usuário comum abre protocolo crítico;
- usuário encerra protocolo alheio;
- alteração retroativa de owner;
- alteração de passos de protocolo muda histórico antigo;
- update direto via API ignora UI;
- cancelamento sem justificativa;
- adulteração de timestamps;
- alteração de criticidade para evitar notificação;
- inclusão indevida de diretoria/área impactada;
- enumeração de dados por usuário fora da área;
- vazamento de e-mails internos;
- duplicação por retry;
- operador fecha protocolo para "parar SLA";
- edição de cenário validado sem nova versão.

### Controles

- RLS;
- autorização server-side;
- scenario versioning;
- audit trail append-only;
- constraints;
- role mapping;
- event correlation;
- revisão administrativa.

### Gate EBSA

- G3.5;
- THREAT-001;
- AUTHZ-001.

---

## SAFRA-C03 - Glossário e modelo de domínio

### Termos canônicos

Definir formalmente:

- cenário;
- gatilho;
- detecção;
- acionamento;
- protocolo;
- tratativa;
- passo/marco;
- dono;
- área responsável;
- área impactada;
- SLA;
- criticidade;
- chamado;
- comitê técnico;
- comitê de negócio;
- diretoria;
- recorrência;
- cancelamento;
- pós-mortem.

### Decisão

`Geral` não é área operacional; é visão agregada.

### Entrega

`docs/GLOSSARIO_DOMINIO.md`.

---

## SAFRA-C04 - Identidade, RBAC e RLS

### Papéis funcionais sugeridos

```text
safra_admin
scenario_owner
scenario_updater
manager_viewer
executive_viewer
viewer
```

Os papéis não substituem vínculos por cenário.

### Modelo

```text
user
  -> membership
      -> operational_area
      -> role

scenario
  -> scenario_owner
      -> user
```

### Matriz inicial

| Ação | Admin | Owner | Updater | Gestor | Diretoria | Viewer |
|---|---:|---:|---:|---:|---:|---:|
| ver painel geral | sim | sim | sim | sim | sim | sim |
| abrir protocolo próprio | admin controlado | sim | não | não | não | não |
| atualizar protocolo autorizado | sim | sim | sim | leitura | leitura | leitura |
| encerrar | admin controlado | sim | não | não | não | não |
| cancelar | admin/owner | sim | não | não | não | não |
| editar cenário | admin/governança | não direto | não | não | não | não |
| aprovar proposta | governança | conforme owner | não | conforme processo | não | não |

### Testes obrigatórios

- owner A não abre cenário B sem vínculo;
- usuário sem autoridade de owner não encerra;
- viewer não escreve por REST direto;
- anon não lê/escreve dados internos;
- role alterada revoga imediatamente permissão crítica;
- sessão expirada não executa efeito.

### Gate EBSA

- G5;
- ID-001;
- ID-002;
- AUDIT-001.

---

## SAFRA-C05 - Schema v2 e migrations

### Estratégia

Adicionar domínio Safra sem breaking change imediato em `applications`/`incidents`.

### Ordem de migration

1. áreas;
2. systems;
3. scenarios;
4. scenario_versions;
5. scenario_owners;
6. scenario_impacted_areas;
7. scenario_systems;
8. scenario_slas;
9. protocol_step_definitions;
10. treatments;
11. treatment_impacted_areas;
12. treatment_steps;
13. treatment_events;
14. treatment_escalations;
15. notifications_log;
16. scenario_proposals;
17. governance_issues;
18. mappings para incidentes TI quando aplicável.

### Requisitos

- FK explícita;
- índices para filas ativas;
- constraints de enum/status;
- timestamps server-side;
- trigger de `updated_at`;
- auditoria;
- sem cascade delete destrutivo em histórico operacional;
- migration reversível ou rollback documentado.

### Testes

- migration em banco descartável;
- migration repetida não deve causar estado inconsistente;
- constraints positivas/negativas;
- rollback ensaiado.

### Gate EBSA

- G5;
- G6 parcialmente.

---

## SAFRA-C06 - Seed canônico da Matriz v3

### Objetivo

Migrar os 11 cenários sem redigitação manual.

### Processo

```text
XLSX v3
 -> parser versionado
 -> staging
 -> validação de completude
 -> preview diff
 -> aprovação humana
 -> seed/migration
 -> reconciliação
```

### Validações

- 11 cenários;
- 5 passos onde existirem 5;
- owner conforme v3;
- área responsável;
- áreas impactadas;
- SLA textual preservado;
- sistemas/ferramentas;
- EDB05/EDB06;
- participantes;
- nenhum P1-P4 publicado por inferência.

### Tratamento de campos abertos

`X h`, `X min`, limites não fechados -> `governance_issues`.

### Critério de saída

Reconciliação 100% entre XLSX v3 e banco para campos importados.

---

## SAFRA-C07 - Engine de SLA

### Problema atual

`cenarios.sla_horas` não comporta cenários com múltiplos compromissos.

### Solução

Usar `scenario_slas`.

### Eventos temporais possíveis

```text
TREATMENT_OPENED
STEP_X_COMPLETED
CONTINUITY_STARTED
SERVICE_RESTORED
PARTNER_RETURNED
TREATMENT_RESOLVED
POSTMORTEM_COMPLETED
```

### Cálculo

Duração sempre derivada de timestamps.

### Regras

- não salvar minutos como fonte primária;
- salvar timestamps e definição de SLA;
- sinalizar SLA ainda não mensurável;
- timezone padronizado;
- não permitir relógio negativo;
- tolerância temporal somente se documentada.

### Testes

- borda exata do SLA;
- horário de verão/timezone;
- evento ausente;
- passo NA;
- encerramento após breach;
- cenário com dois SLAs.

---

## SAFRA-C08 - UX do começo

### Telas

1. Visão Geral;
2. Minha Área;
3. Catálogo de Cenários;
4. Detalhe do Cenário;
5. Abrir Protocolo;
6. Administração/Governança.

### Fluxo de START

```text
selecionar cenário
 -> confirmar contexto
 -> informar escopo/impacto
 -> selecionar áreas realmente impactadas
 -> revisar criticidade vigente
 -> mostrar owner e versão
 -> confirmar "Ativar protocolo"
 -> backend autoriza
 -> criar tratamento e evento
 -> iniciar relógios
 -> disparar comunicações aplicáveis
```

### Guardrails UX

- explicar "protocolo não é chamado";
- confirmação explícita;
- owner visível;
- mostrar fonte/gatilho;
- não permitir cenário proposto;
- não mostrar verde para cenário sem fonte;
- ações destrutivas com confirmação;
- acessibilidade WCAG 2.2 AA;
- alvo touch preferencial >=44x44 onde prático.

### Gate EBSA

- G4;
- G4.5.

---

## SAFRA-C09 - Fundação operacional antes do MVP real

### Definir

- service class;
- SLO;
- RTO;
- RPO;
- backup;
- restore;
- pico esperado de usuários;
- capacidade sustentável;
- observabilidade.

### Importante

A Safra tem período de pico. Testar justamente o cenário de pico esperado.

### Framework

Baseline EBSA: capacidade sustentável >= 2x pico esperado, salvo decisão justificada.

### Evidências

- restore test;
- resultado de carga;
- smoke de autenticação;
- logs sem secrets.

### Gate

- G5.5.

---

# 12. EIXO 2 - MEIO

## Objetivo do eixo

Responder corretamente:

> **"O protocolo está ativo. Onde ele está, quem atualizou, quais SLAs estão correndo e precisamos escalar?"**

---

## SAFRA-M01 - State machine da tratativa

### Estados mínimos

```text
ACTIVE
RESOLVED
CANCELLED
```

### Por que não criar dezenas de statuses

A etapa atual do protocolo deve ser derivada de `treatment_steps`, e o escalonamento deve viver em estrutura própria.

Evitar:

```text
ACTIVE_TECHNICAL_CRISIS_STEP_3_OVERDUE
```

Preferir composição:

```text
status = ACTIVE
current_step = 3
sla_state = BREACHED
escalation = TECHNICAL_CRISIS
```

### Regras de transição

- `ACTIVE -> RESOLVED` por owner;
- `ACTIVE -> CANCELLED` por owner/admin com justificativa;
- `RESOLVED` não volta silenciosamente a ACTIVE;
- reabertura, se necessária, deve gerar evento e política formal.

---

## SAFRA-M02 - Persistência dos passos

### Cada passo precisa registrar

- status;
- usuário;
- instante;
- nota;
- evidência opcional futura;
- mudança anterior no audit trail.

### Concorrência

Dois usuários podem atualizar simultaneamente.

Implementar:

- optimistic concurrency ou versão;
- tratamento de conflito;
- refetch após mutation;
- idempotência.

### Critério

Refresh/troca de computador não perde andamento.

---

## SAFRA-M03 - Timeline operacional

### Timeline deve unir

- abertura;
- passos;
- notas;
- mudança de área impactada;
- notificações;
- SLA breach;
- escalonamento;
- encerramento/cancelamento.

### Objetivo

Uma pessoa que entra no meio da crise deve entender rapidamente:

- o que aconteceu;
- desde quando;
- qual cenário;
- qual owner;
- quem foi impactado;
- o que já foi feito;
- o que falta;
- qual SLA está vencendo/vencido;
- se existe comitê de crise.

---

## SAFRA-M04 - Engine de SLA em tempo real

### Exibir

- tempo decorrido;
- prazo alvo;
- tempo restante;
- estado;
- breach timestamp;
- múltiplos SLAs por cenário.

### Estados visuais

```text
ON_TRACK
AT_RISK
BREACHED
COMPLETED_ON_TIME
COMPLETED_LATE
NOT_APPLICABLE
```

`AT_RISK` exige regra definida, não percentual inventado.

Se não houver regra aprovada:

```text
AT_RISK = NÃO IMPLEMENTAR
```

---

## SAFRA-M05 - Notificações

### Criticidade

```text
CRITICAL
 -> política de comunicação imediata à diretoria

HIGH / MODERATE
 -> comunicação de gestão e áreas impactadas conforme política
```

### Requisitos

- envio server-side;
- log de entrega;
- retry controlado;
- idempotência;
- destinatário derivado de cadastro, não hardcoded no frontend;
- template versionado;
- não incluir dado além do necessário.

### Tipos

- protocolo aberto;
- SLA próximo do limite, se aprovado;
- SLA vencido;
- mudança de escalonamento;
- protocolo encerrado;
- digest periódico.

### Pendência

Definir os quatro cenários críticos antes de ativar regra produtiva.

---

## SAFRA-M06 - Comitê de crise e escalonamento

### Níveis

```text
NONE
TECHNICAL_CRISIS
BUSINESS_CRISIS
EXECUTIVE
```

### Exemplo conceitual

Integração GoDeep-Protheus parada:

1. protocolo é aberto;
2. equipe técnica investiga;
3. se contingência mantém cliente protegido, pode permanecer técnica;
4. se correção exige parada de Protheus ou decisão entre áreas, escalar para negócio;
5. diretoria é informada/acionada conforme criticidade e necessidade.

### Registro

- motivo;
- quem escalou;
- quando;
- participantes/áreas;
- decisão;
- encerramento do comitê.

### Não automatizar

Quantidade de protocolos não deve por si só promover `EXECUTIVE`.

---

## SAFRA-M07 - Ponte com incidents de TI

### Objetivo

Aproveitar o que funciona sem confundir incidente e protocolo.

### Modelo recomendado

`treatments.related_incident_id` nullable ou tabela N:N se surgir necessidade real.

### Cenário 6

Pode referenciar incidente Protheus real.

### Regras

- incidente pode existir sem protocolo;
- protocolo pode existir sem incidente;
- um incidente elegível pode sugerir cenário;
- MVP não cria protocolo automaticamente;
- MTTD/MTTR/MTBF continuam indicadores de TI;
- duração do protocolo é métrica diferente.

---

## SAFRA-M08 - Visão Geral / Torre de Controle

### Cards prioritários

- protocolos ativos agora;
- críticos ativos;
- SLAs vencidos;
- áreas impactadas;
- protocolos por área;
- protocolos por cenário;
- tempo do protocolo mais antigo;
- escalonamentos ativos.

### Lista operacional

Para cada protocolo:

- cenário;
- criticidade;
- owner;
- área responsável;
- áreas impactadas;
- passo atual;
- SLAs;
- tempo ativo;
- escalonamento.

### TV Mode

Criar modo de alta legibilidade:

- atualização automática segura;
- sem botões de edição;
- sem dados pessoais desnecessários;
- contraste alto;
- legível a distância;
- resumo de contingências ativas.

---

## SAFRA-M09 - Visão por área

### Cada área deve enxergar

- cenários sob sua responsabilidade;
- protocolos ativos;
- protocolos que a impactam;
- SLAs;
- histórico recente;
- recorrência;
- pendências de governança.

### RLS

Visibilidade pode ser ampla se a política do negócio assim definir, mas permissão de escrita permanece restrita.

---

## SAFRA-M10 - Governança de novos cenários

### Tela de proposta

Campos mínimos:

- nome;
- problema/risco;
- gatilho;
- detecção;
- área responsável;
- owner candidato;
- áreas impactadas;
- criticidade;
- SLA;
- ferramentas;
- passos;
- justificativa;
- exemplos.

### Workflow

```text
DRAFT
 -> SUBMITTED
 -> UNDER_REVIEW
 -> APPROVED
 -> PUBLISHED
```

ou

```text
UNDER_REVIEW -> REJECTED
```

### Regra

Aprovação não altera um cenário publicado sem criar nova versão.

---

## SAFRA-M11 - Fontes reais futuras

### MVP

Sem integração obrigatória.

### Pós-MVP

Criar um adapter por fonte, com contrato e DATA_RELEASE próprios.

Possíveis fontes:

- Intelipost;
- Protheus;
- Cockpit;
- WMS;
- GoDeep;
- Mensageria;
- monitoramento de TI;
- eventualmente OTRS.

### Pipeline padrão

```text
SOURCE
 -> EXTRACT / RECEIVE
 -> VALIDATE
 -> NORMALIZE
 -> STORE OBSERVATION
 -> EVALUATE RULE
 -> SIGNAL
 -> HUMAN CONFIRMATION
 -> TREATMENT
```

### Regra crítica

`SIGNAL` não é `TREATMENT`.

### Framework

Para cada fonte:

- contrato G6;
- regra G6.5;
- DATA_RELEASE;
- timeout/retry;
- idempotência;
- observabilidade;
- testes de falha.

---

# 13. EIXO 3 - FIM

## Objetivo do eixo

Responder corretamente:

> **"A contingência terminou. O que foi feito, qual foi o resultado, cumprimos o prazo e o que precisa mudar para a próxima ocorrência?"**

---

## SAFRA-F01 - Encerramento formal

### Owner deve informar

- resultado;
- resumo da contingência aplicada;
- impacto final;
- observação final;
- áreas efetivamente impactadas confirmadas;
- motivo de passos `NOT_APPLICABLE`, se necessário;
- classificação final quando houver correção autorizada.

### Backend grava

- `closed_by`;
- `closed_at`;
- durações deriváveis;
- evento `TREATMENT_RESOLVED`.

### Regra

Cliente não calcula timestamp oficial de fechamento sozinho.

---

## SAFRA-F02 - Cancelamento

### Usar quando

- protocolo aberto por engano;
- chamado confundido com protocolo;
- cenário incorreto;
- duplicidade.

### Obrigatório

- justificativa;
- ator;
- instante;
- referência ao correto, se houver.

### Nunca

Excluir silenciosamente para "limpar histórico".

---

## SAFRA-F03 - Pós-mortem e causa-raiz

Nem todo protocolo exige o mesmo pós-mortem.

### Suportar

- pós-mortem obrigatório por cenário;
- pós-mortem por criticidade;
- data limite;
- owner;
- conclusão;
- ação preventiva.

### Cenário 6

A Matriz v3 já prevê pós-mortem <=48h.

Portanto ele deve ser modelado como SLA adicional, não nota livre.

---

## SAFRA-F04 - Métricas históricas

### Indicadores corporativos

- protocolos abertos;
- protocolos encerrados;
- cancelados;
- tempo médio/mediano de protocolo;
- p90 de duração;
- cumprimento de SLA;
- breaches por cenário;
- recorrência por cenário;
- duração acumulada por cenário;
- tempo acumulado de impacto;
- escalonamentos técnicos;
- escalonamentos de negócio;
- críticos no período;
- áreas mais impactadas;
- protocolos simultâneos;
- taxa de reabertura, se existir;
- pós-mortem concluído no prazo.

### Evitar

Usar apenas média quando distribuição for assimétrica.

### Indicadores de TI preservados

- MTTD;
- MTTR;
- MTBF;
- disponibilidade.

Eles pertencem à camada de confiabilidade de TI e não substituem indicadores Safra.

---

## SAFRA-F05 - Recorrência e ritual semanal

### Tela "Governança Semanal"

Mostrar:

- cenários repetidos;
- duração acumulada;
- SLA breach repetido;
- causas-raiz recorrentes;
- ações pendentes;
- owners;
- tendência;
- protocolos críticos da semana;
- protocolos ainda ativos.

### Regra

A ferramenta suporta decisão humana; não declara crise automaticamente por recorrência.

### Saída

Registrar ação de governança:

```text
PROCESS_CHANGE
MASTER_DATA_FIX
CAPACITY_CHANGE
PARTNER_ACTION
SYSTEM_CHANGE
TRAINING
NO_ACTION_JUSTIFIED
```

---

## SAFRA-F06 - Relatório executivo

### Períodos

- dia;
- semana;
- safra acumulada;
- intervalo customizado.

### Conteúdo

- total de protocolos;
- cenário;
- área;
- criticidade;
- duração;
- SLA;
- impacto;
- escalonamento;
- recorrência;
- ações de governança.

### Princípio

O relatório histórico não substitui a Torre de Controle em tempo real.

---

## SAFRA-F07 - Homologação com o negócio

### Validadores

Donos e participantes indicados nas fontes de validação, além dos responsáveis de governança definidos pelo projeto.

### Roteiro por cenário

Para cada um dos 11:

1. cenário aparece correto;
2. owner correto;
3. área responsável correta;
4. áreas impactáveis corretas;
5. passos corretos;
6. SLA correto;
7. ferramenta/origem correta;
8. opening permission correta;
9. notificações corretas;
10. fechamento correto;
11. histórico correto.

### Evidência

Checklist assinado/registrado por cenário.

### Gate EBSA

- G10.

---

## SAFRA-F08 - Auditoria E2E pré-release

### Segurança

- anon bloqueado;
- RLS positive/negative;
- owner isolation;
- scenario_owner restrictions;
- admin restrictions;
- secrets;
- dependencies;
- API direto.

### Integridade

- dupla abertura;
- double submit;
- timestamps;
- version freeze;
- passos;
- cancellation;
- notification idempotency.

### UX

- desktop;
- notebook;
- tablet;
- celular;
- TV mode;
- teclado;
- foco;
- contraste;
- erros;
- reflow 320 CSS px.

### Operação

- load;
- stress;
- spike;
- restore;
- SLO/RTO/RPO;
- logs;
- alertas.

### Gate EBSA

- G7;
- G8;
- G10.5.

---

## SAFRA-F09 - Release e operação

### Antes da abertura geral

- business acceptance;
- auditoria sem bloqueador crítico;
- RELEASE_APPROVAL;
- DATA_RELEASE válido para cada fluxo real;
- runbook;
- owners operacionais;
- rollback;
- suporte;
- monitoramento do próprio Painel.

### Operação

- revisar acessos;
- revisar cenários;
- revisar owners;
- revisar SLA;
- renovar testes de recuperação;
- acompanhar capacidade durante Safra;
- reabrir gates quando houver mudança material.

### Gate

- G11.

---

# 14. Jornada E2E de referência

## 14.1 COMEÇO

```text
1. Operador identifica ocorrência em ferramenta/processo.
2. Consulta catálogo Safra.
3. Identifica cenário compatível.
4. Sistema mostra gatilho, owner, protocolo, SLA e impacto esperado.
5. Owner entra autenticado.
6. Owner informa escopo e áreas impactadas reais.
7. Backend valida owner + cenário publicado + versão vigente.
8. Owner confirma abertura.
9. Backend cria treatment e snapshot/version binding.
10. Evento TREATMENT_OPENED é gravado.
11. SLAs iniciam.
12. Notificações aplicáveis são enfileiradas.
```

## 14.2 MEIO

```text
13. Painel mostra protocolo ativo.
14. Owner autorizado atualiza passos.
15. Cada alteração cria audit event.
16. Relógios são recalculados por timestamps.
17. Áreas impactadas acompanham.
18. Se necessário, owner escala para comitê técnico.
19. Se decisão de negócio for necessária, escala para BUSINESS_CRISIS.
20. Notificações e timeline registram o avanço.
```

## 14.3 FIM

```text
21. Owner confirma normalização/encerramento.
22. Informa resultado e contingência aplicada.
23. Backend encerra treatment.
24. SLAs são fechados.
25. Evento final é gravado.
26. Caso necessário, pós-mortem permanece pendente com SLA próprio.
27. Métricas históricas são atualizadas.
28. Recorrência alimenta ritual semanal.
29. Ações de melhoria são registradas.
```

---

# 15. Matriz de testes de negócio

## 15.1 Abertura

- cenário proposto não abre;
- cenário inativo não abre;
- usuário comum não abre;
- owner correto abre;
- owner de outro cenário não abre;
- duplo clique não duplica;
- refresh após start preserva relógio;
- cenário sem criticality aprovada não ativa notificação incorreta.

## 15.2 Passos

- scenario_owner autorizado conclui;
- usuário sem permissão não conclui;
- concorrência não perde evento;
- passo NA exige política;
- alteração de definição futura não muda passo histórico.

## 15.3 SLA

- dois SLAs simultâneos;
- boundary exato;
- breach;
- cancelamento;
- encerramento tardio;
- pós-mortem 48h;
- dados incompletos.

## 15.4 Escalonamento

- técnico;
- negócio;
- executivo;
- downgrade/fechamento auditado;
- quantidade de ocorrências não escala automaticamente.

## 15.5 Encerramento

- usuário sem autoridade de owner não encerra;
- owner encerra;
- close idempotente;
- cancelamento com razão;
- sem delete físico.

## 15.6 RLS

Testar acesso pelo cliente e acesso REST direto.

---

# 16. Observabilidade do próprio Painel Safra

Não confundir observabilidade do Painel com observabilidade das ferramentas de negócio.

Monitorar:

- erros de login;
- falhas de mutation;
- falhas de notificação;
- latência;
- erro de query;
- RLS denial anômalo;
- duplicate request;
- jobs pendentes;
- tempo de página crítica;
- disponibilidade do próprio Painel.

Não registrar secrets nem payloads excessivos.

---

# 17. Estratégia de dados reais

## 17.1 Dados já existentes

Incidentes TI existentes devem passar por revisão de contrato/segurança antes de ampliar consumo.

## 17.2 Novas fontes

Cada fonte futura terá:

```text
SOURCE_CONTRACT
QUALITY_RULES
OWNERS
FAILURE_MODE
RETRY_POLICY
IDEMPOTENCY
DATA_RELEASE
ROLLBACK
OBSERVABILITY
```

## 17.3 Sem fonte real

Cenário continua utilizável como protocolo manual, mas a interface deve diferenciar:

```text
MANUAL_PROTOCOL
WAITING_INTEGRATION
REAL_SIGNAL_CONNECTED
```

Nunca gerar gráfico fictício para preencher espaço.

---

# 18. Arquitetura lógica recomendada

```text
[Browser / TV]
      |
      v
[TanStack / React]
      |
      v
[Supabase client/API]
      |
      +--> [Auth]
      |
      +--> [RLS / Policies]
      |
      +--> [Postgres]
      |       +-- catálogo Safra
      |       +-- treatments
      |       +-- audit events
      |       +-- scenario versions
      |
      +--> [RPC / DB functions]
      |       +-- start_treatment
      |       +-- close_treatment
      |       +-- cancel_treatment
      |       +-- change_escalation
      |
      +--> [Server-side notification adapter]

FUTURO:
[External sources]
      -> adapters
      -> normalized signals
      -> rule evaluation
      -> human confirmation
```

## 18.1 Autoridade

Operações críticas não devem ser montadas apenas com `.insert()` genérico no browser.

Preferir funções/RPC transacionais para:

- abrir;
- encerrar;
- cancelar;
- promover versão;
- mudar escalonamento.

Porque essas operações precisam combinar autorização + integridade + audit event de forma atômica.

---

# 19. Roadmap por ordem de execução

## Bloco 0 - Parar de ampliar a base insegura

1. SAFRA-C00 - baseline e P0 security.
2. SAFRA-C01 - documentação e profile.
3. SAFRA-C02 - threat model.

## Bloco 1 - Refazer o domínio

4. SAFRA-C03 - glossário.
5. SAFRA-C04 - identity/RBAC/RLS.
6. SAFRA-C05 - schema v2.
7. SAFRA-C06 - seed da Matriz v3.
8. SAFRA-C07 - SLA engine.

## Bloco 2 - Construir COMEÇO completo

9. SAFRA-C08 - UX de catálogo/start.
10. SAFRA-C09 - foundation/restore/capacity.

## Bloco 3 - Construir MEIO completo

11. SAFRA-M01 - state machine.
12. SAFRA-M02 - persistent steps.
13. SAFRA-M03 - timeline.
14. SAFRA-M04 - SLA runtime.
15. SAFRA-M05 - notifications.
16. SAFRA-M06 - crisis escalation.
17. SAFRA-M07 - bridge TI incidents.
18. SAFRA-M08 - control tower.
19. SAFRA-M09 - area views.
20. SAFRA-M10 - scenario governance.

## Bloco 4 - Construir FIM completo

21. SAFRA-F01 - close.
22. SAFRA-F02 - cancel.
23. SAFRA-F03 - post-mortem.
24. SAFRA-F04 - analytics.
25. SAFRA-F05 - weekly governance.
26. SAFRA-F06 - executive report.

## Bloco 5 - Homologar e liberar

27. SAFRA-F07 - homologation.
28. SAFRA-F08 - E2E audit.
29. SAFRA-F09 - release/operation.

## Bloco 6 - Integrações reais por ciclo

30. SAFRA-M11 - uma fonte por vez.

Ordem sugerida de avaliação, não de execução automática:

```text
TI existente
 -> Protheus/Cockpit
 -> Intelipost
 -> WMS
 -> PCP/estoque
 -> outras fontes
 -> OTRS, apenas se ADR futuro aprovar
```

---

# 20. Gates de produto

## Gate P0 - SAFE TO REFACTOR

Só passa se:

- secrets tratados;
- anon não possui CRUD aberto;
- baseline documentado.

## Gate P1 - DOMAIN READY

Só passa se:

- schema aprovado;
- 11 cenários reconciliados;
- pending decisions catalogadas;
- roles definidas.

## Gate P2 - START READY

Só passa se:

- owner authorization funciona;
- start é transacional;
- version snapshot funciona;
- SLA inicia corretamente;
- audit event existe.

## Gate P3 - IN-FLIGHT READY

Só passa se:

- passos persistem;
- concorrência tratada;
- timeline confiável;
- SLA runtime correto;
- escalonamento auditável.

## Gate P4 - CLOSE READY

Só passa se:

- owner encerra;
- cancelamento funciona;
- histórico é imutável/auditável;
- métricas batem com timestamps.

## Gate P5 - BUSINESS READY

Só passa se:

- todos os 11 cenários homologados;
- criticidade aprovada;
- notificações aprovadas;
- diretoria/gestores validam visão.

## Gate P6 - RELEASE READY

Só passa se:

- G7/G10/G10.5 aplicáveis aprovados;
- restore comprovado;
- capacidade aceita;
- WCAG crítica sem bloqueador;
- RELEASE_APPROVAL.

---

# 21. Mapeamento Framework EBSA x Roadmap Safra

| Framework | Roadmap Safra | Observação |
|---|---|---|
| I-1 | C00/C02 | trust boundary e secrets |
| I0 | C00 | repo/branch/env |
| I0.5 | C01 | perfil candidato |
| G0 | C01 | intenção já conhecida, formalizar |
| G1 | C00/C01 | base já existe; revalidar, não recriar |
| G2 | C00/C01 | GitHub já existe; confirmar sync |
| G3 | C01 | documentação canônica |
| G3.25 | C01 | profile completo |
| G3.5 | C02 | threat/privacy |
| G4 | C08/M08/M09 | UX |
| G4.5 | C08 | frontend |
| G5 | C04/C05/M01-M07/F01-F03 | backend/security |
| G5.25 | C00/C01/F08 | governance/supply chain |
| G5.5 | C09 | capacity/recovery |
| G6 | C06/M11 | data contract |
| G6.5 | C07 + regras + M11 | business rules/DATA_RELEASE |
| G7 | F08 | integrated quality |
| G8 | F08 | candidate release |
| G9 | condicional | N/A se replica false |
| G10 | F07 | business homologation |
| G10.5 | F08 | final audit |
| G11 | F09 | operations |
| G12 | futuro | decommission |

---

# 22. Decisões ADR recomendadas

## ADR-001 - Evoluir incident-log-pro

Status: aprovado pelo contexto metodológico.

## ADR-002 - PRIMARY e REPLICA

Status: WAITING_HUMAN_DECISION.

## ADR-003 - Service class

Status: WAITING_HUMAN_DECISION.

Avaliar INTERNO x OPERACIONAL.

## ADR-004 - Identity provider

Status: **APROVADO em 24/09/2026**.

```text
identity_provider = MICROSOFT_ENTRA_ID
auth_method = CORPORATE_SSO
local_password_login = false
```

A autenticação corporativa identifica o usuário. Papéis e permissões Safra permanecem responsabilidade do SAFRA-C04.

## ADR-005 - Tratativas críticas via RPC transacional

Recomendação: aprovar.

## ADR-006 - Geral como visão, não área

Recomendação: aprovar.

## ADR-007 - Ativação manual no MVP

Status: decisão de negócio consolidada.

## ADR-008 - OTRS fora do MVP

Status: manter como hipótese futura sujeita a análise técnica/econômica.

## ADR-009 - Integrações uma por ciclo

Recomendação: aprovar.

---

# 23. Backlog explícito fora do MVP

Não incluir no MVP sem nova decisão:

- abertura automática por Intelipost;
- abertura automática por Protheus;
- abertura automática por OTRS;
- monitoramento universal;
- IA de causa raiz;
- ML de risco;
- WhatsApp/SMS/push;
- automação de remediação;
- criação automática de comitê de crise;
- decisão automática de criticidade;
- REPLICA sem ADR;
- data lake dedicado;
- event streaming complexo;
- integração ampla com Power BI como dependência do fluxo operacional.

---

# 24. Definição de pronto global

Uma funcionalidade Safra só é `DONE` quando:

1. regra possui fonte de negócio;
2. rule_id/version existe quando aplicável;
3. autorização está no backend/banco;
4. RLS foi testada positiva e negativamente;
5. migration está versionada;
6. rollback está documentado;
7. testes unitários/de integração cobrem bordas;
8. E2E cobre usuário permitido e negado;
9. audit trail existe para ação sensível;
10. idempotência existe onde duplicidade é perigosa;
11. UI trata loading/empty/error/forbidden;
12. acessibilidade crítica foi validada;
13. documentação foi atualizada;
14. evidência foi registrada;
15. homologação de negócio ocorreu quando regra mudou;
16. DATA_RELEASE existe antes de nova fonte real;
17. performance/capacidade foi reavaliada quando impacto material existir.

---

# 25. Documentação viva obrigatória

Após cada etapa concluída, atualizar pelo menos:

```text
docs/STATUS.md
docs/ROADMAP.md
docs/DECISOES.md
```

Quando afetado:

```text
docs/ARQUITETURA.md
docs/REGRAS_NEGOCIO.md
docs/PROJECT_PROFILE.yaml
docs/PRIVACIDADE_THREAT_MODEL.md
docs/MATRIZ_PARIDADE.md
docs/data-contracts/*
docs/data-releases/*
docs/adr/*
docs/evidence/*
```

A documentação não pode ficar para o fim do projeto.

---

# 26. Primeiro ciclo recomendado

Não iniciar redesign amplo de dashboard ainda.

O primeiro ciclo deve ser:

```text
SAFRA-C00
    -> P0 security
    -> baseline

SAFRA-C01
    -> docs
    -> PROJECT_PROFILE

SAFRA-C03/C04
    -> domínio
    -> papéis

SAFRA-C05
    -> schema novo

SAFRA-C06
    -> importar Matriz v3

SAFRA-C07
    -> SLA múltiplo

SAFRA-C08
    -> fluxo START
```

Somente depois construir o painel executivo completo.

---

# 27. Resultado esperado ao final dos três eixos

## COMEÇO concluído

O sistema sabe:

- quais cenários existem;
- qual versão está vigente;
- quem é o dono;
- quais áreas podem ser impactadas;
- quais sistemas participam;
- quais SLAs existem;
- quem pode abrir;
- como abrir com segurança.

## MEIO concluído

O sistema sabe:

- quais protocolos estão ativos;
- em qual passo estão;
- quem atualizou;
- quais SLAs correm;
- quais áreas estão impactadas;
- qual nível de escalonamento;
- quem precisa ser comunicado.

## FIM concluído

O sistema sabe:

- como cada contingência terminou;
- quanto durou;
- quais SLAs foram cumpridos;
- quais cenários se repetem;
- quanto impacto acumulado existe;
- quais ações de governança foram abertas;
- o que precisa ser revisto antes da próxima Safra.

---

# 28. Conclusão arquitetural

A reformulação deve conservar o valor do `incident-log-pro`, mas deixar de tratá-lo como modelo completo do produto.

A arquitetura correta é:

```text
incident-log-pro legado de TI
        +
novo domínio Safra versionado
        +
autorização real
        +
workflow COMEÇO / MEIO / FIM
        +
visibilidade executiva
        +
auditoria
        +
governança
```

A principal mudança de mentalidade é esta:

> **O Painel Safra não existe para executar o trabalho operacional de cada área. Ele existe para tornar uma contingência visível, governada, temporizada, auditável e aprendível.**

O Framework EBSA v1.7 é útil porque garante que essa lógica não seja implementada sobre uma base insegura ou sem evidência. Porém, a autoridade da regra de negócio permanece com a Matriz v3 e com as decisões humanas registradas na reunião.

---

# 29. Próximo passo operacional

Após aprovação deste roadmap:

1. substituir o roadmap anterior por este documento como canônico;
2. atualizar README apontando para `docs/ROADMAP.md`;
3. registrar `STATUS` com o estado atual;
4. iniciar `SAFRA-C00`;
5. não alterar ainda as regras do produto no Lovable por prompt;
6. fazer mudanças permanentes GitHub-first;
7. após cada etapa, atualizar documentação e evidências.
