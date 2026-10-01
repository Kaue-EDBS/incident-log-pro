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
| D-02 | Preservar `applications/incidents` para TI | SUPERSEDED by D-50 (30/09/2026) |
| D-03 | Geral é visão agregadora, não área | APPROVED |
| D-04 | Detecção e ativação são conceitos separados | APPROVED |
| D-05 | Protocolo não é chamado | APPROVED |
| D-06 | Qualquer usuário Microsoft autenticado pode START/END/CANCEL; owner conduz o protocolo sem exclusividade sobre essas ações | APPROVED — **START ajustado pela D-65; END e CANCEL substituídos pelas D-64/D-66** (01/10/2026) |
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
| D-18 | Família administrativa e scenario_owner compõem o modelo de responsabilidade | SUPERSEDED_BY_D19_D34 |
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
| D-39 | Auditoria pós-Lovable confirma controles internos; ID-001/ID-002 permanecem dependentes de evidência externa do Entra/TI | SUPERSEDED_BY_D40 |
| D-40 | Recuperação e MFA Microsoft são controles corporativos externos à aplicação; C04 pode fechar no escopo do Painel | APPROVED |
| D-41 | Schema v2 canônico materializado no PRIMARY e versionado em supabase/migrations | APPROVED / IMPLEMENTED |
| D-42 | supabase/migrations é a única autoridade de migrations; Drizzle fica sem autoridade de deploy; drift C00/C04/C05 reconciliado | APPROVED / IMPLEMENTED |
| D-43 | Banco descartável padrão = Supabase local via CLI/Docker; rollback pós-C06 = forward fix por padrão | APPROVED / IMPLEMENTED |
| D-44 | Criticidade ausente nos cenários v1 é estado explícito e não bloqueia START; nenhuma classificação será inferida | APPROVED |
| D-45 | Cenários com threshold/fonte de gatilho ausente operam em START manual no MVP; automação permanece desabilitada | APPROVED |
| D-46 | Cenário 9 permanece START manual enquanto não existir fonte oficial do mínimo curva A; ruptura automática fica desabilitada | APPROVED |
| D-47 | SLA textual só vira relógio estruturado quando a cláusula for inequivocamente de tratativa, tiver alvo numérico e puder usar TREATMENT_OPENED → TREATMENT_RESOLVED sem inferência | APPROVED |
| D-48 | Painel Safra é de audiência interna e aceita identidade Microsoft corporativa apenas dos domínios editoradobrasil.com.br e editoradobrasil1.onmicrosoft.com | APPROVED |
| D-49 | Gate de privacidade/base legal exigido antes de usuários reais foi validado e está atendido | APPROVED / SATISFIED |
| D-50 | Reliability Monitor/MTTR descontinuado; Painel Safra é o único produto do `incident-log-pro` | APPROVED |
| D-51 | Os 11 cenários publicados permanecem liberados para START; governança de liberação por card fica para fase futura | APPROVED |
| D-52 | Toda mudança no banco começa como arquivo em `supabase/migrations/`; cada sessão começa comparando o PRIMARY com o repositório | APPROVED |
| D-53 | `GOVERNANCE_ISSUES.md` é a fonte oficial dos GI; `DECISOES.md` indexa e `public.governance_issues` espelha | APPROVED |
| D-54 | `STATUS.md` guarda só o estado atual; histórico vai para `docs/historico/`; `ROADMAP.md` guarda só fases e gates | APPROVED |
| D-55 | Os 11 cenários são CRITICAL; a comunicação de CRITICAL na abertura vai ao dono do card; diretoria fora do fluxo por ora (resolve GI-SAFRA-001) | APPROVED — aplicada em 01/10/2026 |
| D-56 | Detecção/aviso automático de gatilho fica para versão futura do produto (V2/V3); thresholds do GI-SAFRA-002 e mínimo da curva A do GI-SAFRA-003 não são necessários no MVP | APPROVED |
| D-57 | Cada pessoa pode ter no máximo uma tratativa ACTIVE por cenário; pessoas diferentes podem abrir o mesmo cenário (resolve GI-SAFRA-004) | APPROVED — aplicada em 01/10/2026 |
| D-58 | Avisos por e-mail e Teams: dono do card recebe pelos dois; Jair só por e-mail; platform admins não recebem (resolve GI-SAFRA-005) | APPROVED — implementação na M05 |
| D-59 | A Safra corrente é aberta e encerrada por marcação manual no sistema, feita pelo Kaue (resolve GI-SAFRA-006) | APPROVED — implementação na F04/M05 |
| D-60 | 12º card: conteúdo escrito pelo proponente; Jair aprova; platform admin publica; nasce CRITICAL (resolve GI-SAFRA-007) | APPROVED — implementação na M10 |
| D-61 | Dia, horário e ritual da governança semanal ficam fora do Painel; a F05 mantém tela de resumo e registro de ações (resolve GI-SAFRA-008) | APPROVED |
| D-62 | Sem cronômetro de SLA nos cards; escada de avisos 2h/3h/4h, 24h por dia, com pergunta "foi resolvido?" a quem abriu (resolve GI-SAFRA-009) | APPROVED — **escada substituída pela D-67**; "sem SLA" mantido |
| D-63 | Mantida a liberação dos 11 cards para qualquer usuário corporativo autenticado; sem restrição por card (resolve GI-SAFRA-010) | APPROVED — com a exceção da D-65 |
| D-64 | END só por quem abriu o protocolo ou pelo dono do card, cada um logado no próprio perfil; o botão "Resolvido" abre o Painel e exige confirmação | APPROVED — complementada pela D-66 |
| D-65 | Dono de card não abre protocolo dos próprios cards; pode abrir de cards de outros donos | APPROVED — aplicada em 01/10/2026 (migration 20261001150000) |
| D-66 | Encerramento em duas partes (usuário e dono do card, cada um com seu horário); CANCEL por qualquer um dos dois, com motivo; trava D-57 liberada quando o usuário fecha a parte dele | APPROVED — implementação na F01/F02 |
| D-67 | Escada de avisos revista: 2h e 4h, ao dono do card (para cobrar o usuário) e ao usuário ("foi resolvido?"), até o usuário fechar a parte dele; sem Jair e sem aviso de 3h; 4h não é SLA | APPROVED — implementação na M05/F01 |
| D-68 | 12º card com separação de funções: quem propõe não aprova nem publica; proposta do Jair é aprovada pelo Kaue; proposta de admin técnico é publicada por outro admin | APPROVED — implementação na M10 |
| D-69 | A Safra corrente começou em 01/10/2026 e termina quando o Kaue marcar o encerramento | APPROVED |
| D-70 | Encerrar a Safra exige digitar "ENCERRAR SAFRA" e pode ser desfeito em 7 dias, sem apagar dados nesse prazo | APPROVED — implementação com a D-59 |
| D-71 | "Solicitante" é o termo canônico para quem abriu o protocolo (START) | APPROVED |
| D-72 | Situações do protocolo: Em andamento, Aguardando dono, Aguardando solicitante, Encerrado, Cancelado | APPROVED — implementação na F01/F02 |
| D-73 | Escalonamento fica fora do Painel: é feito pelos donos de card, em conjunto, por avaliação própria; SAFRA-M06 cancelado | APPROVED |
| D-74 | Nome do card é o texto literal da Matriz v3; sem nome curto; a forma de exibir fica para a C08 | APPROVED |

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

