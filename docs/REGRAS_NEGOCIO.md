# REGRAS DE NEGÓCIO — Painel Safra

> Fonte canônica das regras de domínio. Vocabulário: `docs/GLOSSARIO_DOMINIO.md` v2.0. Revisado na C03-AUD2 (01/10/2026) para as decisões D-50 a D-73.

## 1. Governança

Cada regra deve possuir `rule_id`, versão, fonte, owner, exemplos positivos/negativos, testes e status.

Status:

- DRAFT;
- WAITING_HUMAN_DECISION;
- APPROVED;
- IMPLEMENTED;
- DEPRECATED.

Nenhuma decisão material pode ser completada por suposição da LLM.

## 2. Regras Safra consolidadas

### RB-SAFRA-001 — Cenário validado
Somente cenário `ACTIVE` com versão `PUBLISHED` pode originar tratativa real.

### RB-SAFRA-002 — Ativação humana
Nenhum sinal externo cria automaticamente `treatments` no MVP.

### RB-SAFRA-003 — START
Qualquer usuário corporativo autenticado pelo Microsoft Entra ID pode abrir um protocolo de cenário publicado (D-63), **exceto o dono vigente daquele card** (D-65).

O **solicitante** (D-71) é persistido pelo backend com horário oficial e trilha de auditoria.

Cada pessoa pode ter no máximo um protocolo em andamento por card, contado pela parte dela (D-57/D-66).

### RB-SAFRA-004 — END
O encerramento tem **duas partes** (D-66): a do **solicitante** e a do **dono do card**. Cada parte é fechada pela própria pessoa, logada no próprio perfil (D-64), com autor e horário do servidor. O protocolo só fica Encerrado com as duas partes fechadas. Situações intermediárias: "Aguardando dono" e "Aguardando solicitante" (D-72). Quem concluiu a própria parte pode desfazer em até 5 minutos, enquanto o protocolo estiver em andamento (D-99). Encerrado e Cancelado nunca voltam (D-98).

### RB-SAFRA-005 — Execução durante a tratativa
Não existe papel funcional separado de `scenario_updater`.

O Painel Safra não executa nem controla passo a passo o trabalho operacional do protocolo. O `scenario_owner` conduz o protocolo com sua equipe, conforme o procedimento definido para o card.

O solicitante fecha a parte dele quando a necessidade estiver atendida; o dono do card fecha a parte do dono (RB-SAFRA-004).

### RB-SAFRA-006 — Cancelamento auditável
Tratativa incorreta vira `CANCELLED`, por decisão do **solicitante ou do dono do card**, sempre com motivo (D-66); exclusão física é proibida no fluxo normal. Não há correção pelo admin: cancela e abre de novo (D-100). As áreas impactadas não mudam depois da abertura (D-102) e não há notas (D-103). O histórico do protocolo é visto por quem abriu, pelo dono, pela gestão e pelos platform admins, com o nome de quem fez cada coisa (D-104/D-105). Protocolo sem nenhuma parte concluída é cancelado automaticamente 72 horas depois da abertura (D-101).

### RB-SAFRA-007 — Versão congelada
Ao abrir, persistir `scenario_version_id`. Histórico não é recalculado contra versão futura.

### RB-SAFRA-008 — Área impactada real
Cada tratativa possui conjunto próprio de áreas impactadas.

### RB-SAFRA-009 — Criticidade do cenário
A criticidade é atributo do **cenário/protocolo**, com os valores `CRITICAL`, `HIGH` e `MODERATE`.

Fontes: Matriz v3, Protocolos v2 e decisões da reunião de 22/09.

Esta regra não classifica tecnicamente a aplicação Painel Safra. `service_class`, SLO, RTO, RPO e criticidade da aplicação pertencem ao Framework EBSA e são decisões separadas.

**D-55 (30/09/2026):** os 11 cenários são `CRITICAL` por decisão do owner, aplicado na versão 2 em 01/10/2026; a comunicação de abertura vai ao dono do card, sem a diretoria por ora. A regra anterior, que falava em quatro CRITICAL sem nomeá-los, foi superada.

### RB-SAFRA-010 — Protocolo não é chamado
Não exigir workflow de ticket técnico para cada protocolo. O termo é sempre **protocolo**; "chamado" não é usado no Painel (D-05, reafirmada em 01/10/2026).

