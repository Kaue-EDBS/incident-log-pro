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
| D-24 | Application criticality = MEDIUM | APPROVED |
| D-25 | replica_enabled = false; backup/restore continua obrigatório | APPROVED |
| D-26 | Política de retenção vinculada ao fim formal da Safra, com anonimização/eliminação posterior quando identidade não for necessária | APPROVED |
| D-27 | Gates G3 e G3.25 fechados; SAFRA-C01 concluído com 0 UNKNOWN material | APPROVED |
| D-28 | SAFRA-C02 concluído; G3.5, THREAT-001 e AUTHZ-001 = PASS | APPROVED |
| D-29 | Vocabulário canônico do domínio congelado em docs/GLOSSARIO_DOMINIO.md | APPROVED |
| D-30 | Cenário, versão e tratativa formalmente distintos; impacto qualitativo/quantitativo formalizado sem score automático | APPROVED |
| D-31 | Quatro cenários CRITICAL não serão inferidos; pendência registrada como GI-SAFRA-001 | APPROVED |
| D-32 | Glossário de domínio v1.1 entregue READY_FOR_C05, com contratos de cardinalidade, estado, snapshot e null/default | APPROVED |
| D-33 | Login funcional exclusivamente via Microsoft Entra ID; Lovable Cloud Auth cria sessão Supabase; login local por senha proibido | APPROVED / HOMOLOGATED |
| D-34 | Role mapping governado no banco e ownership específico separado de papéis administrativos | APPROVED / IMPLEMENTED |
| D-35 | RLS e autorização server-side usam o mesmo predicado corporativo; safra_access removido | APPROVED / IMPLEMENTED |
| D-36 | supabase/migrations é a autoridade canônica; migration C04 capturada e versionada | APPROVED |
| D-37 | Gates C04 não fecham sem evidência explícita do Manual EBSA; G5 parcial e ID-001/ID-002/AUDIT-001 bloqueados por evidência | APPROVED |
| D-38 | Fechamento dos gaps restantes de C04 será executado no ambiente Lovable; recuperação e MFA permanecem dependências do Entra/TI | APPROVED |

## 3. ADRs

### ADR-001 — Evoluir incident-log-pro
**APPROVED**.

### ADR-002 — PRIMARY e REPLICA
PRIMARY Lovable Cloud: **APPROVED**.
REPLICA: **APPROVED = false**.

Não será mantido segundo banco sincronizado.

Isto não elimina a obrigação de backup, restore e recovery testado. Para `service_class=CRITICO`, a estratégia de recuperação deverá provar RTO 30 min e RPO 5 min.

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
**APPROVED — 25/09/2026**.

Autoridade canônica: `supabase/migrations`.

Drizzle permanece como tooling/ORM auxiliar e não pode manter uma segunda trilha concorrente de schema/migrations.

## 4. Decisões humanas abertas

- quatro cenários CRITICAL — `GI-SAFRA-001`, sem evidência nominal suficiente;
- thresholds 2/4/10/11;
- origem do mínimo curva A;
- múltiplas tratativas simultâneas;
- fechamento com passo incompleto/NA;
- matriz exata de permissões por papel;
- canal de notificação;
- aprovadores de novos cenários;
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
| Service class | **CRITICO — APPROVED**; SLO 99,95%; RTO 30 min; RPO 5 min |
| Criticidade da aplicação | **MEDIUM — APPROVED**; independente de service_class=CRITICO e da criticidade dos cenários |
| Auth | Microsoft Entra ID corporativo via SSO aprovado; frontend ainda não implementado; 0 usuários Auth |
| Papéis privilegiados | safra_platform_admin, safra_governance_admin, safra_executive_admin e scenario_owner; service_role permanece técnico/server-side |
| Dados pessoais | **sim** — identidade interna, nome, e-mail, papéis, autoria/auditoria e possíveis dados incidentais em texto livre |
| Integrações | nenhuma integração externa ativa no MVP/código atual; futuras entram por ciclo governado |
| REPLICA | **false — APPROVED**; backup/restore continua obrigatório |
| API | nenhuma API pública; Data API interna existe e é protegida por grants + RLS |
| Regras de domínio | obrigatórias; 17 regras Safra + 4 regras legadas TI registradas; ativação automática de treatment = false |

Este registro descreve o estado atual e não transforma os itens pendentes em decisões aprovadas.


### ADR-011 — Separação entre criticidade de cenário e criticidade da aplicação
**APPROVED — 24/09/2026**.

- `CRITICAL/HIGH/MODERATE` pertence ao domínio dos cenários/protocolos e é suportado pelos materiais-mãe;
- `service_class` e `application_criticality` pertencem à governança técnica do Framework EBSA;
- SLO/RTO/RPO da aplicação não podem ser derivados dos SLAs dos protocolos;
- a lista dos quatro cenários `CRITICAL` permanece aberta em `GI-SAFRA-001`; não há evidência nominal suficiente para classificá-los por inferência.


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

