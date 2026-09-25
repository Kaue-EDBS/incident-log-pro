# Roadmap de Reformulação — Painel Safra / incident-log-pro

**Versão:** 2.1  
**Data:** 24/09/2026  
**Status:** roadmap consolidado em execução — C00 e C01 concluídos; C02 em andamento  
**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Produto-alvo:** Painel Safra — Torre de Governança de Contingências  
**Regra de execução:** GitHub-first; não reescrever histórico publicado; documentação viva ao fim de cada etapa.

---

# 0. Resumo executivo

O `incident-log-pro` nasceu como um monitor de confiabilidade de aplicações de TI, centrado em `applications`, `incidents`, MTTD, MTTR, MTBF, downtime e disponibilidade. Esse núcleo permanece útil como legado técnico e referência temporal, mas não representa sozinho o domínio do Painel Safra.

O Painel Safra será uma **torre corporativa de governança de contingências**. O produto deve tornar uma contingência visível, temporizada, auditável, comunicável e analisável, sem substituir a execução operacional de cada área.

A lógica canônica é:

```text
OCORRÊNCIA / NECESSIDADE
    -> usuário identifica cenário aplicável
    -> START humano
    -> owner do card conduz o protocolo com sua equipe
    -> Painel registra tempo, estado, auditoria, comunicações e escalonamentos
    -> END ou CANCEL humano
    -> histórico, métricas e governança
```

## 0.1 Mudanças centrais da versão 2.1

1. **START / END / CANCEL não são exclusivos do owner.** Qualquer usuário autenticado pelo Microsoft Entra ID pode executar essas ações, com auditoria, idempotência e controles server-side.
2. **O Painel não acompanha checklist operacional passo a passo.** A execução do protocolo ocorre com o owner e sua equipe; o Painel governa o ciclo, os tempos, as comunicações, o histórico e o aprendizado.
3. **Papéis administrativos foram separados por responsabilidade**, sem herança automática de ownership.
4. **12º card é proposta de novo cenário**, com fluxo próprio de triagem e ownership; não é protocolo genérico.
5. **C00 e C01 estão concluídos.** C02 é a fase atual.
6. **C02 modela controles; não os implementa.** RLS, autorização server-side, versionamento, audit trail, constraints e role mapping são definidos como resposta às ameaças e implementados nas fases C04/C05 e seguintes.
7. **REPLICA está desabilitada**, sem eliminar backup/restore.
8. **Retenção, service class, application criticality e RTO/RPO estão decididos.**

---

# 1. Fontes de verdade e precedência

## 1.1 Fontes primárias de negócio

1. `EDB06 - Matriz Contingencia v3.xlsx`
2. `Painel SAFRA.docx` — reunião de 22/09/2026
3. `EDB06 - Protocolos de contingência v2.pdf`
4. decisões humanas posteriores formalizadas em `docs/DECISOES.md`

## 1.2 Fontes técnicas

- repositório `Kaue-EDBS/incident-log-pro`;
- estado live do Lovable Cloud PRIMARY quando validado;
- migrations e código versionados;
- documentação canônica em `docs/`.

## 1.3 Governança técnica

O Framework EBSA v1.7 governa segurança, gates, evidências, identidade, dados, testes, capacidade, recuperação e operação. Ele **não altera regra de negócio Safra**.

## 1.4 Precedência

```text
Matriz v3
    > decisão posterior explícita registrada
    > reunião 22/09
    > Protocolos v2
    > consolidação metodológica
    > implementação legada
```

Quando o Framework EBSA exigir um controle técnico, ele pode bloquear uma implementação insegura, mas não pode inventar uma regra de negócio.

---

# 2. Definição canônica do produto

## 2.1 O Painel Safra faz

- mantém catálogo dos cenários publicados;
- apresenta gatilho, owner, protocolo, criticidade, SLA e contexto;
- permite START manual por usuário autenticado;
- registra ator, data e hora oficiais;
- mantém vínculo imutável com a versão de cenário usada no START;
- mantém status da tratativa;
- mede tempos e SLAs a partir de eventos persistidos;
- envia comunicações operacionais aprovadas;
- registra escalonamentos;
- permite END e CANCEL auditáveis;
- preserva histórico;
- calcula indicadores e recorrência;
- apoia governança semanal e visão executiva;
- recebe proposta de novo cenário pelo 12º card.

## 2.2 O Painel Safra não faz no MVP

- não substitui OTRS;
- não vira sistema genérico de tickets;
- não executa passo a passo o protocolo de cada área;
- não exige checklist operacional para encerrar uma tratativa;
- não cria tratativa automaticamente a partir de integrações;
- não decide sozinho criticidade, crise ou owner;
- não executa remediação automática;
- não usa IA para decisão operacional automática;
- não depende de REPLICA;
- não depende de Power BI para o fluxo operacional.

## 2.3 Princípios de domínio

```text
DETECTION_MODE != ACTIVATION_MODE
PROPOSAL != PUBLISHED_SCENARIO
PROTOCOL != TICKET
SCENARIO_CRITICALITY != APPLICATION_CRITICALITY
REPLICA != BACKUP
AUTHENTICATION != AUTHORIZATION
```

---

# 3. Estado técnico consolidado

## 3.1 Stack

- React 19;
- TanStack Start / Router / Query;
- Vite;
- TypeScript;
- Tailwind;
- Recharts;
- Lovable Cloud como backend provider;
- PostgreSQL / Supabase como stack do banco;
- banco Lovable Cloud como `PRIMARY`;
- Supabase Auth/Data API;
- GitHub branch `main`.

## 3.2 Estado de segurança após C00

- `.env` fora do tracking;
- `anon` sem acesso às tabelas internas protegidas;
- RLS habilitada;
- policies permissivas antigas removidas;
- `service_role` não exposto no browser;
- contenção transitória por `app_metadata.safra_access=true`;
- RBAC definitivo ainda será implementado em C04.

## 3.3 Migration drift conhecido

A migration `20260924212155_harden_safra_c00_access.sql` representa o hardening aplicado, porém seu registro no histórico formal de migrations precisa ser reconciliado no C05.

---

# 4. PROJECT_PROFILE aprovado

```yaml
project_name: Painel Safra
project_type: internal_operational_control
exposure: internal
backend_provider: lovable_cloud
database_role: PRIMARY
database_engine: postgresql
database_stack: supabase
service_class: CRITICO
application_criticality: MEDIUM
slo: 99.95%
rto_minutes: 30
rpo_minutes: 5
replica_enabled: false
backup_restore_required: true
auth_required: true
identity_provider: MICROSOFT_ENTRA_ID
auth_method: CORPORATE_SSO
local_password_login: false
personal_data: true
sensitive_personal_data_intentional: false
children_or_adolescents_data: false
storage_files_currently_enabled: false
external_integrations_in_mvp: false
public_api: false
automated_decisioning: false
```

## 4.1 Retenção aprovada

- dados pessoais identificáveis: até o encerramento formal da Safra e enquanto necessários para auditoria/pós-mortem;
- depois: eliminar ou anonimizar;
- histórico operacional e métricas podem permanecer para comparação entre Safras sem identificação pessoal quando ela não for necessária.

## 4.2 REPLICA

```text
replica_enabled = false
```

Isso **não** significa ausência de backup. Recovery continua obrigatório e deve ser comprovado no C09.

---

# 5. Modelo de pessoas e responsabilidades

## 5.1 Usuário autenticado — capacidade base

Qualquer usuário autenticado pelo Microsoft Entra ID pode:

- visualizar os cards;
- executar START em cenário publicado;
- executar END em tratativa ativa;
- executar CANCEL com justificativa obrigatória;
- enviar proposta pelo 12º card.

Todas as ações críticas precisam ser auditáveis, idempotentes e validadas no backend.

## 5.2 `scenario_owner`

Responsável formal pelo card e pelo protocolo operacional com sua equipe.

Não possui exclusividade sobre START/END/CANCEL.

Owners atuais dos 11 cards:

- Daniel Garcia — 1, 2, 3, 7, 10, 11;
- Jiane Rodrigues — 4, 5, 6, 8;
- Renato de Paulo — 9.

## 5.3 `safra_platform_admin`

Administração técnica da plataforma.

Membros permanentes:

- Kaue Pastrello;
- Amanda Bueno;
- Vinicius Moraes;
- João Jurado.

Admin técnico não recebe ownership de cenário por herança.

## 5.4 `safra_governance_admin`

Governança funcional global.

Membro atual:

- Jair Silva.

Responsabilidades:

- supervisionar cards e governança;
- acessar relatórios de governança;
- conduzir o fluxo do 12º card;
- receber comunicações operacionais de governança;
- tomar decisões de ownership quando o fluxo exigir;
- não administrar tecnicamente a plataforma.

## 5.5 `safra_executive_admin`

Visão executiva e analytics.

Membro atual:

- Bruno Palhão.

Regras:

- visão de todos os cards e métricas;
- sem manutenção técnica;
- sem e-mails operacionais normais;
- pode ser acionado no fluxo excepcional do 12º card.

## 5.6 Princípio de papéis

```text
papel administrativo != ownership automático
ownership = vínculo explícito ao cenário
```

---

# 6. Decisões de negócio consolidadas

## D-01 — Evoluir o projeto existente

Não criar aplicação paralela.