### RB-SAFRA-011 — Escalonamento fora do Painel — DEPRECATED (D-73)
O escalonamento é feito pelos donos de card, em conjunto, por avaliação própria, fora do Painel.

### RB-SAFRA-012 — SLA
Nenhum card usa SLA (D-62) e a engine de SLA foi aposentada (D-75). Os prazos da Matriz v3 ficam como texto de referência. A escada de avisos (RB-SAFRA-032) não é SLA.

### RB-SAFRA-013 — Fonte sem integração
Ausência de fonte nunca aparece como OK. Usar `NO_SOURCE`, `WAITING_INTEGRATION`, `STALE_DATA` ou `UNKNOWN`.

### RB-SAFRA-014 — Novo cenário / 12º card
O 12º card é um formulário de proposta, não um protocolo genérico.

Qualquer usuário autenticado pode enviar proposta contendo:

- nome preenchido pela identidade Microsoft;
- e-mail preenchido pela identidade Microsoft;
- título;
- descrição do problema;
- descrição de como o problema afeta a Safra.

A proposta não cria cenário produtivo automaticamente.

Fluxo de governança aprovado:

1. Jair Silva recebe a notificação da proposta;
2. Jair lê e encaminha a proposta para Daniel Garcia, Renato Paulo e Jiane Rodrigues;
3. se exatamente um aceitar, esse usuário torna-se owner do novo card;
4. se dois ou mais aceitarem, Jair realiza o check final e define o owner;
5. se ninguém aceitar, Jair é informado e pode:
   - acionar Bruno Palhão para decidir; ou
   - decidir o ownership por conta própria.
6. o proponente escreve o conteúdo; o Jair aprova; um admin técnico publica; o cenário nasce CRITICAL (D-60);
7. quem propõe não aprova nem publica; proposta do Jair é aprovada pelo Kaue; aprovador e publicador são pessoas diferentes (D-68).

Jiane participa desse fluxo como candidata a owner e não como governança global.

### RB-SAFRA-015 — Recorrência
Recorrência é métrica; não promove automaticamente nível de crise.

### RB-SAFRA-016 — Integridade temporal
Eventos não podem violar sequência temporal sem justificativa administrativa auditada.

### RB-SAFRA-017 — Idempotência
Duplo clique, retry ou refresh não pode duplicar abertura, encerramento de parte, cancelamento ou aviso.

### RB-SAFRA-018 — Administração executiva
Bruno Palhão possui visão executiva de analytics sobre todos os cards e métricas, sem recebimento de e-mails operacionais e sem manutenção técnica da plataforma.

No módulo de analytics (F04), o Bruno terá uma **visão consolidada** de todos os cards (confirmado pelo owner em 01/10/2026, C04-AUD2). Essa visão não dá poder técnico nem de governança: o Bruno não lê a auditoria de papéis nem administra a plataforma (teste `c04_aud2_identity_authz.test.sql`).

### RB-SAFRA-019 — Analytics por audiência
O Frontend deverá tratar analytics por audiência, com pelo menos três perspectivas a detalhar posteriormente:

- Bruno — todos os cards e métricas;
- donos de card — métricas dos cards sob sua responsabilidade;
- Jair — analytics de governança.

O detalhamento de componentes, filtros, KPIs e visualizações fica reservado à fase de Frontend.

### RB-SAFRA-020 — Identidade do proponente
No 12º card, nome e e-mail devem vir da sessão Microsoft autenticada e não podem depender de digitação livre.

## 3. Regras legadas de TI — RETIRADAS

As regras LEGACY-INC-001 a LEGACY-INC-004 (incidente ativo único por aplicação, coerência de timestamps do incidente, MTTD/MTTR/MTBF/downtime/disponibilidade e cronômetro do incidente) deixaram de valer com a D-50 (30/09/2026), junto com as tabelas `applications` e `incidents`. O texto original permanece no histórico Git.

## 4. State machine alvo

Estados técnicos:

```text
ACTIVE
RESOLVED
CANCELLED
```

Situações na interface (D-72): Em andamento, Aguardando dono e Aguardando solicitante (todas `ACTIVE`), Encerrado (`RESOLVED`, as duas partes fechadas) e Cancelado (`CANCELLED`).