## 4. Inventário atual de decisões abertas e classificadas

Questão conhecida, registrada e com comportamento seguro/fase responsável **não é UNKNOWN**.

> **Fonte oficial dos GI-SAFRA:** `docs/GOVERNANCE_ISSUES.md` (C01-AUD2, 30/09/2026). A tabela abaixo é um índice; em caso de divergência, vale o `GOVERNANCE_ISSUES.md`.

O inventário vigente é:

| Item | Estado | Tratamento atual |
|---|---|---|
| GI-SAFRA-001 — quatro cenários CRITICAL | RESOLVED (D-55) | os 11 são CRITICAL na versão 2 (migration 20261001120000) |
| GI-SAFRA-002 — thresholds 2/4/10/11 | OPEN / DEFERRED_TO_PRODUCT_V2 (D-56) | D-45 mantém detecção automática `NOT_CONFIGURED`; START manual permitido |
| GI-SAFRA-003 — fonte mínimo curva A | OPEN / DEFERRED_TO_PRODUCT_V2 (D-56) | D-46 mantém automação desligada e START manual |
| GI-SAFRA-004 — múltiplas tratativas simultâneas | RESOLVED (D-57) | uma ACTIVE por pessoa e por cenário; trava ativa (migration 20261001120000) |
| GI-SAFRA-005 — canal/provider de notificações e platform admins | DECIDED (D-58) / IMPLEMENTATION_IN_M05 | e-mail + Teams; destinatários definidos |
| GI-SAFRA-006 — janela temporal oficial da Safra | DECIDED (D-59) / IMPLEMENTATION_IN_F04_M05 | abertura/encerramento manual pelo Kaue |
| GI-SAFRA-007 — publicação formal do 12º card | DECIDED (D-60) / IMPLEMENTATION_IN_M10 | proponente escreve, Jair aprova, platform admin publica |
| GI-SAFRA-008 — janela de governança semanal | RESOLVED (D-61) / OUT_OF_APP_SCOPE | ritual fora do Painel; F05 mantida |
| GI-SAFRA-009 — mapeamento de eventos dos SLAs textuais | RESOLVED (D-62) | sem cronômetro de SLA; escada de avisos (revista pela D-67: 2h e 4h) é requisito da M05/F01 |
| GI-SAFRA-010 — governança de liberação de START por card | RESOLVED (D-63) | 11 cenários liberados para qualquer usuário corporativo |
| métricas do protocolo Safra (substitutas de MTTD/MTTR/MTBF) | DEFERRED_TO_F04_M05 | D-50 retirou as métricas de TI; nenhuma métrica de protocolo é inferida |
| fechamento com passo incompleto/NA | DEFERRED_TO_F01 | não impacta START |
| impacto quantitativo — métricas/thresholds | DEFERRED_TO_F04 | modelo conceitual aprovado; thresholds não inferidos |
| matriz exata de permissões por papel | IMPLEMENTED_C04 | fonte: `private.safra_principals` + `private.safra_role_grants` e matriz C04 |
| audiência/domínios corporativos | IMPLEMENTED_C01_AUD | `editoradobrasil.com.br` e `editoradobrasil1.onmicrosoft.com`; verificados no PRIMARY |
| privacidade/base legal pré-release | SATISFIED_D49 | gate confirmado como atendido em 27/09/2026 |

**Contagem material desconhecida recertificada em 27/09/2026: `0`.** Itens abertos remanescentes estão classificados, possuem comportamento seguro aprovado ou fase futura explícita; portanto não contam como UNKNOWN.

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


## 7. Registro de perfil histórico — SAFRA-C01 / 24-09-2026

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

Este registro descreve o estado observado em 24/09/2026. Para o estado atual, prevalecem `docs/PROJECT_PROFILE.yaml`, `docs/STATUS.md` e as decisões posteriores.


### ADR-011 — Separação entre criticidade de cenário e criticidade da aplicação
**APPROVED — 24/09/2026**.

- `CRITICAL/HIGH/MODERATE` pertence ao domínio dos cenários/protocolos e é suportado pelos materiais-mãe;
- `service_class` e `application_criticality` pertencem à governança técnica do Framework EBSA;
- SLO/RTO/RPO da aplicação não podem ser derivados dos SLAs dos protocolos;
- a lista dos quatro cenários `CRITICAL` permanece aberta em `GI-SAFRA-001`; não há evidência nominal suficiente para classificá-los por inferência.


### ADR-012 — Modelo de papéis funcionais
**SUPERSEDED — 25/09/2026 por ADR-013 / ADR-025.**

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

### ADR-029 — Autorização exclusivamente governada pelo banco e vinculada à sessão viva
**APPROVED — 25/09/2026**.

Decisão:
- `public.safra_is_corporate_user()` passa a exigir, além da identidade corporativa Entra e do JWT não expirado, que o claim `session_id` exista em `auth.sessions` para o mesmo usuário;
- a claim `app_metadata.safra_access` foi descontinuada como mecanismo de acesso, e o server function que a concedia foi removido do frontend;
- o logout passa a ser global, encerrando a sessão no servidor.

Motivo: revogação e desligamento precisam valer imediatamente, sem depender do conteúdo local do token.

### ADR-030 — Trilha de auditoria RBAC append-only (AUDIT-001)
**APPROVED — 25/09/2026**.

Decisão: toda concessão, troca, revogação e remoção de grant governado gera evento em
`private.safra_rbac_audit_events` por trigger server-side, com ator, ação, recurso,
horário do servidor, resultado e `correlation_id`. O histórico é append-only por trigger
(UPDATE/DELETE bloqueados inclusive para sessões privilegiadas). Tentativas negadas são
registradas por `public.safra_log_access_denied`, com autoria e horário resolvidos no servidor.
Secrets e tokens nunca são registrados.