## D-02 — Preservar domínio legado de TI

`applications/incidents` continuam representando confiabilidade de TI onde fizer sentido, sem serem forçados a representar todo o Safra.

## D-03 — Geral é visão, não área

`Geral` é agregação; não é entidade operacional.

## D-04 — Detecção e ativação são separadas

No MVP, integrações podem futuramente gerar sinal, mas não criam `treatment` automaticamente.

## D-05 — Protocolo não é chamado

O Painel governa contingência; não substitui sistemas de atendimento operacional.

## D-06 — START / END / CANCEL

- qualquer usuário autenticado pode START;
- qualquer usuário autenticado pode END;
- qualquer usuário autenticado pode CANCEL;
- CANCEL exige motivo;
- ator e timestamp são persistidos no backend;
- nenhuma ação crítica depende apenas do frontend.

## D-07 — Sem delete físico para “corrigir histórico”

Abertura errada vira `CANCELLED`.

## D-08 — Novo cenário exige governança

Proposta não vira cenário produtivo automaticamente.

## D-09 — Criticidade de cenário

Valores:

```text
CRITICAL
HIGH
MODERATE
```

A lista exata dos quatro cenários `CRITICAL` não possui evidência nominal suficiente nas fontes revisadas e está registrada como `GI-SAFRA-001` em `docs/GOVERNANCE_ISSUES.md`. Não inferir.

## D-10 — Recorrência não cria crise automaticamente

Recorrência é indicador; crise depende de avaliação humana e contexto.

## D-11 — Comitê é escalonamento

Escalonamento não substitui `status` da tratativa.

## D-12 — Sem checklist operacional no Painel

O protocolo é executado pelo owner com sua equipe. O Painel não exige controle passo a passo da execução.

---

# 7. Modelo de domínio alvo — v2.1

## 7.1 Catálogo

### `operational_areas`

```text
id
code
name
is_active
created_at
updated_at
```

### `systems`

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

Conteúdo mutável/versionado do cenário.

```text
id
scenario_id
version
trigger_description
detection_mode
activation_mode
criticality
protocol_text
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

### `scenario_owners`

```text
id
scenario_id
user_id
valid_from
valid_to
created_at
```

### `scenario_impacted_areas`

Relação N:N das áreas potencialmente impactadas.

### `scenario_systems`

Relação N:N entre cenário e sistemas.

### `scenario_slas`

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

## 7.2 Identidade e papéis

### `safra_user_roles`

[DERIVADO — desenho técnico a homologar em C04/C05]

```text
id
user_id
role
valid_from
valid_to
created_by
created_at
```

Roles previstos:

```text
safra_platform_admin
safra_governance_admin
safra_executive_admin
scenario_owner  # ownership também possui vínculo explícito em scenario_owners
```

## 7.3 Operação

### `treatments`

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

Estados mínimos:

```text
ACTIVE
RESOLVED
CANCELLED
```

### `treatment_impacted_areas`

Áreas efetivamente impactadas naquela ocorrência.

### `treatment_events`

Trilha append-only.

Eventos mínimos previstos:

```text
TREATMENT_OPENED
NOTE_ADDED
IMPACT_AREA_ADDED
IMPACT_AREA_REMOVED
ESCALATION_CHANGED
SLA_BREACHED
TREATMENT_RESOLVED
TREATMENT_CANCELLED
ADMIN_CORRECTION_RECORDED
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
created_at
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

```text
id
treatment_id
notification_type
recipient_id
recipient_email
correlation_id
status
provider_message_id
sent_at
error_code
created_at
```

## 7.4 Governança

### `scenario_proposals`

O 12º card cria proposta, não cenário produtivo.

Campos do formulário aprovado:

```text
id
submitted_by
submitted_name_snapshot
submitted_email_snapshot
title
problem_description
safra_impact_description
status
created_at
updated_at
```

### `scenario_proposal_owner_responses`

[DERIVADO — necessário para representar o fluxo aprovado]

```text
id
proposal_id
candidate_user_id
response  # ACCEPTED | DECLINED
responded_at
```

### `governance_issues`

