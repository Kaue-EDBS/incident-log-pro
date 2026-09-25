# DECISÕES — Painel Safra

> Registro canônico de decisões. Decisões arquiteturais extensas podem ganhar ADR em `docs/adr/`.

## 1. Estados

- **APPROVED**
- **PROPOSED**
- **WAITING_HUMAN_DECISION**
- **SUPERSEDED**

## 2. Decisões consolidadas

| ID | Decisão | Status |
|---|---|---|
| D-01 | Evoluir `incident-log-pro`; não criar app paralelo | APPROVED |
| D-02 | Preservar `applications/incidents` para TI | APPROVED |
| D-03 | Geral é visão agregadora, não área | APPROVED |
| D-04 | Detecção e ativação são conceitos separados | APPROVED |
| D-05 | Protocolo não é chamado | APPROVED |
| D-06 | Owner controla START/END e delega atualização | APPROVED |
| D-07 | Tratativa errada é CANCELLED; não apagar | APPROVED |
| D-08 | Novo cenário exige governança | APPROVED |
| D-09 | Criticidade usa CRITICAL/HIGH/MODERATE | APPROVED; lista crítica pendente |
| D-10 | Recorrência não define crise sozinha | APPROVED |
| D-11 | Comitê é escalonamento, não status | APPROVED |
| D-12 | Lovable Cloud é backend provider e banco é PRIMARY | APPROVED |
| D-13 | Stack do PRIMARY é PostgreSQL/Supabase | APPROVED |
| D-14 | Histórico Git publicado não deve ser reescrito | APPROVED |
| D-15 | Acesso `anon` ao banco interno é proibido | APPROVED |
| D-16 | G5 C00 fecha P0; RBAC final fica no C04/C05 | APPROVED |
| D-17 | Microsoft Entra ID corporativo via SSO será o provedor de identidade | APPROVED |
| D-18 | Família safra_admin e scenario_owner compõem o modelo de responsabilidade | APPROVED |
| D-19 | safra_admin dividido em plataforma, governança e executivo | APPROVED |
| D-20 | 12º card é formulário de proposta de novo cenário, não protocolo genérico | APPROVED |
| D-21 | Jair é o único safra_governance_admin; Jiane recebe somente comunicações dos próprios cards | APPROVED |
| D-22 | 12º card usa aceite dos owners e decisão final/escalonamento pelo Jair | APPROVED |
| D-23 | Service class da aplicação = CRITICO; SLO 99,95%; RTO 30 min; RPO 5 min | APPROVED |

## 3. ADRs

### ADR-001 — Evoluir incident-log-pro
**APPROVED**.

### ADR-002 — PRIMARY e REPLICA
PRIMARY Lovable Cloud: **APPROVED**.
REPLICA: **WAITING_HUMAN_DECISION**.

### ADR-003 — Service class da aplicação
**APPROVED — 24/09/2026**.

A aplicação Painel Safra foi classificada como:

```text
service_class = CRITICO
SLO = 99,95%
RTO = 30 min
RPO = 5 min
```

Esta decisão pertence ao Framework EBSA e classifica o próprio software. Não altera nem deriva da criticidade dos cenários Safra.

### ADR-004 — Identity provider
**APPROVED — 24/09/2026**.

O Painel Safra utilizará **Microsoft Entra ID corporativo via SSO** como provedor de identidade.

Decisões associadas:

- autenticação corporativa via Microsoft;
- não criar login local por senha como caminho funcional do produto;
- Auth identifica o usuário; autorização permanece responsabilidade do RBAC/RLS do Painel Safra;
- configuração de papéis e delegações continua separada no SAFRA-C04.

### ADR-005 — Operações críticas via RPC transacional
**PROPOSED**.

### ADR-006 — Geral como visão
**APPROVED**.

### ADR-007 — Ativação manual no MVP
**APPROVED**.

### ADR-008 — OTRS fora do MVP
**APPROVED para o MVP**; hipótese futura.

### ADR-009 — Integrações uma por ciclo
**PROPOSED**.

### ADR-010 — Tooling de migrations
**WAITING_HUMAN_DECISION**.
Hoje coexistem `supabase/migrations` e Drizzle. C05 deve definir autoridade única.

## 4. Decisões humanas abertas

- quatro cenários CRITICAL;
- thresholds 2/4/10/11;
- origem do mínimo curva A;
- múltiplas tratativas simultâneas;
- fechamento com passo incompleto/NA;
- matriz exata de permissões por papel;
- REPLICA;
- canal de notificação;
- aprovadores de novos cenários;
- retenção;
- janela semanal;
- impacto quantitativo.

## 5. Precedência

```text
fonte primária de negócio
 -> decisão humana posterior registrada
 -> DECISOES / ADR
 -> regra implementada
 -> documentação histórica
```

## 6. Nova decisão

Toda decisão material deve registrar ID, data, contexto, decisão, alternativas, impacto, owner, status, documentos e gates afetados.