### ADR-031 — Contas de serviço fora de escopo no MVP
**APPROVED — 25/09/2026**.

`SERVICE_ACCOUNT_SCOPE = NOT_APPLICABLE_MVP`. Não existe identidade funcional de serviço
no Painel Safra. O `service_role` é credencial técnica de backend e não é usuário funcional.
A criação de qualquer conta de integração reabre ID-001.


### ADR-032 — Fechamento interno não equivale a fechamento externo
**APPROVED — 25/09/2026**.

A auditoria independente confirmou os controles internos do C04:
- troca/revogação de role;
- sessão viva/revogada;
- auditoria RBAC;
- limpeza do grant temporário;
- ausência de conta de serviço funcional no MVP.

Entretanto:
- ID-001 permanece dependente de evidência do processo corporativo de recuperação de acesso;
- ID-002 permanece dependente de evidência de MFA/Conditional Access dos privilegiados no Microsoft Entra;
- AUDIT-001 está aprovado no escopo de RBAC do C04.

As migrations geradas pelo ambiente Lovable foram espelhadas para `supabase/migrations`; esta continua sendo a fonte canônica.


### ADR-033 — Recuperação e MFA como controles corporativos externos
**APPROVED — 25/09/2026**.

Decisão:
- recuperação de acesso da identidade Microsoft é tratada pela TI diretamente com a Microsoft/Entra;
- bloqueio de conta, MFA e Conditional Access também pertencem à governança corporativa de identidade da TI/Microsoft Entra;
- o Painel Safra não replica, substitui ou administra esses controles.

Consequência:
- `ENTRA_RECOVERY = EXTERNAL_CORPORATE_CONTROL`;
- `PRIVILEGED_MFA = EXTERNAL_CORPORATE_CONTROL`;
- ambos ficam fora da Definition of Done da aplicação para C04;
- isso não constitui auditoria ou certificação do ambiente Entra; apenas define fronteira de responsabilidade.

Com os controles internos aprovados, SAFRA-C04 é considerado concluído no escopo do produto.


### ADR-034 — Schema v2 canônico
**APPROVED / IMPLEMENTED — 25/09/2026**.

Fonte canônica:
`supabase/migrations/20260925170000_c05_schema_v2_canonical_base.sql`.

Decisões:
- o domínio Safra passa a ter schema próprio separado do legado de incidentes TI;
- `private.safra_principals` e `private.safra_role_grants` permanecem a fonte de identidade/responsabilidade global;
- não existe `safra_user_roles` concorrente;
- novas tabelas começam deny-by-default;
- seed e API produtiva ficam para fases seguintes;
- nenhuma criticidade é inferida;
- múltiplos treatments ACTIVE do mesmo cenário não são bloqueados no C05;
- histórico usa FK RESTRICT e estruturas append-only em vez de cascata destrutiva.

Rollback:
- antes de dados produtivos, schema pode ser removido por migration explícita;
- após C06, correções são forward-only e não devem apagar histórico.


### ADR-035 — Autoridade única de migrations e repair do tracking
**APPROVED / IMPLEMENTED — 25/09/2026**.

Decisão:
- `supabase/migrations` é a única fonte canônica para alterações de schema;
- Drizzle permanece somente como ORM/tooling auxiliar;
- `drizzle/migrations` não deve ser usada como trilha de deploy;
- mudanças futuras no PRIMARY devem partir de migration versionada, evitando edição remota ad hoc.

Repair:
- o estado live foi verificado antes da reconciliação;
- C00, C04 e C05 já estavam aplicados no PRIMARY;
- como `supabase migration repair` não estava disponível pelos conectores, foi realizado repair equivalente apenas em `supabase_migrations.schema_migrations`;
- nenhuma DDL foi reaplicada ou revertida.

Versões reconciliadas:
- 20260924212155;
- 20260925133200;
- 20260925164500;
- 20260925164600;
- 20260925164700;
- 20260925170000;
- 20260925173000;
- 20260925210500.

Estado final: GitHub e PRIMARY registram as mesmas 10 migrations canônicas. As duas últimas já estavam fisicamente aplicadas no PRIMARY; o repair apenas registrou seu tracking, sem reexecutar DDL.


### ADR-036 — Rollback e banco descartável
**APPROVED / IMPLEMENTED — 25/09/2026**.

Decisão:
- PRIMARY nunca é ambiente descartável;
- o ambiente descartável padrão é Supabase local via CLI/Docker;
- migrations canônicas são reconstruídas com `supabase db reset --local`;
- testes de banco usam pgTAP via `supabase test db`;
- lint local usa `supabase db lint --local --level error`;
- seed local não contém dados produtivos;
- após C06 e existência de dados reais, rollback destrutivo deixa de ser padrão e correções devem preferir forward fix;
- backup/restore/RTO/RPO permanecem no C09.

Artefatos:
- `docs/ROLLBACK_E_BANCO_DESCARTAVEL.md`;
- `supabase/seed.sql`;
- `supabase/tests/database/c05_schema_v2.test.sql`;
- `.github/workflows/database-disposable-test.yml`.


### ADR-037 — Fechamento do SAFRA-C05
**APPROVED / CLOSED — 25/09/2026**.

Escopo encerrado:
- schema v2 materializado;
- 17 tabelas de domínio com RLS;
- FKs e constraints estruturais;
- timestamps oficiais server-side;
- version freeze;
- histórico append-only;
- integridade temporal;
- ausência de cascade destrutivo;
- CANCEL com motivo obrigatório;
- END/CANCEL somente a partir de ACTIVE;
- idempotência estrutural/double submit validado;
- rollback em banco descartável;
- Data API direta negada;
- migrations reconstruídas do zero;
- lint aprovado;
- tracking de migrations reconciliado com GitHub.

Evidência principal:
- GitHub Actions Run 27 / ID `36189333481` = SUCCESS.

Decisão de fase:
```text
SAFRA-C05 = CONCLUIDO
C05_TECHNICAL_VALIDATION = PASS
MIGRATION_DRIFT = 0
NEXT_PHASE = SAFRA-C06
```

Limites preservados:
- testes funcionais de START permanecem em C08;
- testes funcionais de END/CANCEL permanecem em F01/F02;
- múltiplos treatments ACTIVE por cenário continua decisão M01;
- notificações produtivas permanecem M05;
- criticidade dos quatro cenários permanece em GI-SAFRA-001.


### ADR-038 — Engine de SLA determinística e privada
**APPROVED / IMPLEMENTED — 25/09/2026**.