Registra decisões abertas sem transformá-las em default.

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
created_at
updated_at
```

---

# 8. Baseline dos 11 cenários

A carga canônica virá da Matriz v3, sem redigitação manual.

| # | Cenário | Área | Owner | SLA resumido | Pendência material |
|---:|---|---|---|---|---|
| 1 | Insucesso de entrega | Logística | Daniel Garcia | falha <=2h; tratativa <=48h | nenhuma estrutural |
| 2 | Transportadora fora do ar | Logística | Daniel Garcia | plano B <=4h | definir `X h` |
| 3 | Atraso (+48h) sem causa | Logística | Daniel Garcia | retorno <=4h | regra de 48h já existe |
| 4 | Pedido pago não integrado | TI | Jiane Rodrigues | tratativa <=2h | definir `X min` |
| 5 | Tracking falso | TI | Jiane Rodrigues | correção <=4h | validação físico x sistêmico |
| 6 | ERP indisponível/travado | TI | Jiane Rodrigues | continuidade <=30min; pós-mortem <=48h | ponte semântica com incidents TI |
| 7 | Divergência saldo físico x virtual | Logística | Daniel Garcia | correção <=24h | detecção MIXED |
| 8 | Falha NF-e / bloqueio fiscal | TI | Jiane Rodrigues | liberação <=4h | preservar owner correto da Matriz v3 |
| 9 | Ruptura estoque curva A | PCP | Renato de Paulo | realocação no dia | fonte oficial do mínimo curva A |
| 10 | Colapso picking/esteira | Logística | Daniel Garcia | normalizar no turno | limite lead time/fila |
| 11 | Pico de volume > capacidade | Logística | Daniel Garcia | plano de pico no dia | capacidade/limiar |

Nenhum P1-P4 deve ser publicado por inferência.

---

# 9. Dívida de decisão — com fase responsável

Nada nesta seção deve voltar a aparecer como `UNKNOWN` genérico.

| Decisão | Estado | Fase responsável |
|---|---|---|
| quatro cenários CRITICAL | GOVERNANCE_ISSUE GI-SAFRA-001 | decisão humana + C06 |
| threshold cenário 2 | DEFERRED | C06/C07 |
| threshold cenário 4 | DEFERRED | C06/C07 |
| threshold cenário 10 | DEFERRED | C06/C07 |
| threshold cenário 11 | DEFERRED | C06/C07 |
| fonte mínima curva A cenário 9 | DEFERRED | C06/C07 |
| regra para múltiplas tratativas simultâneas do mesmo cenário | DEFERRED | M01 |
| provider/canal de e-mail | DEFERRED | M05 |
| comportamento de e-mail dos platform admins | DEFERRED | M05 |
| período exato da “Safra corrente” para métricas em e-mail | DEFERRED | M05/F04 |
| publicação formal após ownership do 12º card | DEFERRED | M10 |
| janela oficial de governança semanal | DEFERRED | F05 |
| métricas/thresholds quantitativos específicos | DEFERRED | C06/F04 |
| estratégia canônica de migrations (Drizzle x supabase/migrations) | DEFERRED | C05 |

---

# 10. Contratos de regras de negócio — baseline

## RB-SAFRA-001 — Cenário publicado

Somente cenário `PUBLISHED` pode originar tratativa real.

## RB-SAFRA-002 — Ativação humana

Nenhum sinal externo cria `treatment` automaticamente no MVP.

## RB-SAFRA-003 — START

Qualquer usuário Microsoft autenticado pode iniciar cenário publicado. Ator, timestamp server-side e versão vigente devem ser persistidos.

## RB-SAFRA-004 — END

Qualquer usuário Microsoft autenticado pode encerrar tratativa `ACTIVE` quando a necessidade estiver concluída. Ator e timestamp server-side são obrigatórios.

## RB-SAFRA-005 — Execução do protocolo

Owner e equipe executam o protocolo fora do controle passo a passo do Painel. O Painel não cria papel `scenario_updater`.

## RB-SAFRA-006 — CANCEL

CANCEL exige justificativa; não existe delete físico para esconder uma tratativa.

## RB-SAFRA-007 — Versão congelada

`scenario_version_id` é congelado no START.

## RB-SAFRA-008 — Áreas impactadas reais

A tratativa registra suas áreas impactadas, distintas das áreas potencialmente impactáveis do cenário.

## RB-SAFRA-009 — Criticidade do cenário

`CRITICAL | HIGH | MODERATE`.

## RB-SAFRA-010 — Protocolo != chamado

Sem workflow de ticket obrigatório.

## RB-SAFRA-011 — Escalonamento separado

Crise/comitê é estrutura própria, não status da tratativa.

## RB-SAFRA-012 — SLA múltiplo

Duração é derivada de eventos/timestamps; não salvar minuto calculado como fonte primária.

## RB-SAFRA-013 — Fonte ausente

Ausência de integração não pode aparecer como “OK”.

## RB-SAFRA-014 — 12º card

Proposta não publica cenário automaticamente.

## RB-SAFRA-015 — Recorrência

Recorrência informa governança; não promove crise automaticamente.

## RB-SAFRA-016 — Integridade temporal

Sequência temporal inválida deve ser bloqueada ou corrigida por evento administrativo auditável.

## RB-SAFRA-017 — Idempotência

Retry, refresh e double submit não podem duplicar START/END/CANCEL/eventos/notificações.

---

# 11. EIXO 1 — COMEÇO

## Objetivo

Garantir que cenário, identidade, versão, SLA, segurança e fundação estejam corretos antes da abertura operacional.

---

## SAFRA-C00 — Baseline e contenção P0 — CONCLUÍDO

### Entregas concluídas

- baseline registrada;
- `.env` removido do tracking;
- anon bloqueado;
- RLS habilitada;
- policies abertas removidas;
- acesso direto não autorizado testado;
- histórico Git preservado.

### Gate

```text
P0 security = PASS
```

---

## SAFRA-C01 — Documentação canônica e PROJECT_PROFILE — CONCLUÍDO

### Resultado

```text
G3 = PASS
G3.25 = PASS
unknown_material_count = 0
```

### Decisões fechadas

- `service_class = CRITICO`;
- `application_criticality = MEDIUM`;
- `RTO = 30 min`;
- `RPO = 5 min`;
- Microsoft Entra ID / SSO;
- `replica_enabled = false`;
- retenção;
- responsabilidades administrativas.

---

## SAFRA-C02 — Threat model e abuso de negócio — CONCLUÍDO

### Objetivo

Modelar abuso antes de codificar autorização e schema.

### Threats modelados

- START indevido/duplicado;
- END prematuro/repetido;
- CANCEL para mascarar histórico;
- alteração indevida de owner;
- alteração de criticidade para manipular comunicação;
- adulteração de timestamps;
- edição retroativa de cenário;
- nova versão afetando tratamento ativo;
- bypass de UI pela Data API/RPC;
- enumeração de dados;
- vazamento de dados internos;
- duplicidade por retry;
- manipulação para “parar SLA”;
- proposta do 12º card entrando em operação sem governança.

### Controles definidos — ainda não implementar nesta fase

- RLS;
- autorização server-side;
- versionamento de cenário;
- audit trail append-only;
- constraints;
- role mapping;
- event correlation;
- idempotência;
- minimização de dados;
- revisão administrativa.

### Testes derivados

Quatro classes obrigatórias:

1. positivos;
2. negativos;
3. concorrência/retry;
4. limites/bordas temporais.

### Critérios de evidência

Cada teste deve registrar:

```text
ator
correlation_id
estado anterior
ação
resultado
estado posterior
eventos de auditoria
timestamps oficiais
notificações
mutações colaterais
```

### Critério de saída do C02

Fechar somente quando:

- todas as ameaças materiais possuírem controle;
- todo controle possuir fase de implementação;
- testes positivos/negativos/concorrência/limite estiverem derivados;
- riscos residuais estiverem explícitos;
- `G3.5`, `THREAT-001` e `AUTHZ-001` tiverem evidência suficiente.

### Gate

```text
G3.5 = PASS
THREAT-001 = PASS
AUTHZ-001 = PASS
```

**Fechamento em 25/09/2026:** riscos residuais classificados, sem bloqueador material sem destino. Implementação dos controles permanece nas fases responsáveis.

---

## SAFRA-C03 — Glossário e modelo de domínio

### Objetivo

Congelar o vocabulário antes de criar schema v2.

### Termos obrigatórios

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

### C03.1 — Vocabulário canônico congelado

**CONCLUÍDO em 25/09/2026.**

Termos congelados: cenário, versão de cenário, gatilho, detecção, START, protocolo, tratativa, owner, área responsável, área impactada, SLA, criticidade, END, CANCEL, escalonamento, pós-mortem, recorrência, proposta de cenário e publicação de cenário.

Fonte canônica: `docs/GLOSSARIO_DOMINIO.md`.

### C03.2 — Cenário, versão, tratativa e impacto — CONCLUÍDO

Congelado em 25/09/2026:

- cenário = identidade estável do tipo de contingência;
- versão = conteúdo imutável vigente daquele cenário;
- tratativa = ocorrência real criada por START;
- impacto qualitativo = descrição contextual das consequências;
- impacto quantitativo = medição estruturada com métrica + valor + unidade + fonte + referência temporal;
- cenário/versão pode conter impacto esperado;
- tratativa contém impacto observado;
- impacto não altera automaticamente criticidade, escalonamento ou SLA;
- score/threshold quantitativo permanece proibido sem regra e fonte explícitas.

Desenho técnico de medições quantitativas fica para C05/F04.

### C03.3 — Quatro CRITICAL: evidência insuficiente — CONCLUÍDO

Revisão das fontes em 25/09/2026:

- a Matriz v3 não possui coluna de criticidade nem valores CRITICAL/HIGH/MODERATE;
- a reunião confirma três níveis e menciona quatro temas “super pesados”, mas não nomeia os quatro;
- o PDF v2 é preliminar e usa “crítica” em descrições operacionais, sem formalizar a criticidade dos cenários.

Resultado:

- nenhuma lista foi inferida;
- criado `GI-SAFRA-001`;
- classificação produtiva dos quatro CRITICAL permanece bloqueada até evidência/decisão humana formal;
- C06 deve preservar a pendência no seed.

### C03.4 — Handoff sem ambiguidades para C05 — CONCLUÍDO

`docs/GLOSSARIO_DOMINIO.md` v1.1 foi promovido a `READY_FOR_C05`.

Contratos adicionados:
- fonte de verdade e mutabilidade por conceito;
- cardinalidades;
- estados canônicos;
- elegibilidade de START;
- snapshots de owner/área no START;
- áreas e sistemas potencialmente associados por versão;
- criticidade nullable sem default enquanto GI-SAFRA-001 estiver aberto;
- semântica física de END/CANCEL;
- audit trail append-only;
- estrutura mínima para impacto quantitativo;
- recorrência como derivação;
- múltiplos ACTIVE não bloqueados por constraint antes de M01;
- lista explícita de decisões que C05 não pode inventar.

### Decisões que C03 deve deixar explícitas

- `Geral` = visão agregada;
- protocolo operacional não é checklist do Painel;
- diferença entre cenário, versão e tratativa;
- definição de impacto qualitativo e caminho para impacto quantitativo;
- lista dos quatro `CRITICAL` se houver evidência suficiente; caso contrário, permanecer governance issue para C06.

### Entrega

`docs/GLOSSARIO_DOMINIO.md`

### Critério de saída

Nenhuma entidade de C05 pode possuir nome ambíguo ou duas definições concorrentes.

---

## SAFRA-C04 — Identidade, RBAC e RLS

### Objetivo

Implementar autenticação corporativa e autorização definitiva conforme o modelo aprovado.

### C04.1 — Microsoft Entra ID / SSO — HOMOLOGADO

Implementado no frontend:
- gate global de sessão;
- login exclusivamente via Lovable Cloud Auth com provider `microsoft`, que estabelece a sessão Supabase;
- escopo `email`;
- persistência/restauração de sessão Supabase;
- logout;
- bearer token anexado às server functions pelo middleware existente;
- middleware server-side valida token e expõe `sub`/user id;
- nenhum fluxo funcional de senha local foi adicionado.

Homologação concluída em 25/09/2026:
- provider Microsoft configurado via Lovable Cloud Auth;
- primeiro login corporativo realizado com sucesso;
- sessão persistida no Supabase Auth;
- identidade registrada com provider Azure;
- cadeia Microsoft -> Lovable Auth -> Supabase session validada;
- login local por senha permanece proibido pela decisão do projeto;
- evidência runtime: usuário Azure presente em `auth.users` com `last_sign_in_at` preenchido.

### Identidade

```text
Microsoft Entra ID
    -> SSO
    -> Lovable Cloud Auth (provider microsoft)
    -> Supabase Auth session
    -> auth.uid()