## 5. Autoridade

### Usuário autenticado
Pode visualizar cards e abrir protocolos (exceto dos cards de que é dono). Ao abrir, torna-se o **solicitante** daquele protocolo: fecha a parte dele e pode cancelar, com motivo.

### Dono do card (scenario owner)
É o responsável formal pelo card e pelo protocolo operacional junto ao seu time. Recebe os avisos do próprio card, fecha a parte do dono de cada protocolo e pode cancelar, com motivo. Não abre protocolo dos próprios cards (D-65).

### Papéis administrativos
Os subtipos administrativos e suas responsabilidades estão registrados em `docs/DECISOES.md`. A implementação fina de RBAC permanece deferida ao SAFRA-C04.

## 6. Decisões humanas abertas

Fonte oficial: `docs/GOVERNANCE_ISSUES.md` (D-53). Em 01/10/2026 seguem abertas: GI-SAFRA-002 e 003 (V2 do produto), 005 (avisos, M05), 006 (marcação da Safra, F04/M05), 007 (12º card, M10) e 011 (Teams). A lista que existia aqui foi resolvida pelas decisões D-44 a D-73.

## 7. Precedência

```text
decisão humana posterior registrada em DECISOES.md
 > Matriz v3
 > decisão explícita da reunião de 22/09
 > Protocolos v2
 > consolidação metodológica
```

O Framework EBSA pode bloquear solução insegura, mas não inventa regra de negócio.

## 8. Implementação

START/END/CANCEL e demais operações críticas devem preferir RPC/função transacional para combinar autorização, invariantes, persistência, auditoria e idempotência.

## 9. Pronto de regra

Uma regra só está pronta com fonte, owner, decisão, contrato, exemplos, testes, implementação e evidência.


### RB-SAFRA-021 — Governança global
Jair Silva é o único `safra_governance_admin`.

Jiane Rodrigues não possui governança global. Ela recebe comunicações somente dos cards em que é `scenario_owner`.

### RB-SAFRA-022 — Resolução de ownership do 12º card
O ownership de uma proposta do 12º card segue a regra de aceite:

- 1 aceite entre Daniel/Renato/Jiane -> ownership automático para quem aceitou;
- 2 ou mais aceites -> Jair define o owner final;
- 0 aceites -> Jair decide diretamente ou aciona Bruno para decidir.


### RB-SAFRA-023 — Cenário, versão e tratativa
- `scenario` é a identidade estável do tipo de contingência;
- `scenario_version` é a fotografia imutável do conteúdo vigente do cenário;
- `treatment` é a ocorrência real criada por START;
- START congela `scenario_version_id`;
- nova versão não altera tratativa já existente.

### RB-SAFRA-024 — Impacto qualitativo
Impacto qualitativo descreve consequências/contexto operacional.

- cenário/versão pode registrar impacto esperado/potencial;
- tratativa registra impacto efetivamente observado;
- impacto qualitativo não redefine criticidade automaticamente.

### RB-SAFRA-025 — Impacto quantitativo
Impacto quantitativo é uma medição estruturada com métrica, valor, unidade, fonte e referência temporal.

- valor sem fonte não é confirmado;
- desconhecido não vira zero;
- uma tratativa pode ter múltiplas medições;
- não existe score agregado ou threshold automático sem regra de negócio aprovada;
- impacto quantitativo não altera automaticamente criticidade nem status.


### RB-SAFRA-026 — Criticidade sem inferência
**Superada para a lista nominal pela D-55 (os 11 são CRITICAL).** Continua valendo o princípio: criticidade nunca é definida por inferência; só por decisão humana registrada e nova versão de cenário.

Histórico da regra (até 30/09/2026): os quatro cenários `CRITICAL` não podiam ser definidos por inferência.

- Matriz v3 sem coluna formal de criticidade;
- reunião confirma existência de quatro temas críticos, mas não os nomeia;
- termos como “crítico” dentro de gatilho/protocolo não equivalem a `scenario_version.criticality = CRITICAL`;
- até resolução de `GI-SAFRA-001`, nenhuma regra produtiva deve assumir a lista dos quatro;
- C06 deve preservar a pendência no seed/reconciliação.