Decisão:
- o cálculo de SLA é derivado de timestamps/eventos server-side;
- a engine não escolhe `start_event`, `end_event` ou threshold por inferência;
- funções de avaliação permanecem em schema `private`;
- `anon` e `authenticated` não recebem EXECUTE direto;
- uso produtivo ocorrerá via operações server-side/RPCs governadas nas fases próprias;
- SLAs textuais dos 11 cenários atuais permanecem sem estruturação até existir decisão/fonte explícita;
- versões PUBLISHED existentes não serão reescritas para anexar SLA estruturado; nova configuração nasce em nova `scenario_version`.

Estados:
`ON_TRACK`, `BREACHED`, `COMPLETED_ON_TIME`, `COMPLETED_LATE`, `NOT_MEASURABLE`, `NOT_APPLICABLE`.

Regra de borda:
- instante exato do deadline ainda é on-time;
- breach começa apenas após o deadline.

### ADR-039 — P1–P4 nunca recebem PASS por inferência
**APPROVED / IMPLEMENTED — 25/09/2026**.

`P1 DOMAIN READY`, `P2 START READY`, `P3 IN-FLIGHT READY` e `P4 CLOSE READY` são gates de produto, não prioridades de cenário.

Nenhum desses gates pode ser publicado como `PASS` automaticamente.

Fonte canônica:
`docs/product-gates/P1_P4.json`.

Para publicar PASS:
- aprovação humana explícita;
- evidência concreta para cada critério obrigatório do gate;
- todos os critérios do roadmap daquele gate precisam estar comprovados.

Não contam como evidência suficiente:
- conclusão automática de fase;
- nome de commit;
- interpretação da LLM;
- simples ausência de erro no CI.

O CI bloqueia PASS sem essas condições.


### ADR-040 — Reconciliação integral da Matriz v3
**APPROVED / IMPLEMENTED — 26/09/2026**.

A Matriz v3 somente é considerada reconciliada quando todos os campos importados correspondem integralmente ao estado canônico.

Gate:
```text
11 registros
x 18 campos importados
= 198 comparações
EXPECTED = 198/198
TOLERANCE = 0
```

Proteções:
- hash SHA256 da XLSX;
- hash SHA256 do staging;
- exatamente 18 campos canônicos por registro;
- teste pgTAP contra o banco reconstruído;
- validação das relações normalizadas;
- CI bloqueante.

Qualquer alteração futura na fonte exige novo pipeline de staging/diff/aprovação. Não existe reconciliação parcial silenciosa.


### ADR-041 — Reconciliação retrospectiva do C03
**APPROVED — 26/09/2026**.

A auditoria do SAFRA-C03 confirmou que o glossário e o schema v2 preservam as fronteiras semânticas aprovadas.

Correções documentais:
- D-06 foi atualizado para a decisão vigente: qualquer usuário Microsoft autenticado pode START/END/CANCEL; owner não possui exclusividade;
- ADR-012 foi marcado como SUPERSEDED pelo refinamento posterior dos papéis administrativos;
- a decomposição vigente de papéis permanece em safra_platform_admin, safra_governance_admin, safra_executive_admin e scenario_owner;
- nenhuma tabela concorrente safra_user_roles foi criada;
- scenario_owners continua sendo o vínculo explícito de ownership.

A correção preserva histórico e elimina definições concorrentes sem reescrever decisões publicadas silenciosamente.


### ADR-042 — Gate pré-C08 para dados de negócio ausentes
**APPROVED — 27/09/2026**.

A ausência de criticidade nominal, thresholds de gatilho, fonte curva A e decomposição completa de SLA textual **não bloqueia START manual**.

Princípios:
- ausência não vira default;
- automação dependente de dado ausente permanece desligada;
- START manual continua permitido para cenário PUBLISHED;
- UI deve exibir ausência de configuração de forma explícita;
- nenhuma versão PUBLISHED é reescrita retroativamente.

### D-44 / GI-SAFRA-001 — criticidade ausente é estado explícito no MVP
**APPROVED — 27/09/2026**.

Decisão:
- as 11 `scenario_version v1` permanecem com `criticality = NULL`;
- `NULL` significa **criticidade não definida**, não HIGH/MODERATE;
- criticidade não é requisito para START;
- C08 deve exibir “Criticidade não definida”;
- regras de comunicação/escalonamento baseadas em criticidade não executam quando a criticidade está ausente;
- futura classificação exige decisão humana e **nova scenario_version**.

A decisão não identifica artificialmente os quatro CRITICAL. Ela remove a criticidade ausente como bloqueio de START.

### D-45 / GI-SAFRA-002 — thresholds ausentes tornam gatilho manual no MVP
**APPROVED — 27/09/2026**.

Aplica-se a SAFRA-02, SAFRA-04, SAFRA-10 e SAFRA-11.

Enquanto o threshold numérico não existir em fonte aprovada:
- detector automático do gatilho fica **NOT_CONFIGURED**;
- nenhum `X h`, `X min`, limite de fila ou capacidade é inferido;
- cenário continua elegível para START manual por usuário autenticado;
- a frase original da Matriz v3 permanece como evidência;
- futura automação exige threshold versionado e fonte explícita.

### D-46 / GI-SAFRA-003 — cenário 9 manual até fonte oficial do mínimo curva A
**APPROVED — 27/09/2026**.

Enquanto não existir fonte/regra oficial do saldo mínimo:
- nenhuma ruptura é classificada automaticamente;
- nenhum mínimo é calculado ou inventado pelo Painel;
- SAFRA-09 continua disponível para START manual;
- UI deve sinalizar que a detecção automática está não configurada;
- futura automação exige fonte oficial + regra versionada.

### D-47 / GI-SAFRA-009 — política formal de estruturação dos SLAs textuais
**APPROVED — 27/09/2026**.

Uma cláusula textual só é elegível a `scenario_slas` quando cumprir **todos** os critérios:
1. descreve explicitamente prazo da **tratativa**, não detecção, gatilho, milestone intermediário, janela operacional ou pós-mortem;
2. possui alvo numérico explícito;
3. possui unidade temporal explícita;
4. o relógio pode iniciar em `TREATMENT_OPENED`;
5. o relógio pode terminar em `TREATMENT_RESOLVED`;
6. a estruturação não exige criar evento novo por interpretação.

Classificação canônica da Matriz v3:
- **SAFRA-01 — “tratativa ≤ 48h”**: elegível;
- **SAFRA-05 — “tratativa ≤ 4h”**: elegível;
- demais cláusulas: não estruturáveis na versão atual sem evento/regra adicional.