```

Sem login local por senha.

### C04.2 — Role mapping sem herança de ownership — IMPLEMENTADO

Implementado no PRIMARY em 25/09/2026:

- cadastro governado de principals em `private.safra_principals`;
- grants em `private.safra_role_grants`;
- pré-provisionamento por e-mail corporativo;
- binding automático para `auth.uid()` no login;
- funções de consulta de role isoladas em schema `private`;
- wrappers públicos `SECURITY INVOKER`;
- nenhum papel administrativo confere ownership de cenário;
- `scenario_owner` indica elegibilidade/responsabilidade, não vínculo com card específico.

Pessoas pré-provisionadas:
- platform admin: Kaue, Amanda, Vinicius, João;
- governance admin: Jair;
- executive admin: Bruno;
- scenario_owner: Daniel, Jiane, Renato.

Validação:
- usuário autenticado Kaue -> `safra_platform_admin = true`;
- `scenario_owner = false`;
- nenhuma tabela scenario→owner existe ainda;
- ownership específico permanece para C05/C06.

Estado do C04:
- `app_metadata.safra_access` foi removido;
- RLS usa o predicado canônico `safra_is_corporate_user()`;
- role mapping permanece em tabelas governadas;
- testes dependentes de cenário/tratativa foram movidos para as fases executáveis correspondentes.

### Role mapping alvo

| Ação | Usuário autenticado | Scenario owner | Governance admin | Executive admin | Platform admin |
|---|---:|---:|---:|---:|---:|
| ver cards | sim | sim | sim | sim | sim |
| START | sim | sim | sim | sim* | sim* |
| END | sim | sim | sim | sim* | sim* |
| CANCEL com motivo | sim | sim | sim | sim* | sim* |
| receber comunicação do próprio card | não por default | sim | conforme governança | não | DEFERRED M05 |
| gerir ownership | não | não | sim | não | suporte técnico, sem decisão de negócio |
| publicar cenário | não | não | conforme fluxo M10 | não | não por herança |
| analytics global | não | seus cards | governança | sim | técnico conforme necessidade |
| manutenção técnica | não | não | não | não | sim |

`*` capacidade base de usuário autenticado; papel não é necessário para START/END/CANCEL.

### Regras de segurança

- nunca confiar em `user_metadata` para autorização;
- `app_metadata`/tabelas governadas para papéis;
- RLS para dados expostos à Data API;
- browser não define role, owner ou criticidade;
- sessão inválida não produz efeito;
- acesso por API deve ter o mesmo resultado de segurança da UI.

### C04.3 — RLS e autorização equivalente entre UI, REST/Data API, RPC e servidor — IMPLEMENTADO

Concluído em 25/09/2026:

- removido o gate temporário `app_metadata.safra_access`;
- criado `public.safra_is_corporate_user()` como predicado único de acesso base;
- RLS de `applications` e `incidents` usa o mesmo predicado;
- middleware server-side consulta o mesmo RPC;
- UI/Data API permanecem sujeitas às mesmas policies;
- RPCs usam o mesmo contexto autenticado;
- `user_metadata` não participa de autorização;
- roles continuam em tabelas governadas.

Validação:
- corporativo Azure: acesso permitido;
- outsider autenticado: zero linhas;
- anon: sem SELECT/EXECUTE;
- `safra_access` removido de app_metadata.

Migration canônica versionada em `supabase/migrations/20260925133200_c04_role_mapping_and_corporate_rls.sql`. O único item administrativo remanescente é o migration repair do histórico remoto.

### Testes obrigatórios do C04

Executar ainda no C04:
- anon não lê/escreve;
- sessão inválida/expirada não produz autorização;
- usuário autenticado não consegue alterar principals/roles governados;
- platform admin não herda scenario_owner;
- acesso direto por REST/RPC obedece à mesma regra-base da UI/server.

Os testes que dependem do domínio real ficam explicitamente deferidos:
- ownership por cenário + separação Jair/Bruno/Jiane/platform admins -> C06.1, após seed dos 11 cenários;
- START autenticado -> C08.1, após fluxo START existir;
- END/CANCEL autenticado -> F02.1, após state machine + END + CANCEL existirem.

Não marcar esses testes como PASS antes da entidade/mutation existir.

### C04.4 — Gate review G5 / ID-001 / ID-002 / AUDIT-001 — BLOCKED POR EVIDÊNCIA

Framework EBSA aplicado literalmente:

- **ID-001 / G5:** exige criação, recuperação, troca de papel, revogação, desligamento e contas de serviço;
- **ID-002 / G5.25:** exige revisão de acessos privilegiados e MFA conforme risco;
- **AUDIT-001 / G5:** exige ator, ação, recurso, data, resultado e correlação para ações sensíveis.

Evidências já disponíveis:
- Microsoft Entra ID / SSO homologado;
- primeiro usuário corporativo criado/autenticado;
- role mapping governado;
- RLS positiva/negativa;
- anon bloqueado;
- outsider corporativo inválido bloqueado;
- platform admin não herda ownership;
- usuário authenticated não altera principals/role grants;
- REST/RPC/server usam predicado corporativo equivalente.

Evidências ainda faltantes:
- teste formal de troca de papel;
- teste formal de revogação;
- cenário de desligamento/sessão antiga;
- decisão/escopo para contas de serviço;
- evidência de recuperação de acesso via Entra corporativo;
- revisão de MFA para papéis privilegiados;
- trilha de auditoria completa com ator + ação + recurso + data + resultado + correlation_id para ações sensíveis.

Resultado:
- `G5 = PARTIAL`;
- `ID-001 = BLOCKED_EVIDENCE`;
- `ID-002 = BLOCKED_EVIDENCE`;
- `AUDIT-001 = BLOCKED_EVIDENCE`.

Não fechar por inferência.

### C04.5 — Fechamento controlado via Lovable — PLANEJADO

Objetivo: usar o ambiente do próprio Lovable Cloud para concluir os controles de identidade/RBAC que ficaram bloqueados pelos conectores externos, sem antecipar C05/C06/C08/F02.

#### Prioridade 0 — limpeza obrigatória

Antes de qualquer novo teste:
- localizar qualquer grant ativo com `source = C04_ID001_TEMP_TEST`;
- revogar/remover o grant temporário de teste;
- comprovar que Kaue permanece apenas com o papel permanente `safra_platform_admin`;
- registrar evidência antes/depois.

Nenhuma evolução deve continuar enquanto esse estado não estiver confirmado.

#### Escopo Lovable

1. **Troca de papel controlada**
   - usar fixture/principal de teste ou mudança temporária reversível;
   - provar alteração imediata de autorização com o mesmo `auth.uid()`;
   - não remover acesso técnico permanente de produção sem rollback explícito.

2. **Revogação de papel**
   - revogar grant governado;
   - comprovar que a RPC de role deixa de autorizar imediatamente;
   - garantir ausência de dependência de `user_metadata` ou cache do browser.

3. **Sessão antiga / desligamento**
   - validar `session_id` contra `auth.sessions` nas operações sensíveis;
   - token com assinatura/expiração válidas, mas sessão inexistente/revogada, deve falhar;
   - preservar o teste já aprovado de `exp` vencido.

4. **AUDIT-001 para RBAC**
   - registrar ator, ação, recurso, data/hora, resultado e `correlation_id`;
   - cobrir grant, troca e revogação de papel;
   - auditoria deve ser server-side e não controlada pelo browser;
   - histórico não pode ser apagado silenciosamente por usuário comum.

5. **Contas de serviço**
   - registrar `NOT_APPLICABLE_MVP` se não existir identidade de serviço funcional no produto;
   - `service_role` técnico do backend não é tratado como usuário humano nem como conta funcional do Painel;
   - qualquer futura conta de integração reabre ID-001.

#### Fora do escopo Lovable

Dependências do Microsoft Entra/TI:
- evidência do processo corporativo de recuperação de acesso;
- política de MFA/Conditional Access dos usuários privilegiados.

O Lovable não deve simular nem substituir essas evidências.

#### Restrições

- não criar `scenarios`, `scenario_versions`, `treatments` ou mutations START/END/CANCEL nesta etapa;
- não alterar ownership dos 11 cenários;
- não mudar a regra de negócio de acesso base;
- não introduzir login local por senha;
- não usar `user_metadata` para autorização;
- não expor service role/secret ao browser;
- toda mudança permanente deve ser versionada em `supabase/migrations`;
- ao final, GitHub deve refletir integralmente o estado produzido no Lovable.

#### Evidências esperadas

```text
TEMP_GRANT_CLEANUP = PASS
ROLE_CHANGE = PASS
ROLE_REVOCATION = PASS
REVOKED_SESSION = PASS
SERVICE_ACCOUNT_SCOPE = N/A_MVP
RBAC_AUDIT_TRAIL = PASS
ENTRA_RECOVERY = EXTERNAL_CORPORATE_CONTROL|PASS
PRIVILEGED_MFA = EXTERNAL_CORPORATE_CONTROL|PASS
```

Somente após essas evidências reavaliar:
- `G5`;
- `ID-001`;
- `ID-002`;
- `AUDIT-001`.

### Gate

```text
G5 = PARTIAL
ID-001 = BLOCKED_EVIDENCE
ID-002 = BLOCKED_EVIDENCE
AUDIT-001 = BLOCKED_EVIDENCE
```

---

## SAFRA-C05 — Schema v2, migrations e invariantes

### Objetivo

Materializar o domínio aprovado sem quebrar imediatamente o legado de TI.

### C05.0 — Autoridade de migrations e captura do C04 — CONCLUÍDO

Decisão:
- `supabase/migrations` é a fonte canônica de migrations;
- Drizzle permanece como tooling/ORM auxiliar e não cria uma segunda trilha de schema;
- migration canônica do C04 criada em:
  `supabase/migrations/20260925133200_c04_role_mapping_and_corporate_rls.sql`.

Estado:
- conteúdo equivalente ao estado live validado do C04;
- role mapping, predicado corporativo e RLS capturados em código;
- histórico remoto reconciliado em 25/09/2026; sem drift conhecido de C00/C04/C05.

### Antes de criar migration
1. autoridade canônica definida: `supabase/migrations`; Drizzle não é fonte de verdade de schema — **CONCLUÍDO**;
2. reconciliar drift da migration de hardening — **CONCLUÍDO**;
3. documentar rollback — **CONCLUÍDO** em `docs/ROLLBACK_E_BANCO_DESCARTAVEL.md`;
4. garantir banco descartável para teste — **IMPLEMENTADO** via Supabase local + pgTAP + GitHub Actions.

### C05.1 — Schema v2 canônico — IMPLEMENTADO

Migration:
`supabase/migrations/20260925170000_c05_schema_v2_canonical_base.sql`

Concluído:
- entidades canônicas materializadas no PRIMARY;
- RBAC existente reutilizado, sem tabela concorrente;
- RLS deny-by-default;
- invariantes de publicação/versionamento/owner/snapshot/append-only implementadas;
- GI-SAFRA-001 preservada OPEN;
- legado applications/incidents preservado;
- self-tests positivos/negativos executados com rollback integral de fixtures.

Não incluído:
- seed C06;
- RPCs START/END/CANCEL;
- decisão de múltiplos ACTIVE;
- criticidade inferida;
- notificações produtivas.

### C05.2 — Rollback e banco descartável — IMPLEMENTADO

Artefatos:
- `docs/ROLLBACK_E_BANCO_DESCARTAVEL.md`;
- `supabase/seed.sql` sem dados produtivos;
- `supabase/tests/database/c05_schema_v2.test.sql`;
- `.github/workflows/database-disposable-test.yml`.

Contrato:
```text
supabase start
-> supabase db reset --local
-> supabase test db
-> supabase db lint --local --level error
-> supabase stop --no-backup
```

O PRIMARY nunca é tratado como banco descartável. Após C06, rollback padrão passa a ser forward fix, preservando histórico operacional.

### Ordem recomendada

1. `operational_areas`;
2. `systems`;
3. reutilizar `private.safra_principals` + `private.safra_role_grants` (sem `safra_user_roles` concorrente);
4. `scenarios`;
5. `scenario_versions`;
6. `scenario_owners`;
7. `scenario_version_impacted_areas`;
8. `scenario_version_systems`;
9. `scenario_slas`;
10. `treatments`;
11. `treatment_impacted_areas`;
12. `treatment_impact_measurements`;
13. `treatment_events`;
14. `treatment_escalations`;
15. `notifications_log`;
16. `scenario_proposals`;
17. `scenario_proposal_owner_responses`;
18. `governance_issues`;
19. mapeamentos para `incidents` quando aplicável.

### Invariantes mínimos

- FK explícita;
- enums/status via constraints ou tipo governado;
- timestamp oficial server-side;
- `scenario_version` publicada não é reescrita;
- tratamento congela `scenario_version_id`;
- snapshot de owner e área responsável no START;
- criticidade sem decisão aceita ausência explícita e não possui default;
- audit events append-only;
- sem cascade destrutivo em histórico operacional;
- CANCEL exige razão;
- END/CANCEL somente em `ACTIVE`;
- idempotência para mutations críticas;
- correlation id persistido;
- constraints de integridade temporal;
- não criar unicidade de ACTIVE por cenário antes da decisão M01;
- views expostas devem respeitar RLS/security invoker quando aplicável.

### Testes

- migration em banco descartável;
- positive/negative constraints;
- double submit;
- concorrência END x CANCEL;
- version freeze;
- rollback ensaiado;
- API direto;
- RLS positiva/negativa.

### Gate

```text
G5 = PASS_C05_SCHEMA_BASE
G6 = PARTIAL_SCHEMA_READY
```

C05 continua aberto para passos seguintes de RPCs/constraints/idempotência adicionais previstos, mas a **base canônica do schema v2 está concluída**.

---

## SAFRA-C06 — Seed canônico da Matriz v3

### Pipeline

```text
XLSX v3
 -> parser versionado
 -> staging
 -> validação
 -> preview diff
 -> aprovação humana
 -> seed/migration
 -> reconciliação