Não esconder decisão em prompt, commit ou mensagem de chat.


## 7. Registro de perfil — SAFRA-C01 / 24-09-2026

| Tema | Estado registrado |
|---|---|
| Service class | **WAITING_HUMAN_DECISION** — candidatos INTERNO x OPERACIONAL |
| Criticidade da aplicação | **WAITING_HUMAN_DECISION** — não confundir com criticidade de cenário |
| Auth | Microsoft Entra ID corporativo via SSO aprovado; frontend ainda não implementado; 0 usuários Auth |
| Papéis privilegiados | funcionais aprovados: apenas safra_admin e scenario_owner; service_role permanece técnico/server-side |
| Dados pessoais | **sim** — identidade interna, nome, e-mail, papéis, autoria/auditoria e possíveis dados incidentais em texto livre |
| Integrações | nenhuma integração externa ativa no MVP/código atual; futuras entram por ciclo governado |
| REPLICA | **WAITING_HUMAN_DECISION**; nenhuma REPLICA provisionada |
| API | nenhuma API pública; Data API interna existe e é protegida por grants + RLS |
| Regras de domínio | obrigatórias; 17 regras Safra + 4 regras legadas TI registradas; ativação automática de treatment = false |

Este registro descreve o estado atual e não transforma os itens pendentes em decisões aprovadas.


### ADR-011 — Separação entre criticidade de cenário e criticidade da aplicação
**APPROVED — 24/09/2026**.

- `CRITICAL/HIGH/MODERATE` pertence ao domínio dos cenários/protocolos e é suportado pelos materiais-mãe;
- `service_class` e `application_criticality` pertencem à governança técnica do Framework EBSA;
- SLO/RTO/RPO da aplicação não podem ser derivados dos SLAs dos protocolos;
- a lista dos quatro cenários `CRITICAL` continua `WAITING_HUMAN_DECISION`.


### ADR-012 — Modelo de papéis funcionais
**APPROVED — 24/09/2026**.

Papéis aprovados:

- `safra_admin`;
- `scenario_owner`.

Regras estruturais:

- não existirão papéis funcionais separados de updater, manager viewer, executive viewer ou viewer;
- `safra_admin` não se torna owner de todos os cenários;
- `scenario_owner` depende de vínculo explícito com cenário;
- não existe herança automática entre os dois papéis.

A matriz fina de permissões entre `safra_admin` e `scenario_owner` permanece `WAITING_HUMAN_DECISION`.


### ADR-013 — Subtipos de safra_admin
**APPROVED — 24/09/2026**.

#### safra_platform_admin
Administração técnica da plataforma.

Membros permanentes:
- kaue.pastrello@editoradobrasil.com.br
- amanda.bueno@editoradobrasil.com.br
- vinicius.moraes@editoradobrasil.com.br
- joao.jurado@editoradobrasil.com.br

Amanda, Vinicius e João permanecem com acesso técnico permanente como substitutos de Kaue.

#### safra_governance_admin
Governança funcional de todos os cards e do 12º card.

Membro:
- jair.silva@editoradobrasil.com.br

Responsabilidades:
- supervisionar todos os cards;
- acessar relatórios;
- tomar decisões de governança;
- receber e-mails operacionais;
- conduzir a triagem das propostas do 12º card;
- não executar manutenção técnica da plataforma.

Jiane Rodrigues não exerce mais governança global. Ela permanece como `scenario_owner` dos cards sob sua responsabilidade e recebe apenas as comunicações desses cards.

#### safra_executive_admin
Visão executiva/analytics.

Membro:
- bruno.palhao@editoradobrasil.com.br

Responsabilidades:
- acesso a analytics de todos os cards e métricas;
- não recebe e-mails operacionais;
- não realiza manutenção técnica da plataforma.

A composição final do analytics será decidida posteriormente em regras de negócio e Frontend.

### ADR-014 — 12º card como proposta de novo cenário
**APPROVED — 24/09/2026**.

Qualquer usuário autenticado poderá abrir o formulário do 12º card.

Campos:
- nome — preenchido automaticamente pela identidade Microsoft;
- e-mail — preenchido automaticamente pela identidade Microsoft;
- título — texto livre;
- descrição do problema — texto livre;
- como o problema afeta a Safra — texto livre.

Nome e e-mail não dependem de digitação manual.

A submissão não cria protocolo produtivo automaticamente. O fluxo aprovado é:

1. Jair recebe a notificação da nova proposta;
2. Jair lê a proposta e a encaminha para Daniel Garcia, Renato Paulo e Jiane Rodrigues;
3. se exatamente um deles aceitar, o novo card passa a ser responsabilidade desse owner;
4. se dois ou mais aceitarem, Jair faz o check final e define o owner;
5. se ninguém aceitar, Jair é notificado e pode:
   - acionar Bruno Palhão para escalonamento executivo; ou
   - tomar a decisão de ownership por conta própria.

Jiane participa desse fluxo como candidata a owner, não como governança global.