Regras complementares:
- thresholds de detecção permanecem gatilho, não SLA runtime;
- milestones intermediários não são convertidos em END;
- pós-mortem pertence a F03;
- expressões como “no dia”, “no turno”, “imediata” ou apenas resultado esperado não viram duração numérica;
- versões PUBLISHED atuais não são reescritas;
- configuração estruturada futura nasce em nova `scenario_version`.

Com essa política, GI-SAFRA-009 deixa de bloquear C08: START inicia somente os SLAs estruturados existentes na versão; ausência de SLA estruturado é válida e não gera inferência.


### D-48 — audiência interna e domínios corporativos permitidos
**APPROVED — 27/09/2026**.

O Painel Safra é de audiência funcional exclusivamente interna.

Domínios Microsoft corporativos permitidos:
- `editoradobrasil.com.br`;
- `editoradobrasil1.onmicrosoft.com`.

A publicação técnica do endpoint não equivale a acesso funcional público. A aplicação deve exigir identidade Microsoft corporativa pertencente a um dos domínios aprovados. Domínio corporativo não substitui RBAC, role grant ou ownership.

A implementação técnica desta decisão será reconciliada na rodada C01-AUD aberta em 27/09/2026.

### D-49 — gate de privacidade/base legal atendido
**APPROVED / SATISFIED — 27/09/2026**.

Foi confirmado que o enquadramento/base legal e a validação de privacidade previstos antes da liberação para usuários reais já foram realizados.

Consequências:
- a pendência `DEFERRED_TO_PRIVACY_OWNER_BEFORE_REAL_USER_RELEASE` deve ser encerrada documentalmente;
- continuam vigentes minimização, retenção, anonimização/eliminação posterior e as restrições de dados sensíveis;
- esta decisão não altera a política de retenção aprovada.

### D-50 — Reliability Monitor/MTTR descontinuado
**APPROVED — 30/09/2026** — owner: Kaue.

Contexto: a reauditoria C00-AUD2 (`docs/AUDITORIA_C00_REABERTURA_2026-09-30.md`) mostrou que o START do C08 substituiu o fluxo "Novo Incidente" sem decisão registrada, contrariando D-02, `ARQUITETURA.md` §9 e o SAFRA-M07.

Decisão:
- o `incident-log-pro` passa a ter um único produto: o Painel Safra;
- não existe mais "Novo Incidente"; a abertura é sempre "Abrir Protocolo" sobre um cenário publicado;
- o Reliability Monitor inteiro sai: `applications`, `incidents`, MTTD, MTTR, MTBF, downtime, disponibilidade e os dados fictícios XPTO/ABC/SEP;
- as tabelas `public.applications` e `public.incidents` e seus helpers são apagados por migration (`20260930120000_c00_aud2_retire_reliability_monitor.sql`); o conteúdo era apenas seed demo;
- as telas de MTTR (Visão Geral, Incidentes, Aplicações, Indicadores) são removidas; a Visão Geral fica como "Em obras" até existir a versão Safra;
- não haverá app paralelo (D-01 mantida).

Alternativas descartadas: convivência dos dois produtos no mesmo app; separação em apps diferentes.

Impacto:
- D-02 passa a SUPERSEDED;
- SAFRA-M07 (ponte com incidents de TI) é cancelado;
- `MATRIZ_PARIDADE.md`, `ARQUITETURA.md` §9, `ROADMAP.md`, `REGRAS_NEGOCIO.md` e `GLOSSARIO_DOMINIO.md` são atualizados;
- métricas de comunicação/analytics passam a ser métricas do protocolo Safra, a definir em F04/M05 sem inferência;
- o histórico Git e as migrations antigas permanecem intactos como registro.

### D-51 — START liberado para os 11 cenários publicados
**APPROVED — 30/09/2026** — owner: Kaue.

Os 11 cenários publicados continuam startáveis, como já estão no C08. A regra de quais cards podem ser abertos, e por quem, será definida numa governança futura (`GI-SAFRA-010`). Até lá, nenhum card é bloqueado por inferência.

### D-52 — Mudança de banco só a partir de arquivo no repositório
**APPROVED — 30/09/2026** — owner: Kaue.

Contexto: três migrations foram aplicadas no PRIMARY em 28/09/2026 sem arquivo no repositório (achado C00-AUD2-07). O Lovable permite alterar o banco por vários caminhos (chat, editor SQL, conector), e só alguns salvam o arquivo.

Decisão:
- toda alteração de estrutura, permissão ou dado de referência no PRIMARY nasce como arquivo em `supabase/migrations/`, versionado no GitHub **antes** de ser aplicado;
- ao aplicar fora do fluxo automático, a versão é registrada em `supabase_migrations.schema_migrations`;
- no início de cada sessão de trabalho, compara-se a lista de versões do PRIMARY com os arquivos do repositório; qualquer diferença nova é reportada ao owner antes de seguir.

### D-53 — Fonte oficial das pendências de governança
**APPROVED — 30/09/2026** — owner: Kaue.

`docs/GOVERNANCE_ISSUES.md` passa a ser o único dono do texto e do status de cada GI-SAFRA. `DECISOES.md` mantém só o índice. `public.governance_issues` espelha o status. Havendo divergência, vale o `GOVERNANCE_ISSUES.md` e o banco é corrigido por migration (D-52).

### D-54 — STATUS e ROADMAP enxutos
**APPROVED — 30/09/2026** — owner: Kaue.

Aplica a regra de autoridade do C01 ("STATUS não é backlog histórico; ROADMAP não duplica regras"):
- `STATUS.md` descreve só onde o projeto está agora;
- o histórico integral até 30/09/2026 foi movido, sem alteração, para `docs/historico/`;
- `ROADMAP.md` lista fases, estado e gates, e aponta para os documentos donos de regras, decisões, arquitetura e domínio.

### D-55 — Os 11 cenários são CRITICAL; aviso vai ao dono do card
**APPROVED — 30/09/2026** — owner: Kaue. **Resolve GI-SAFRA-001.**

Contexto: a reunião de 22/09/2026 falava em quatro temas "super pesados", sem nomeá-los, e em comunicar a diretoria na abertura de um CRITICAL. A criticidade de todos os cenários estava `NULL` (D-44).

Decisão:
- os 11 cenários publicados (SAFRA-01 a SAFRA-11) têm criticidade `CRITICAL`;
- a comunicação de abertura de um CRITICAL vai para o **dono do card** (owner vigente do cenário);
- a **diretoria fica fora** desse fluxo por ora; incluí-la exige decisão nova;
- esta decisão prevalece sobre a menção a "quatro" da reunião de 22/09, pela regra de precedência (decisão humana posterior registrada).