```

### Validar

- exatamente 11 cenários publicados no seed inicial;
- owner conforme Matriz v3;
- área responsável;
- áreas impactáveis;
- protocolo completo;
- criticidade quando suportada por fonte/decisão;
- SLA textual preservado;
- sistemas/ferramentas;
- mapeamentos EDB05/EDB06;
- P1-P4 não publicados por inferência.

### Campos abertos

`X h`, `X min`, capacidade, curva A e outras lacunas entram em `governance_issues`.

### Saída

Reconciliação 100% dos campos importados contra a Matriz v3.

### C06.1 — Regressão RBAC/ownership com cenários reais

Executar somente depois que os 11 cenários e seus vínculos de owner estiverem materializados.

Testes:
- Daniel é owner somente dos cenários 1, 2, 3, 7, 10 e 11;
- Jiane é owner somente dos cenários 4, 5, 6 e 8;
- Renato é owner somente do cenário 9;
- Jair mantém governance admin sem herdar ownership;
- Bruno mantém executive admin sem ownership e sem permissão técnica;
- Kaue/Amanda/Vinicius/João mantêm platform admin sem ownership automático;
- usuário autenticado não consegue se autoatribuir owner via payload/REST/RPC;
- alteração de ownership exige caminho de governança;
- leitura direta por Data API/RPC preserva o mesmo modelo de autorização.

Critério de PASS:
- todos os testes usam cenários reais do seed;
- nenhuma role global produz ownership implícito;
- ownership é demonstrado pelo vínculo explícito scenario↔user.

---

## SAFRA-C07 — Engine de SLA

### Princípio

SLA de protocolo é diferente do SLO/RTO/RPO do software.

### Modelo

Cada SLA possui:

```text
start_event
end_event
target_value
target_unit
```

### Regras

- duração calculada por timestamps;
- timezone padronizado;
- relógio negativo proibido;
- CANCEL não equivale a SLA cumprido;
- END só fecha o SLA quando seu `end_event` for `TREATMENT_RESOLVED`;
- múltiplos SLAs podem coexistir no mesmo cenário;
- evento ausente => SLA não mensurável, não “OK”.

### Testes

- borda exata;
- breach;
- END no instante do breach;
- timezone/DST;
- evento ausente;
- CANCEL;
- dois SLAs simultâneos;
- tentativa de alterar status/timestamp para parar relógio.

---

## SAFRA-C08 — UX do COMEÇO

### Telas

1. Visão Geral;
2. Catálogo de Cenários;
3. Detalhe do Cenário;
4. Abrir Protocolo;
5. Proposta de novo cenário (12º card);
6. Administração/Governança conforme papel.

### START

```text
usuário autenticado
 -> selecionar cenário publicado
 -> confirmar contexto
 -> informar escopo/impacto necessário
 -> confirmar áreas realmente impactadas, se aplicável
 -> revisar criticidade vigente
 -> visualizar owner + protocolo + versão
 -> confirmar START
 -> backend valida
 -> cria treatment
 -> congela scenario_version_id
 -> grava TREATMENT_OPENED
 -> inicia SLAs aplicáveis
 -> dispara comunicação aplicável