A matriz fina de permissões está **DEFERRED_TO_SAFRA_C04**.


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


### ADR-015 — Application criticality
**APPROVED — 24/09/2026**.

```text
application_criticality = MEDIUM
```

Esta classificação representa o impacto operacional/organizacional do próprio Painel Safra.

Ela é independente de:

- `service_class = CRITICO`;
- `scenario.criticality = CRITICAL/HIGH/MODERATE`.

A combinação `service_class=CRITICO` + `application_criticality=MEDIUM` é uma decisão explícita do projeto.


### ADR-016 — Política de retenção
**APPROVED — 24/09/2026**.

Regra:

- dados pessoais identificáveis permanecem até o encerramento formal da Safra e enquanto necessários para auditoria e pós-mortem;
- após essa finalidade, devem ser eliminados ou anonimizados;
- histórico operacional e métricas podem ser preservados para comparação entre Safras quando não dependerem de identificação pessoal;
- retenção indefinida de identidade não é o padrão do projeto.


### ADR-017 — Fechamento do SAFRA-C01
**APPROVED — 24/09/2026**.

Resultado:

```text
G3 = PASS
G3.25 = PASS
unknown_material_count = 0
SAFRA-C01 = CONCLUIDO
```

Pendências de fases posteriores não foram apagadas. Elas foram classificadas como `DEFERRED_TO_<fase>` e deverão ser retomadas nos respectivos gates.


### ADR-018 — Fechamento do SAFRA-C02
**APPROVED — 25/09/2026**.

Resultado:

```text
SAFRA-C02 = CONCLUIDO
G3.5 = PASS
THREAT-001 = PASS
AUTHZ-001 = PASS
```

O fechamento aprova o threat model, os controles requeridos, os testes derivados e a classificação de riscos residuais. Não antecipa a implementação de RLS/RBAC/RPCs/constraints, que permanece nas fases definidas pelo roadmap.


### ADR-019 — Vocabulário canônico do domínio
**APPROVED — 25/09/2026**.

`docs/GLOSSARIO_DOMINIO.md` passa a ser a fonte canônica para os termos funcionais do Painel Safra.

As distinções cenário/versão/tratativa, gatilho/detecção, protocolo/tratativa, owner/ator da ação, área responsável/impactada, SLA/SLO-RTO-RPO, criticidade/escalonamento e END/CANCEL não podem ser redefinidas silenciosamente.


### ADR-020 — Cenário, versão, tratativa e impacto
**APPROVED — 25/09/2026**.

- cenário identifica o tipo de contingência;
- versão congela o conteúdo válido;
- tratativa representa uma ocorrência real;
- START liga a tratativa à versão vigente;
- impacto qualitativo é descrição contextual;
- impacto quantitativo exige métrica, valor, unidade, fonte e referência temporal;
- cenário pode expressar impacto esperado; tratativa registra impacto observado;
- impacto desconhecido não é zero;
- não existe score agregado, faixas ou thresholds automáticos sem regra de negócio aprovada.


### ADR-021 — Quatro CRITICAL somente com evidência suficiente
**APPROVED — 25/09/2026**.

A revisão das fontes não identificou nominalmente, com evidência suficiente, os quatro cenários que devem receber `CRITICAL`.

- Matriz v3: não possui coluna formal de criticidade;
- reunião 22/09: confirma quatro temas críticos/super pesados, mas não nomeia os quatro;
- Protocolos v2: preliminar; uso textual de “crítico” não equivale à classificação formal.

Decisão:
- não inferir a lista;
- registrar `GI-SAFRA-001`;
- manter classificação produtiva pendente de decisão humana formal;
- quando decidida, aplicar por nova `scenario_version`, sem alterar histórico.


### ADR-022 — Handoff do domínio para C05
**APPROVED — 25/09/2026**.

O `docs/GLOSSARIO_DOMINIO.md` v1.1 é o contrato semântico de entrada do SAFRA-C05.

Decisões derivadas para preservar histórico:
- START congela `scenario_version_id`;
- tratativa persiste `owner_id_at_start` e `responsible_area_id_at_start`;
- áreas potencialmente impactáveis e sistemas associados são relações da versão;
- criticidade pendente não recebe default;
- CANCEL não usa campos de resolução;
- múltiplas tratativas ACTIVE do mesmo cenário não serão proibidas em C05 antes da decisão M01.

Alteração dessas fronteiras exige retorno ao domínio antes de migration.


### ADR-023 — Microsoft Entra ID como único login funcional
**APPROVED / CODE_IMPLEMENTED — 25/09/2026**.

Fluxo alvo:

```text
Microsoft Entra ID
  -> OAuth/SSO
  -> Supabase/Lovable Auth
  -> sessão JWT
  -> Data API / server functions
  -> auth.uid()
```

Regras:
- não existe login local por senha no produto;
- frontend oferece apenas entrada Microsoft;
- backend Auth deve ter Email/Password desabilitado antes da homologação;
- tenant corporativo deve ser restringido na configuração do provider;
- nenhuma credencial/secret do Entra entra no GitHub.

Homologação concluída em 25/09/2026. O provider Microsoft foi configurado via Lovable Cloud Auth e houve autenticação corporativa real bem-sucedida; a identidade resultante foi registrada no Supabase Auth com provider `azure` e `last_sign_in_at` preenchido.


### ADR-024 — Homologação runtime do Microsoft SSO
**APPROVED / HOMOLOGATED — 25/09/2026**.

A implementação efetiva utiliza:

```text
Microsoft Entra ID
  -> Lovable Cloud Auth (provider "microsoft")
  -> tokens OAuth
  -> supabase.auth.setSession(...)
  -> Supabase Auth identity provider = azure
  -> auth.uid()
```

Evidências:
- commit de configuração do provider Microsoft: `68f72ea69cd20d02f88633191b57922cfc710350`;
- usuário real autenticado;
- `auth.users.last_sign_in_at` preenchido;
- `auth.identities.provider = azure`;
- Lovable sincronizado com commits posteriores.

A decisão de produto continua: não oferecer login local por senha.


### ADR-025 — Role mapping sem herança automática de ownership
**APPROVED / IMPLEMENTED — 25/09/2026**.

Fonte de verdade:
- `private.safra_principals`;
- `private.safra_role_grants`.

Papéis:
- `safra_platform_admin`;
- `safra_governance_admin`;
- `safra_executive_admin`;
- `scenario_owner`.

Regras:
- autorização não usa `user_metadata`;
- grants são governados no banco;
- usuário é ligado ao principal por e-mail corporativo e `auth.uid()`;
- nenhum papel administrativo gera ownership de cenário;
- `scenario_owner` apenas qualifica a pessoa para ser owner;
- ownership real depende de vínculo explícito scenario↔user em entidade própria futura.

Implementação privilegiada permanece em schema privado; funções públicas de consulta são `SECURITY INVOKER`.

RLS definitivo ainda será migrado do gate temporário `safra_access` para este modelo no próximo passo do C04.


### ADR-026 — Predicado canônico de autorização corporativa
**APPROVED / IMPLEMENTED — 25/09/2026**.

Predicado base canônico:

```text
auth.uid() presente
AND sessão não anônima
AND provider = azure
AND e-mail corporativo @editoradobrasil.com.br
```

Aplicação:
- RLS da Data API;
- chamadas REST diretas;
- RPC;
- middleware server-side;
- UI indiretamente via Supabase/Data API.

Regras:
- `user_metadata` não é fonte de autorização;
- `app_metadata` é usado apenas para sinal controlado pelo backend, como provider de identidade;
- papéis permanecem em tabelas governadas privadas;
- `safra_access` foi removido e não participa mais da autorização;
- ownership de cenário permanece fora de metadata e fora de herança de role.

A mudança live deverá ser reconciliada com migration canônica no SAFRA-C05.


### ADR-027 — Captura canônica da migration C04
**APPROVED — 25/09/2026**.

Migration:
`20260925133200_c04_role_mapping_and_corporate_rls.sql`.

Ela captura o estado C04 já validado no PRIMARY:
- role mapping;
- identidade corporativa;
- RLS;
- Data API;
- RPC/server authorization equivalente;
- remoção de `safra_access`.

O artefato está fechado em Git. A sincronização do histórico interno do Supabase permanece pendente de migration repair suportado e não deve ser simulada por INSERT manual na tabela interna.


### ADR-028 — Fechamento do C04 via ambiente Lovable
**APPROVED — 25/09/2026**.

Motivo:
- os conectores externos permitiram parte das operações de banco, mas bloquearam mutações necessárias para troca/revogação controlada de roles;
- o Lovable Cloud é o backend PRIMARY do projeto e é o ambiente adequado para concluir esses testes com contexto integral do produto.

Escopo:
- limpar `C04_ID001_TEMP_TEST`;
- validar troca e revogação de roles;
- validar sessão ativa por `session_id`;
- implementar auditoria RBAC compatível com AUDIT-001;
- classificar contas de serviço como N/A no MVP quando aplicável.

Fora do escopo:
- recuperação de acesso e MFA são evidências do Microsoft Entra/TI;
- domínio scenarios/treatments continua nas fases já previstas;
- START/END/CANCEL continuam C08.1/F02.1.

GitHub e `supabase/migrations` permanecem os registros duráveis das mudanças.