Aplicação técnica:
- a criticidade é conteúdo da versão publicada, que é imutável; a mudança entra numa nova `scenario_version` (versão 2) de cada cenário, e a versão 1 passa a `RETIRED`;
- tratativas já abertas continuariam na versão em que começaram (hoje não há nenhuma);
- até a aplicação, o banco segue com `criticality = NULL` e o comportamento seguro da D-44;
- a notificação em si só existe quando o SAFRA-M05 for implementado.

### D-56 — Detecção automática de gatilho fora do MVP
**APPROVED — 30/09/2026** — owner: Kaue.

O aviso automático de que um gatilho foi atingido (a partir de integrações como Intelipost, Protheus ou WMS) fica para uma versão futura do produto (V2 ou V3). No MVP, todo START é manual (D-45 continua valendo). Por isso os números de disparo dos cenários 2, 4, 10 e 11 (GI-SAFRA-002) e a fonte do mínimo da curva A do cenário 9 (GI-SAFRA-003) não são necessários agora e ficam adiados, sem valor inferido.

### D-57 — Uma tratativa ativa por pessoa e por cenário
**APPROVED — 30/09/2026** — owner: Kaue. **Resolve GI-SAFRA-004.**

Regra:
- uma pessoa (identidade Microsoft, `auth.uid()`) pode ter tratativas abertas em vários cenários ao mesmo tempo;
- no mesmo cenário, a mesma pessoa só pode ter **uma** tratativa `ACTIVE`; outra só depois de encerrar (END) ou cancelar (CANCEL) a primeira;
- pessoas diferentes podem ter, cada uma, uma tratativa `ACTIVE` do mesmo cenário ao mesmo tempo;
- a retentativa do mesmo START (mesma chave de idempotência) continua devolvendo a mesma tratativa, sem contar como segunda abertura.

Aplicação técnica pendente: trava no banco (unicidade de tratativa `ACTIVE` por pessoa e cenário) e mensagem na tela de Abrir Protocolo. Momento de ligar a trava a confirmar com o owner, porque END/CANCEL (F01/F02) ainda não existem.

### D-58 — Canais e destinatários dos avisos
**APPROVED — 30/09/2026** — owner: Kaue. **Resolve GI-SAFRA-005.**

Canais: **e-mail** (Microsoft 365) e **Microsoft Teams**, ambos enviados pelo servidor (nunca pelo navegador).

Destinatários do aviso de abertura de protocolo:

| Quem | Recebe? | Canal |
|---|---|---|
| Dono do card (owner vigente) | sim | e-mail e Teams |
| Jair (`safra_governance_admin`) | sim, de todos os protocolos | só e-mail |
| Platform admins (time técnico) | não, salvo se forem donos do card | — |
| Bruno (`safra_executive_admin`) | não (sem e-mail operacional) | — |
| Diretoria | fora do fluxo por ora (D-55) | — |

Pré-requisito: autorização no Microsoft 365 da Editora para o Painel enviar e-mail e postar no Teams (TI/administrador do tenant). Detalhes (caixa remetente, canal ou chat do Teams, modelo da mensagem) ficam para a M05. Continuam valendo: envio server-side, template versionado, log de entrega, idempotência e deduplicação por e-mail.

### D-59 — Início e fim da Safra por marcação manual
**APPROVED — 30/09/2026** — owner: Kaue. **Resolve GI-SAFRA-006.**

- A "Safra corrente" não tem datas fixas: ela começa quando o Kaue marca **"Safra iniciada"** no sistema e termina quando ele marca **"Safra encerrada"**.
- Os instantes são gravados pelo servidor, no fuso `America/Sao_Paulo` para exibição (C07, Regra 2), com autor registrado.
- Métricas, e-mails e relatórios "da Safra corrente" usam esse intervalo.
- O encerramento é o marco da política de retenção (ADR-016): a partir dele contam os prazos de eliminação/anonimização de dados pessoais.
- Implementação quando a primeira funcionalidade precisar da janela (F04/M05). Incluir substitutos para a marcação exige decisão nova.

### D-60 — Publicação de cenário novo vindo do 12º card
**APPROVED — 30/09/2026** — owner: Kaue. **Resolve GI-SAFRA-007.**

Complementa ADR-014 (triagem e definição do dono pela proposta do 12º card):

1. **Conteúdo:** o usuário que fez a proposta, por ter a necessidade, escreve o conteúdo do cenário (gatilho, protocolo e prazos).
2. **Aprovação:** o Jair (`safra_governance_admin`) aprova.
3. **Publicação:** depois da aprovação, um platform admin (`safra_platform_admin`) publica a primeira `scenario_version`.
4. **Criticidade:** todo cenário novo nasce `CRITICAL`, como os 11 atuais (D-55).

Sem as etapas 2 e 3 registradas, a proposta não vira cenário publicado (regra anterior mantida). Quem aprova e quem publica ficam gravados na trilha de auditoria.

### D-61 — Ritual da governança semanal fora do Painel
**APPROVED — 30/09/2026** — owner: Kaue. **Resolve GI-SAFRA-008.**

- O **dia, o horário e o ritual** da reunião semanal de governança são responsabilidade da organização, **fora da alçada da aplicação**. O Painel não guarda nem controla a agenda.
- A fase **SAFRA-F05 continua**: tela de resumo (cenários recorrentes, prazos estourados, protocolos ativos, tendência) e registro das ações decididas (`PROCESS_CHANGE`, `MASTER_DATA_FIX`, `CAPACITY_CHANGE`, `PARTNER_ACTION`, `SYSTEM_CHANGE`, `TRAINING`, `NO_ACTION_JUSTIFIED`).
- O período coberto pelo resumo será definido no desenho da F05, sem inferir cadência.

### D-62 — Escada de avisos no lugar de cronômetro de SLA
**APPROVED — 01/10/2026** — owner: Kaue. **Resolve GI-SAFRA-009.**

**Sem cronômetro de SLA.** Nenhum dos 11 cards terá relógio de prazo nem marcação de "prazo estourado" no MVP. `public.scenario_slas` continua vazio; a engine do C07 e a política D-47 ficam disponíveis, mas sem uso nos cards. Os prazos da Matriz v3 permanecem como texto de referência no protocolo.

**Escada de avisos**, igual para os 11 cards, enquanto o protocolo estiver `ACTIVE`:

| Tempo desde a abertura | Aviso para | Pergunta a quem abriu |
|---|---|---|
| 2h | dono do card | "Foi resolvido?" |
| 3h | Jair | "Foi resolvido?" |
| 4h (último) | Jair e dono do card | "Foi resolvido?" |

Regras:
- o tempo conta **24 horas por dia, todos os dias**, inclusive madrugada, fins de semana e feriados ("tempos de Safra");
- canais conforme D-58: dono do card por e-mail e Teams; Jair só por e-mail; quem abriu recebe a pergunta por e-mail e Teams;
- a pergunta traz um link para o protocolo no Painel, com dois botões: **"Resolvido"** encerra o protocolo na hora (END, registrado com autor e horário do servidor); **"Ainda não"** registra a resposta, o protocolo segue aberto e os avisos seguintes continuam;
- quando o protocolo é encerrado ou cancelado, os avisos pendentes deixam de sair;
- depois do aviso de 4h não há novos avisos; o protocolo segue aberto até ser encerrado;
- cada aviso é enviado uma única vez por protocolo (idempotência e log de entrega, conforme M05).

Implementação: depende do envio de avisos (SAFRA-M05) e do encerramento (SAFRA-F01). Não entra no pacote da versão 2 dos cards.

### D-63 — Sem restrição de START por card
**APPROVED — 01/10/2026** — owner: Kaue. **Resolve GI-SAFRA-010.**

A regra da D-51 deixa de ser provisória: qualquer usuário corporativo autenticado (D-48) pode abrir qualquer um dos 11 cenários publicados, respeitada a trava da D-57 (uma tratativa ativa por pessoa e por cenário). Restringir por área, lista de pessoas ou suspensão de card exige decisão nova.

### Aplicação do pacote C01-AUD2 — 01/10/2026

Migration `20261001120000_c01_aud2_scenario_v2_critical_and_start_lock.sql`, com CI verde (App Smoke e Database Disposable) e aplicada no PRIMARY:
- D-55: 11 cenários na versão 2 CRITICAL; 11 versões 1 RETIRED; áreas (20) e sistemas (11) copiados; nenhuma linha em `scenario_slas` (D-62);
- D-57: índice `treatments_one_active_per_person_scenario` e erro `SAFRA_START_ACTIVE_EXISTS` no START;
- GI-SAFRA-001/004/008/009/010 marcados RESOLVED no banco; 002/003/005/006/007 seguem OPEN.

### D-64 — Quem pode encerrar (END) um protocolo
**APPROVED — 01/10/2026** — owner: Kaue. **Substitui a parte de END da D-06.** Nasce da reauditoria C02-AUD2 (ameaça do botão "Resolvido" em e-mail encaminhado).

- Só podem encerrar um protocolo:
  1. **quem abriu** (`treatments.opened_by`);
  2. **o dono do card** vigente (owner atual do cenário).
- Cada um encerra **logado no próprio perfil** (login Microsoft corporativo, sessão viva). A verificação é feita no servidor, pelo `auth.uid()`, nunca pelo link ou pelo navegador.
- O botão **"Resolvido"** do e-mail/Teams (D-62) **não encerra direto**: abre o protocolo no Painel, exige login e um clique de confirmação. Quem não for quem abriu nem o dono vê a mensagem de que não pode encerrar; o link encaminhado não dá poder a terceiros.
- O encerramento grava autor e horário do servidor e para os avisos pendentes (D-62).
- START continua liberado a qualquer usuário corporativo (D-63). CANCEL segue a D-06 até decisão própria.

Implementação: SAFRA-F01 (END) junto com a M05 (avisos).

### D-65 — Dono de card não abre protocolo do próprio card
**APPROVED — 01/10/2026** — owner: Kaue.

- O dono vigente de um card **não pode abrir protocolo daquele card**. O papel dele no protocolo é o de dono, não o de usuário.
- O mesmo dono **pode** abrir protocolo de um card de **outro** dono; nesse protocolo ele é o usuário.
- Por isso, quem abre nunca é o próprio dono do card, e o encerramento em duas partes (D-66) sempre envolve duas pessoas.
- Ajusta a D-63 (liberação geral) e a D-06 (START por qualquer usuário).

Implementação pendente: o START passa a recusar a abertura quando `auth.uid()` é o dono vigente do cenário, com mensagem própria na tela.

### D-66 — Encerramento em duas partes e cancelamento
**APPROVED — 01/10/2026** — owner: Kaue. Complementa a D-64.

**Encerramento (END) em duas partes:**
- o protocolo tem duas partes a fechar: a do **usuário** (quem abriu) e a do **dono do card**;
- cada um fecha a própria parte, logado no próprio perfil (D-64), e cada fechamento grava o **seu horário** (servidor);
- quando o **usuário** fecha a parte dele, a trava da D-57 é liberada para ele naquele card: ele já pode abrir outro protocolo do mesmo card;
- se o **dono** fecha primeiro, o usuário continua travado até fechar a parte dele;
- o protocolo só fica totalmente encerrado quando as duas partes estão fechadas.

**Cancelamento (CANCEL):**
- **qualquer um dos dois** (usuário ou dono do card) pode cancelar, sozinho, logado no próprio perfil;
- **motivo obrigatório** sempre;
- cancelamento não conta como resolvido e preserva o histórico (regras C02/C07 mantidas).

**Relatórios (F04):** três medidas de tempo — tempo de encerramento pelo **dono do card**, tempo de encerramento pelo **usuário** e uma visão **consolidada** mostrando a diferença entre os dois.

Implementação: F01 (END) e F02 (CANCEL). A trava da D-57 hoje usa `status = ACTIVE`; na F01 ela passa a considerar a parte do usuário.

### D-67 — Escada de avisos revista
**APPROVED — 01/10/2026** — owner: Kaue. **Substitui a escada da D-62** (a parte "sem cronômetro de SLA" continua valendo).

| Momento desde a abertura | Condição | Aviso |
|---|---|---|
| 2h | usuário ainda não fechou a parte dele (D-66) | e-mail ao **dono do card**, pedindo que cobre o usuário; pergunta **"foi resolvido?"** ao **usuário** |
| 4h | usuário ainda não fechou a parte dele | idem |
| qualquer momento | usuário fechou a parte dele | **nenhum aviso a mais** |