```

### Guardrails

- confirmação explícita;
- protocolo completo visível;
- owner visível;
- cenário proposto não pode ser aberto;
- loading/error/forbidden claros;
- acessibilidade WCAG 2.2 AA;
- não depender de cor para estado;
- ação crítica nunca depende só de esconder botão.

### C08.1 — Regressão de autorização do START

Testar com cenário PUBLISHED real:
- usuário Microsoft corporativo autenticado consegue START;
- anon/outsider não consegue START;
- START por não-owner é permitido conforme regra de negócio;
- scenario_version_id é resolvida e congelada no backend;
- ator e timestamp são server-side;
- payload não consegue trocar owner/criticidade/version_id;
- UI, REST/RPC e server-side produzem decisão equivalente;
- retry/duplo clique não duplica tratativa.

---

## SAFRA-C09 — Fundação operacional

### Decisões já fechadas

```text
service_class = CRITICO
SLO = 99.95%
RTO = 30 min
RPO = 5 min
replica_enabled = false
```

### Trabalho do C09

- definir estratégia real de backup;
- comprovar restore;
- comprovar RPO/RTO;
- medir pico esperado de usuários;
- testar capacidade sustentável;
- monitorar latência/erros/login/mutations;
- validar logs sem secrets;
- criar runbook de recuperação.

### Evidências

- restore test;
- resultado de carga/stress/spike;
- smoke de auth;
- evidência RTO/RPO;
- observabilidade mínima.

### Gate

`G5.5`

---

# 12. EIXO 2 — MEIO

## Objetivo

Responder:

> O protocolo está ativo. Há quanto tempo? Quem abriu? Qual versão vale? Qual owner responde? Quais SLAs estão correndo? Houve escalonamento? Quem precisa ser comunicado?

O Painel **não** precisa saber em qual passo operacional a equipe está.

---

## SAFRA-M01 — State machine

Estados:

```text
ACTIVE
RESOLVED
CANCELLED
```

Transições:

```text
NEW START -> ACTIVE
ACTIVE -> RESOLVED   # END válido
ACTIVE -> CANCELLED  # CANCEL válido + motivo
```

Regras:

- qualquer usuário autenticado pode executar END/CANCEL;
- backend valida estado atual;
- `RESOLVED`/`CANCELLED` não voltam silenciosamente a `ACTIVE`;
- concorrência END x CANCEL precisa resultar em uma única transição;
- regra de múltiplas tratativas simultâneas do mesmo cenário deve ser decidida aqui.

---

## SAFRA-M02 — Audit trail e acompanhamento mínimo

### Objetivo

Substitui o antigo conceito de “persistência dos passos”.

Registrar apenas eventos relevantes ao governo da contingência:

- START;
- alterações de áreas impactadas;
- nota de governança quando necessária;
- SLA breach;
- escalonamento;
- notificações;
- END;
- CANCEL;
- correção administrativa auditável.

### Regras

- timeline reconstruível após refresh/troca de dispositivo;
- eventos críticos append-only;
- concorrência não pode perder evento;
- notas não substituem protocolo operacional;
- sem checklist obrigatório.

---

## SAFRA-M03 — Timeline operacional

A timeline une:

- abertura;
- mudanças relevantes;
- notificações;
- breaches;
- escalonamentos;
- encerramento/cancelamento;
- correções administrativas.

Deve responder rapidamente:

- o que aconteceu;
- desde quando;
- qual cenário e versão;
- quem abriu;
- qual owner;
- quem foi impactado;
- quais SLAs estão correndo/vencidos;
- qual escalonamento existe.

---

## SAFRA-M04 — SLA em tempo real

Exibir:

- tempo decorrido;
- prazo alvo;
- tempo restante;
- estado;
- breach timestamp;
- múltiplos SLAs.

Estados visuais:

```text
ON_TRACK
BREACHED
COMPLETED_ON_TIME
COMPLETED_LATE
NOT_MEASURABLE
NOT_APPLICABLE  # somente quando regra aprovada
```

`AT_RISK` só existe se houver regra aprovada; não inventar percentual.

---

## SAFRA-M05 — Notificações

### Eventos aprovados

- START;
- END;
- CANCEL.

### Conteúdo mínimo

- evento;
- data;
- hora;
- autor;
- card/cenário;
- protocolo completo;
- métricas aplicáveis: MTTD, MTTR, MTBF, disponibilidade e ocorrências;
- período: Safra corrente — janela exata ainda deve ser formalizada nesta fase/F04.

### Regras de destinatário

- owner do card recebe comunicações do próprio card;
- Jair recebe comunicações de governança aplicáveis;
- Jiane recebe somente as comunicações dos cards em que é owner;
- Bruno não recebe e-mail operacional normal;
- comportamento dos platform admins permanece decisão desta fase;
- destinatários duplicados devem ser deduplicados por e-mail normalizado.

### Requisitos técnicos

- envio server-side;
- template versionado;
- log de entrega;
- idempotência;
- retry controlado;
- nenhuma decisão de destinatário baseada no frontend;
- não incluir dados além do necessário.

---

## SAFRA-M06 — Escalonamento e comitê

Níveis:

```text
NONE
TECHNICAL_CRISIS
BUSINESS_CRISIS
EXECUTIVE
```

Registrar:

- motivo;
- ator;
- instante;
- participantes/áreas;
- decisão;
- encerramento do escalonamento.

Recorrência sozinha não promove `EXECUTIVE`.

---

## SAFRA-M07 — Ponte com incidents de TI

Regras:

- incidente TI pode existir sem protocolo;
- protocolo pode existir sem incidente;
- incidente elegível pode ajudar a sugerir cenário no futuro;
- MVP não cria protocolo automaticamente;
- MTTD/MTTR/MTBF de TI não substituem duração do protocolo Safra.

---

## SAFRA-M08 — Torre de Controle

Cards prioritários:

- protocolos ativos agora;
- críticos ativos;
- SLA vencido;
- áreas impactadas;
- protocolos por área/cenário;
- tempo da tratativa mais antiga;
- escalonamentos ativos.

Lista operacional:

- cenário;
- criticidade;
- owner;
- área responsável;
- áreas impactadas;
- SLA(s);
- tempo ativo;
- escalonamento;
- autor do START;
- versão do cenário.

### TV Mode

- sem botões de mutação;
- alta legibilidade;
- atualização segura;
- sem dado pessoal desnecessário;
- contraste adequado.

---

## SAFRA-M09 — Visões por audiência

### Usuário autenticado

Visão ampla dos cards conforme política aprovada.

### Scenario owner

- cards sob sua responsabilidade;
- ativos;
- histórico;
- métricas dos seus cards.

### Jair

- governança global;
- propostas;
- ownership;
- recorrência;
- pendências.

### Bruno

- analytics global executivo;
- todos os cards e métricas;
- sem mutação técnica.

---

## SAFRA-M10 — Governança do 12º card

### Formulário inicial

- nome — da sessão Microsoft;
- e-mail — da sessão Microsoft;
- título;
- descrição do problema;
- como o problema afeta a Safra.

### Fluxo aprovado

```text
SUBMITTED
 -> Jair recebe
 -> Jair envia para Daniel, Renato e Jiane
 -> exatamente 1 aceita -> vira owner
 -> 2+ aceitam -> Jair escolhe
 -> 0 aceitam -> Jair decide OU escala para Bruno
```

### Depois do ownership

A fase deve definir, sem inferência:

- quais campos adicionais são obrigatórios antes de publicar;
- quem aprova criticidade;
- quem aprova SLA;
- quem aprova protocolo;
- como nasce a primeira `scenario_version`;
- quando o status muda para `PUBLISHED`.

Aprovação nunca reescreve cenário já publicado; gera nova versão quando aplicável.

---

## SAFRA-M11 — Fontes reais futuras

Sem integração obrigatória no MVP.

Pipeline futuro:

```text
SOURCE
 -> CONTRACT
 -> VALIDATE
 -> NORMALIZE
 -> OBSERVATION/SIGNAL
 -> HUMAN CONFIRMATION
 -> TREATMENT