### RB-SAFRA-027 — Regras de tempo
**Status: IMPLEMENTED (C07-AUD2) — engine de SLA aposentada (D-75)**

- tempos sempre derivados de horários do servidor (`timestamptz`); nenhuma duração gravada como fonte;
- relógio negativo (horário antes da abertura) é recusado;
- horário ausente nunca vira "OK" nem zero;
- escada de avisos (D-76): `private.safra_reminder_steps`;
- tempos de encerramento (D-77): `private.safra_close_times`;
- dia/hora dos relatórios em `America/Sao_Paulo`: `private.safra_local_day`;
- nenhuma regra de tempo é chamável pelo navegador.

### RB-SAFRA-028 — P1–P4 não publicados por inferência
**Status: IMPLEMENTED**

Os gates de produto `P1`, `P2`, `P3` e `P4` não podem receber `PASS` por conclusão automática, inferência de LLM, nome de commit, conclusão de fase ou interpretação subjetiva.

Contrato:
- estado inicial: `NOT_PUBLISHED`;
- `PASS` exige `human_approval=true`;
- `PASS` exige pacote de evidências não vazio;
- todos os critérios do roadmap daquele gate precisam estar explicitamente evidenciados;
- ausência de evidência mantém o gate não publicado;
- CI deve falhar se um gate for marcado como `PASS` sem aprovação/evidência.


### RB-SAFRA-029 — Reconciliação 100% da Matriz v3
**Status: IMPLEMENTED**

Todo dado importado da Matriz v3 deve reconciliar integralmente com o estado canônico publicado antes de qualquer avanço de fase.

Contrato:
- 11 cenários canônicos;
- 18 campos importados por cenário;
- 198 comparações obrigatórias;
- tolerância de divergência = zero;
- qualquer diferença bloqueia o CI;
- mudança de fonte exige novo hash, novo staging, novo preview diff e nova aprovação humana;
- não é permitido alterar simultaneamente o snapshot esperado e o banco para “fazer o teste passar” sem reconhecer formalmente a mudança da fonte.

Campos cobertos:
- number;
- code;
- name;
- trigger;
- activation;
- protocol;
- responsible_area;
- owner;
- impacted_areas;
- sla_target;
- tool;
- monitoring_visibility;
- validation_participants;
- mapping;
- source_row;
- source_file;
- source_sheet;
- source_sha256.

Além da comparação dos 18 campos importados, o gate valida as representações normalizadas no schema:
- nome;
- gatilho;
- acionamento;
- protocolo;
- área responsável;
- owner;
- áreas impactáveis;
- vínculo de ferramenta/sistema.

Resultado esperado:
`MATRIX_V3_RECONCILIATION = 198/198`.


## 10. Regras acrescentadas na C03-AUD2 — 01/10/2026

### RB-SAFRA-030 — Solicitante e dono
O **solicitante** é quem abriu o protocolo (D-71). O **dono do card** não pode ser solicitante do próprio card (D-65). Os dois têm papéis distintos no encerramento (RB-SAFRA-004).

### RB-SAFRA-031 — Encerramento em duas partes
Ver RB-SAFRA-004 e D-66/D-72. Quando o solicitante fecha a parte dele, a trava (D-57) é liberada e os avisos param. Relatórios medem: tempo de encerramento pelo solicitante, pelo dono e o consolidado, até a última parte fechada (D-77); cancelado não conta.

### RB-SAFRA-032 — Escada de avisos
Aos 2h, aos 4h e depois de hora em hora desde a abertura, enquanto o solicitante não fechar a parte dele nem houver cancelamento: pergunta "foi resolvido?" ao solicitante e e-mail ao dono pedindo que cobre o solicitante, só enquanto o dono não tiver fechado a parte dele (D-76). Tempo corrido, 24h por dia. Não é SLA (D-62/D-67). Aviso de abertura ao dono do card e ao Jair (D-58). Teams em aberto (GI-SAFRA-011).

### RB-SAFRA-033 — Safra corrente
Começou em 01/10/2026 e termina quando o Kaue marcar (D-59/D-69). Encerrar exige digitar `ENCERRAR SAFRA` e pode ser desfeito em 7 dias, sem apagar dados nesse prazo (D-70).