- O Jair saiu da escada e não há mais aviso de 3h.
- As 4h são só o momento do último aviso. **Não existe "prazo estourado"**: o Painel continua sem cronômetro de SLA (D-62).
- Tempo corrido, 24h por dia, todos os dias (D-62).
- A pergunta ao usuário traz o link para o Painel, onde ele fecha a parte dele logado no próprio perfil (D-64/D-66).
- Canal: **e-mail** decidido. **Teams** em dúvida, registrado como GI-SAFRA-011.
- O aviso de abertura do protocolo segue a D-58 (dono do card e Jair), salvo decisão nova.

### D-68 — Separação de funções no 12º card
**APPROVED — 01/10/2026** — owner: Kaue. Complementa a D-60. Nasce da reauditoria C02-AUD2.

- Quem **propõe** um cenário não pode **aprovar** nem **publicar** a própria proposta.
- Se a proposta for do **Jair** (o aprovador habitual), quem aprova é o **Kaue**.
- Se a proposta for de um **admin técnico**, a publicação é feita por **outro** admin técnico.
- Quem aprova e quem publica também são pessoas diferentes; se o Kaue aprovar, outro admin técnico publica.
- O servidor verifica essas regras pelo `auth.uid()` de cada etapa, e cada etapa fica na trilha de auditoria.

Implementação: SAFRA-M10.

### D-69 — Início da Safra corrente
**APPROVED — 01/10/2026** — owner: Kaue. Aplica a D-59.

- A Safra corrente **começou em 01/10/2026** (fuso `America/Sao_Paulo`).
- Ela **termina quando o Kaue marcar** o encerramento no sistema; não há data prevista.
- Enquanto a marcação da D-59 não existir no sistema (F04/M05), esta decisão é o registro oficial do início. Ao construir a marcação, o primeiro registro deve usar 01/10/2026 00:00 (São Paulo) como início, com referência a esta decisão.
- O encerramento continua sendo o marco da política de retenção (ADR-016).

### D-70 — Proteções contra encerrar a Safra por engano
**APPROVED — 01/10/2026** — owner: Kaue. Complementa a D-59. Nasce da reauditoria C02-AUD2.

- **Confirmação reforçada:** para marcar "Safra encerrada", é preciso digitar `ENCERRAR SAFRA`; um clique não basta.
- **Prazo para desfazer:** por **7 dias** após o encerramento, a Safra pode ser **reaberta**. Nesse prazo, **nenhum dado pessoal é apagado ou anonimizado** pela política de retenção.
- A contagem da retenção (ADR-016) começa só depois desses 7 dias sem reabertura.
- Encerramento e reabertura ficam na trilha de auditoria, com autor e horário do servidor.

Implementação: junto com a marcação da D-59 (F04/M05).

### D-71 — Termo canônico "Solicitante"
**APPROVED — 01/10/2026** — owner: Kaue. Nasce da reauditoria C03-AUD2.

- **Solicitante** é a pessoa que abriu o protocolo (executou o START), identificada pela sessão Microsoft (`treatments.opened_by`).
- Substitui "ator do START" e o uso informal de "usuário" nesse sentido. "Usuário" continua significando qualquer pessoa autenticada no Painel.
- Relatórios e avisos usam: "tempo de encerramento pelo **solicitante**", "tempo de encerramento pelo **dono do card**" e a visão consolidada (D-66).
- O dono do card nunca é o solicitante do próprio card (D-65).

### D-72 — Situações do protocolo com encerramento em duas partes
**APPROVED — 01/10/2026** — owner: Kaue. Detalha a D-66.

| Situação (tela) | Condição | Efeitos |
|---|---|---|
| **Em andamento** | nenhuma parte fechada | trava do solicitante ativa (D-57); escada de avisos ativa (D-67) |
| **Aguardando dono** | só o solicitante fechou a parte dele | trava do solicitante liberada; avisos encerrados |
| **Aguardando solicitante** | só o dono fechou a parte dele | solicitante segue travado e recebendo a pergunta "foi resolvido?" |
| **Encerrado** | as duas partes fechadas | horário de cada parte preservado para os relatórios |
| **Cancelado** | o solicitante ou o dono cancelou, com motivo | histórico preservado; não conta como resolvido |

Persistência (F01): o protocolo guarda separadamente quem fechou e quando, para o solicitante e para o dono. O estado técnico `RESOLVED` só é atingido com as duas partes fechadas; as duas situações "Aguardando" continuam `ACTIVE` no banco, distinguidas pelas partes já fechadas.

### D-73 — Escalonamento fora do Painel
**APPROVED — 01/10/2026** — owner: Kaue. Nasce da reauditoria C03-AUD2.

- O escalonamento de um protocolo (crise técnica, de negócio ou executiva) **não é registrado nem controlado pelo Painel**. Ele é feito pelos **donos de card, em conjunto**, por avaliação própria.
- A fase **SAFRA-M06 (Escalonamento e comitê) é cancelada**.
- O termo "escalonamento" sai do vocabulário do produto (`GLOSSARIO_DOMINIO.md` v2.0).
- A tabela `public.treatment_escalations` e o evento `ESCALATION_CHANGED`, criados no C05, deixam de ter uso. A remoção da tabela segue a D-52 (migration própria) e fica para o pacote da reauditoria do C05.

### D-74 — Nome do card é o texto da Matriz v3
**APPROVED — 01/10/2026** — owner: Kaue. Nasce da reauditoria C06-AUD2.

- O nome de cada card (`scenarios.name`) é o texto **literal** da coluna "Cenário" da Matriz v3, inclusive a quebra de linha dentro dos nomes do SAFRA-04 (`Pedido pago não integrado` + `("limbo" de entrada)`) e do SAFRA-05 (`Tracking falso` + `(status ≠ físico)`).
- Não existe "nome curto" no banco. Listas resumidas (como a do ROADMAP) são apenas referência e não são fonte.
- Como a tela exibe a quebra de linha é decisão de UX, na C08.

### Aplicação do pacote C06-AUD2 — 01/10/2026

- Planilha fornecida pelo owner: assinatura `b0cca8cc…` igual à aprovada; o leitor gerou cópia idêntica à registrada; comparação sem diferenças (`NO_DIFF`); validação `PASS`.
- Conferência de 100% dos campos no PRIMARY: `docs/data-contracts/c06_aud2_reconciliation_2026-10-01.json`.
- Migration `20261001220000_c06_aud2_governance_issue_texts.sql` (CI verde #242/#280; aplicada no PRIMARY, 37 = 37): textos das pendências abertas e da resolução da GI-SAFRA-009 alinhados às decisões vigentes; nenhum status mudou.
- Marcos P1–P4: critérios revistos (D-62/D-66/D-67/D-73); todos seguem `NOT_PUBLISHED`.