```

Cada fonte exige:

- SOURCE_CONTRACT;
- QUALITY_RULES;
- DATA_RELEASE;
- timeout/retry;
- idempotência;
- observabilidade;
- teste de falha;
- rollback.

---

# 13. EIXO 3 — FIM

## Objetivo

Encerrar com integridade, preservar histórico e transformar operação em aprendizado.

---

## SAFRA-F01 — END formal

### Obrigatório no backend

- validar `ACTIVE`;
- persistir `closed_by`;
- persistir `closed_at` server-side;
- gravar `TREATMENT_RESOLVED`;
- fechar somente SLAs cujo `end_event` corresponda ao END;
- manter histórico imutável.

### Campos humanos adicionais

Resultado, observação final e impacto final devem ser decididos/homologados nesta fase; não presumir obrigatoriedade antes da decisão de negócio.

---

## SAFRA-F02 — CANCEL

Usar quando:

- abertura por engano;
- cenário incorreto;
- duplicidade;
- protocolo não aplicável.

Obrigatório:

- motivo;
- ator;
- timestamp server-side;
- evento auditável.

Nunca excluir silenciosamente.

CANCEL não deve ser contado automaticamente como SLA cumprido.

### F02.1 — Regressão de autorização END/CANCEL

Executar com tratativa ACTIVE real:
- usuário Microsoft corporativo autenticado pode END;
- usuário Microsoft corporativo autenticado pode CANCEL com motivo;
- anon/outsider não consegue END/CANCEL;
- END repetido falha/idempotente conforme contrato;
- CANCEL repetido não duplica evento/notificação;
- END x CANCEL concorrentes produzem uma única transição válida;
- CANCEL não mascara SLA nem apaga histórico;
- payload não consegue elevar owner/role;
- UI, REST/RPC e server-side produzem decisão equivalente.

Este bloco fecha os testes originalmente listados no C04 que dependiam da existência de treatments e mutations reais.

---

## SAFRA-F03 — Pós-mortem

Suportar quando houver regra explícita por cenário/criticidade.

Cenário 6 já possui referência de pós-mortem <=48h e deve ser tratado como SLA adicional quando formalizado no seed/regra.

---

## SAFRA-F04 — Analytics

### Métricas Safra

- STARTs;
- ENDs;
- CANCELs;
- duração média/mediana/p90;
- cumprimento de SLA;
- breaches;
- recorrência;
- duração acumulada;
- protocolos simultâneos;
- escalonamentos;
- críticos no período;
- áreas impactadas.

### Métricas de confiabilidade preservadas

- MTTD;
- MTTR;
- MTBF;
- disponibilidade.

### Audiências

- Bruno: todos os cards/métricas;
- owners: seus cards;
- Jair: governança global.

### Pendência

Definir janela exata de “Safra corrente” para e-mails e analytics acumulados.

---

## SAFRA-F05 — Governança semanal

Mostrar:

- cenários recorrentes;
- duração acumulada;
- SLA breach repetido;
- ações pendentes;
- owners;
- tendência;
- críticos da semana;
- tratativas ainda ativas.

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

Definir janela/ritual oficial nesta fase.

---

## SAFRA-F06 — Relatório executivo

Períodos:

- dia;
- semana;
- Safra acumulada;
- intervalo customizado.

Conteúdo:

- total de tratativas;
- cenário;
- criticidade;
- duração;
- SLA;
- impacto;
- escalonamento;
- recorrência;
- ações de governança.

---

## SAFRA-F07 — Homologação de negócio

Para cada cenário:

1. nome/contexto corretos;
2. owner correto;
3. área responsável correta;
4. áreas impactáveis corretas;
5. protocolo completo correto;
6. SLA correto;
7. ferramenta/origem correta;
8. START correto;
9. notificações corretas;
10. END/CANCEL corretos;
11. histórico/versionamento corretos.

Evidência: checklist de homologação por cenário.

Gate: `G10`.

---

## SAFRA-F08 — Auditoria E2E pré-release

### Segurança

- anon bloqueado;
- RLS positiva/negativa;
- role mapping;
- API direto;
- bypass de UI;
- enumeração;
- vazamento em logs/erros;
- secrets/dependencies.

### Integridade

- double submit;
- retry;
- timestamps;
- version freeze;
- END x CANCEL concorrente;
- notification idempotency;
- SLA manipulation;
- append-only audit.

### UX

- desktop/notebook/tablet/celular;
- TV mode;
- teclado/foco;
- contraste;
- loading/empty/error/forbidden;
- reflow 320 CSS px.

### Operação

- load;
- stress;
- spike;
- restore;
- RTO/RPO;
- logs;
- alertas.

Gates:

```text
G7
G8
G10.5
```

---

## SAFRA-F09 — Release e operação

Antes da abertura geral:

- business acceptance;
- auditoria sem bloqueador crítico;
- RELEASE_APPROVAL;
- DATA_RELEASE para fonte real nova;
- runbook;
- rollback;
- suporte;
- monitoramento do Painel;
- restore comprovado.

Operação contínua:

- revisar acessos;
- revisar owners;
- revisar cenários e versões;
- revisar SLAs;
- renovar teste de recuperação;
- acompanhar capacidade;
- reabrir gate após mudança material.

Gate: `G11`.

---

# 14. Jornada E2E de referência — v2.1

## 14.1 COMEÇO

```text
1. Usuário autenticado identifica uma necessidade/ocorrência.
2. Consulta o catálogo.
3. Seleciona cenário publicado.
4. Painel mostra owner, protocolo, criticidade, SLA e versão.
5. Usuário confirma contexto/impacto necessário.
6. Usuário confirma START.
7. Backend valida sessão + cenário + versão vigente.
8. Backend cria treatment e congela scenario_version_id.
9. Backend grava TREATMENT_OPENED com ator/timestamp.
10. SLAs aplicáveis iniciam.
11. Comunicação START é enfileirada/idempotente.
```

## 14.2 MEIO

```text
12. Owner conduz o protocolo com sua equipe fora do checklist do Painel.
13. Painel mantém tratativa ACTIVE, relógios e timeline.
14. Mudanças relevantes geram eventos auditáveis.
15. Breaches são registrados.
16. Escalonamento, quando necessário, é registrado.
17. Comunicações aplicáveis são enviadas e logadas.
```

## 14.3 FIM

```text
18. Necessidade é concluída ou abertura é considerada indevida.
19. Usuário autenticado executa END ou CANCEL.
20. Backend valida transição.
21. Backend grava ator/timestamp/evento.
22. SLAs são fechados conforme seus end_events.
23. Comunicação END/CANCEL é enfileirada.
24. Histórico permanece imutável/auditável.
25. Métricas e recorrência alimentam analytics/governança.
```

---

# 15. Matriz de testes de negócio — v2.1

## 15.1 START

- autenticado abre cenário publicado;
- não autenticado não abre;
- cenário DRAFT/PROPOSED/INACTIVE não abre;
- versão arbitrária enviada pelo client é rejeitada/ignorada;
- duplo clique não duplica;
- retry após timeout é idempotente;
- START na troca de versão usa uma única versão definida pelo backend.

## 15.2 END/CANCEL

- autenticado encerra `ACTIVE`;
- END repetido falha/idempotente sem novo evento;
- CANCEL exige razão;
- END x CANCEL concorrentes produzem uma única transição válida;
- CANCEL imediato após START preserva os dois eventos;
- END/CANCEL não aceita timestamp oficial do browser.

## 15.3 Versionamento

- versão publicada não é editada in-place;
- nova versão não altera tratamento ativo;
- owner/criticidade/protocolo histórico permanecem congelados;
- 12º card não vira cenário publicado sem governança.

## 15.4 SLA

- dois SLAs simultâneos;
- borda exata;
- breach;
- END no instante do breach;
- CANCEL;
- evento ausente;
- timezone/DST;
- tentativa de alterar status/timestamp para parar SLA falha.

## 15.5 Segurança / API

- anon sem acesso;
- REST/RPC direto respeita autorização;
- payload não eleva role/owner;
- paginação não permite enumeração fora do escopo;
- logs/erros não vazam secret/token/e-mail desnecessário;
- sessão expirada não produz efeito.

## 15.6 Notificações

- START gera no máximo uma comunicação por destinatário/evento;
- END idem;
- CANCEL idem;
- recipient dedup por e-mail normalizado;
- Bruno não recebe e-mail operacional normal;
- Jiane recebe somente seus cards;
- owner vigente recebe protocolo completo.

---

# 16. Observabilidade do próprio Painel

Monitorar:

- erro de login;
- sessão inválida;
- mutation negada;
- RLS denial anômalo;
- latência de mutation/query;
- duplicate request;
- falha de notificação;
- fila de notificação;
- erro de SLA engine;
- inconsistência de state transition;
- indisponibilidade do Painel;
- restore/recovery test status.

Não registrar secrets nem payloads pessoais excessivos.

---

# 17. Estratégia de dados reais

Cada fonte futura deve possuir:

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

Sem fonte real, o cenário continua operável manualmente. A interface deve diferenciar ausência de integração de “sistema saudável”.

---

# 18. Arquitetura lógica alvo

```text
[Browser / TV]
      |
      v
[React / TanStack]
      |
      v
[Microsoft Entra ID -> Auth]
      |
      v
[Lovable Cloud PRIMARY]
      |
      +-- RLS / role mapping
      +-- Postgres
      |    +-- catálogo/versionamento
      |    +-- treatments
      |    +-- audit events
      |    +-- SLA definitions
      |    +-- proposals/governance
      |    +-- notification log
      |
      +-- RPC / funções transacionais
           +-- start_treatment
           +-- resolve_treatment
           +-- cancel_treatment
           +-- publish_scenario_version
           +-- change_escalation
      |
      +-- server-side notification adapter

[FUTURO]
External source
 -> adapter
 -> signal
 -> human confirmation
 -> treatment
```

Operações críticas não devem ser montadas apenas com `.insert()`/`.update()` genérico do browser.

---

# 19. Ordem de execução canônica

## Bloco 0 — Fundação segura

1. C00 — concluído;
2. C01 — concluído;
3. C02 — em andamento.

## Bloco 1 — Domínio e backend

4. C03 — glossário/modelo;
5. C04 — identidade/RBAC/RLS;
6. C05 — schema v2/migrations;
7. C06 — seed Matriz v3;
8. C07 — engine SLA.

## Bloco 2 — COMEÇO utilizável

9. C08 — UX START;
10. C09 — backup/restore/capacidade.
## Bloco 3 — MEIO

11. M01 — state machine;
12. M02 — audit trail/acompanhamento mínimo;
13. M03 — timeline;
14. M04 — SLA runtime;
15. M05 — notificações;
16. M06 — escalonamento;
17. M07 — ponte TI;
18. M08 — Torre de Controle;
19. M09 — visões por audiência;
20. M10 — governança de novos cenários;
21. M11 — integrações futuras.

## Bloco 4 — FIM

22. F01 — END;
23. F02 — CANCEL;
24. F03 — pós-mortem;
25. F04 — analytics;
26. F05 — governança semanal;
27. F06 — relatório executivo.

## Bloco 5 — Homologação e release

28. F07 — homologação;
29. F08 — auditoria E2E;
30. F09 — release/operação.

---

# 20. Gates de produto — melhorados

## P0 — SAFE TO REFACTOR — PASS

- secrets tratados;
- anon bloqueado;
- baseline documentada.

## P1 — DOMAIN READY

Só passa quando:

- C02 fechado;
- glossário aprovado;
- role model aprovado/implementável;
- schema aprovado;
- 11 cenários reconciliados;
- governance issues catalogadas;
- nenhuma regra crítica depende de suposição.

## P2 — START READY

Só passa quando:

- autenticação Microsoft funciona;
- usuário autenticado consegue START;
- não autenticado é bloqueado;
- START é transacional/idempotente;
- versão é congelada;
- audit event existe;
- SLA inicia corretamente;
- comunicação START é deduplicada.

## P3 — IN-FLIGHT READY

Só passa quando:

- timeline confiável;
- eventos auditáveis;
- concorrência tratada;
- SLA runtime correto;
- escalonamento auditável;
- nenhuma dependência de checklist operacional existe.

## P4 — CLOSE READY

Só passa quando:

- END por usuário autenticado funciona;
- CANCEL com motivo funciona;
- END x CANCEL concorrente é seguro;
- histórico é imutável/auditável;
- SLA não pode ser manipulado por status/timestamp do client;
- comunicação END/CANCEL é idempotente.

## P5 — BUSINESS READY

Só passa quando:

- 11 cenários homologados;
- owners/protocolos/SLAs corretos;
- criticidade homologada;
- notificações homologadas;
- Jair/owners/Bruno validam suas visões correspondentes.

## P6 — RELEASE READY

Só passa quando:

- G7/G10/G10.5 aplicáveis aprovados;
- restore comprovado;
- RTO/RPO evidenciados;
- capacidade aceita;
- WCAG crítica sem bloqueador;
- RELEASE_APPROVAL emitido.

---

# 21. Mapeamento Framework EBSA x roadmap

| Framework | Fase | Aplicação |
|---|---|---|
| I-1 | C00/C02 | trust boundary/secrets |
| I0/G0 | C00/C01 | ambiente/intenção |
| G2/G3 | C00/C01 | GitHub-first/docs |
| G3.25 | C01 | PROJECT_PROFILE |
| G3.5 | C02 | threat/privacy |
| G4/G4.5 | C08/M08/M09 | UX/frontend |
| G5 | C04/C05/M01-M07/F01-F03 | backend/security |
| G5.25 | C00/C01/F08 | supply chain/governança |
| G5.5 | C09 | capacity/recovery |
| G6 | C06/M11 | data contracts |
| G6.5 | C07 + regras + M11 | rule traceability |
| G7 | F08 | qualidade integrada |
| G8 | F08 | candidate release |
| G9 | N/A | replica=false |
| G10 | F07 | homologação |
| G10.5 | F08 | auditoria final |
| G11 | F09 | operação |

---

# 22. ADRs / decisões arquiteturais

| ADR | Decisão | Estado |
|---|---|---|
| ADR-001 | evoluir `incident-log-pro` | APPROVED |
| ADR-002 | Lovable Cloud PRIMARY; REPLICA=false | APPROVED |
| ADR-003 | service_class=CRITICO; SLO 99,95%; RTO 30; RPO 5 | APPROVED |
| ADR-004 | Microsoft Entra ID / SSO | APPROVED |
| ADR-005 | operações críticas via função/RPC transacional | PROPOSED -> decidir em C05 |
| ADR-006 | Geral = visão, não área | APPROVED |
| ADR-007 | ativação humana no MVP | APPROVED |
| ADR-008 | OTRS fora do MVP | APPROVED |
| ADR-009 | integrações uma por ciclo | PROPOSED |
| ADR-010 | tooling de migrations | DEFERRED C05 |
| ADR-011 | scenario criticality != application criticality | APPROVED |
| ADR-012 | modelo de papéis/responsabilidades | APPROVED |
| ADR-013 | subtipos administrativos | APPROVED |
| ADR-014 | 12º card como proposal | APPROVED |
| ADR-015 | application_criticality=MEDIUM | APPROVED |
| ADR-016 | retenção | APPROVED |
| ADR-017 | fechamento C01 | APPROVED |

---

# 23. Backlog fora do MVP

- abertura automática por Intelipost/Protheus/OTRS;
- remediação automática;
- IA de causa-raiz;
- ML de risco;
- WhatsApp/SMS/push;
- data lake dedicado;
- event streaming complexo;
- REPLICA;
- integração ampla com Power BI como dependência operacional;
- checklist operacional detalhado por área;
- decisão automática de criticidade/crise.

---

# 24. Definition of Done global

Uma funcionalidade só é `DONE` quando:

1. possui fonte/decisão;
2. regra está identificada/versionada quando aplicável;
3. autorização está no backend/banco;
4. RLS foi testada quando aplicável;
5. migration está versionada;
6. rollback existe;
7. testes positivos/negativos/borda existem;
8. concorrência/idempotência foram testadas onde necessário;
9. E2E cobre API direto quando ação é sensível;
10. audit trail existe;
11. UI trata loading/empty/error/forbidden;
12. acessibilidade crítica foi validada;
13. documentação foi atualizada;
14. evidência foi registrada;
15. homologação de negócio ocorreu quando regra mudou;
16. DATA_RELEASE existe antes de nova fonte real;
17. performance/recovery foram reavaliados quando impacto material existir.

---

# 25. Documentação viva

Após cada etapa, atualizar no mínimo:

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
docs/evidence/*
docs/data-contracts/*
docs/data-releases/*
```

---

# 26. Regras de execução do programa

1. GitHub é o registro durável das mudanças.
2. Não usar force-push/rebase/amend/squash destrutivo sobre histórico sincronizado.
3. Não alterar regra de negócio por inferência da LLM.
4. Não criar documentação paralela quando já existe fonte canônica.
5. Não começar redesign amplo antes de domínio, auth e schema estarem estáveis.
6. Não introduzir integração real sem contrato e DATA_RELEASE.
7. Não usar frontend como barreira de segurança.
8. Não transformar decisão deferida em default silencioso.
9. Não executar protocolo operacional dentro do Painel; governar a contingência.
10. Ao fim de cada etapa, atualizar documentação e evidências.

---

# 27. Critério de encerramento dos três eixos

## COMEÇO concluído

O sistema sabe:

- quais cenários existem;
- qual versão está vigente;
- quem é o owner;
- quais áreas podem ser impactadas;
- quais SLAs existem;
- quem está autenticado;
- como START acontece com segurança;
- como recuperar o próprio Painel.

## MEIO concluído

O sistema sabe:

- quais tratativas estão ativas;
- desde quando;
- quem abriu;
- qual versão vale;
- quais SLAs estão correndo;
- quais áreas estão impactadas;
- qual escalonamento existe;
- quem precisa ser comunicado;
- qual trilha auditável existe.

## FIM concluído

O sistema sabe:

- como a tratativa terminou;
- quem encerrou/cancelou;
- quanto durou;
- quais SLAs foram cumpridos ou violados;
- quais cenários se repetem;
- quais ações de governança foram abertas;
- o que deve mudar para a próxima Safra.

---

# 28. Próximo passo exato

Fase atual:

```text
SAFRA-C03 — Glossário e modelo de domínio
```

Já concluído dentro do C02:

- ameaças principais identificadas;
- controles mapeados;
- casos de bypass/API, enumeração, vazamento, retry e SLA manipulável formalizados;
- testes positivos, negativos, concorrência/retry e limite derivados.

Fechamento C02 concluído:

1. riscos residuais revisados;
2. cobertura de G3.5 / THREAT-001 / AUTHZ-001 confirmada;
3. C02 encerrado documentalmente;
4. próximo ciclo: C03 — Glossário e modelo de domínio;
5. controles permanecem para implementação em C04/C05 e fases dependentes.

---

# 29. Conclusão

A versão 2.1 corrige uma ambiguidade importante do roadmap anterior: **o Painel Safra não é um executor do protocolo operacional; é uma camada de governança da contingência**.

A arquitetura alvo deve manter cinco compromissos simultaneamente:

```text
DOMÍNIO CORRETO
+ IDENTIDADE REAL
+ AUTORIZAÇÃO SERVER-SIDE
+ TEMPO/AUDITORIA CONFIÁVEIS
+ GOVERNANÇA/ANALYTICS
```

O próximo risco a evitar é antecipar implementação antes de concluir o C02/C03. A sequência permanece deliberada: primeiro ameaça e domínio; depois identidade/RLS; depois schema; depois dados; depois UX/operação.
---

## SAFRA-C04 — CONCLUÍDO (25/09/2026)

Entregue: limpeza do grant temporário, troca e revogação de papel validadas em tempo real,
vínculo com sessão viva (`session_id` x `auth.sessions`), trilha de auditoria RBAC append-only,
contas de serviço classificadas como N/A no MVP.

Controles corporativos externos ao escopo da aplicação: `ENTRA_RECOVERY` e `PRIVILEGED_MFA`, sob responsabilidade da TI/Microsoft Entra.

Não iniciado neste ciclo, conforme restrição: scenarios, scenario_versions, scenario_owners,
treatments, START (C08.1), END/CANCEL (F02.1) e seed dos 11 cenários (C06.1).

Próximo passo: SAFRA-C05 — Schema v2, migrations e invariantes.


### C04.6 — Auditoria pós-Lovable

Resultado técnico interno:
- TEMP_GRANT_CLEANUP = PASS;
- ROLE_CHANGE = PASS;
- ROLE_REVOCATION = PASS;
- REVOKED_SESSION = PASS;
- SERVICE_ACCOUNT_SCOPE = NOT_APPLICABLE_MVP;
- RBAC_AUDIT_TRAIL = PASS.

Dependências externas:
- ENTRA_RECOVERY = EXTERNAL_CORPORATE_CONTROL;
- PRIVILEGED_MFA = EXTERNAL_CORPORATE_CONTROL.

Gates:
```text
G5 = PASS
ID-001 = PASS_APP_SCOPE
ID-002 = PASS_APP_SCOPE
AUDIT-001 = PASS
```

Não avançar o status para C05 por decisão automática; revisão humana permanece necessária.


### C04.7 — Fronteira de responsabilidade Entra — APROVADA

Decisão humana:
- recuperação de acesso Microsoft pertence à TI/Microsoft Entra;
- bloqueio, MFA e Conditional Access da identidade Microsoft pertencem à TI/Microsoft Entra;
- o Painel Safra não implementa controles paralelos para esses processos.

Logo:
- `ENTRA_RECOVERY = EXTERNAL_CORPORATE_CONTROL`;
- `PRIVILEGED_MFA = EXTERNAL_CORPORATE_CONTROL`;
- esses itens não bloqueiam o encerramento do C04 no escopo da aplicação.

Fechamento:
```text
G5 = PASS
ID-001 = PASS_APP_SCOPE
ID-002 = PASS_APP_SCOPE
AUDIT-001 = PASS
SAFRA-C04 = CONCLUIDO
```

Próxima etapa: SAFRA-C05.


### C05.0.1 — Autoridade de migrations e drift — CONCLUÍDO

- `supabase/migrations` é a única fonte canônica de schema/migrations;
- Drizzle é tooling auxiliar sem autoridade de deploy;
- drift de C00/C04/C05 reconciliado em `supabase_migrations.schema_migrations`;
- nenhuma DDL foi reaplicada durante o repair;
- migrations remotas diretas ficam proibidas fora de exceção formal documentada.
