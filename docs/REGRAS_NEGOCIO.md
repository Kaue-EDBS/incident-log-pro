# REGRAS DE NEGÓCIO — Painel Safra

> Fonte canônica das regras de domínio.

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
Somente cenário `VALIDATED/PUBLISHED` pode originar tratativa real.

### RB-SAFRA-002 — Ativação humana
Nenhum sinal externo cria automaticamente `treatments` no MVP.

### RB-SAFRA-003 — START
Qualquer usuário autenticado pelo Microsoft Entra ID pode iniciar um protocolo publicado.

O ator do START deve ser persistido pelo backend com timestamp oficial e trilha de auditoria.

O `scenario_owner` não possui exclusividade sobre o START; seu papel é responsabilidade pelo card e execução do protocolo com sua equipe.

### RB-SAFRA-004 — END
Qualquer usuário autenticado pelo Microsoft Entra ID pode encerrar uma tratativa ativa quando a necessidade que motivou a ativação estiver concluída.

O ator do END e o timestamp oficial devem ser persistidos pelo backend.

### RB-SAFRA-005 — Execução durante a tratativa
Não existe papel funcional separado de `scenario_updater`.

O Painel Safra não executa nem controla passo a passo o trabalho operacional do protocolo. O `scenario_owner` conduz o protocolo com sua equipe, conforme o procedimento definido para o card.

O usuário autenticado que ativou ou acompanha o caso pode encerrar a tratativa quando a necessidade estiver concluída.

### RB-SAFRA-006 — Cancelamento auditável
Tratativa incorreta vira `CANCELLED`; exclusão física é proibida no fluxo normal.

### RB-SAFRA-007 — Versão congelada
Ao abrir, persistir `scenario_version_id`. Histórico não é recalculado contra versão futura.

### RB-SAFRA-008 — Área impactada real
Cada tratativa possui conjunto próprio de áreas impactadas.

### RB-SAFRA-009 — Criticidade do cenário
A criticidade é atributo do **cenário/protocolo**, com os valores `CRITICAL`, `HIGH` e `MODERATE`.

Fontes: Matriz v3, Protocolos v2 e decisões da reunião de 22/09.

Esta regra não classifica tecnicamente a aplicação Painel Safra. `service_class`, SLO, RTO, RPO e criticidade da aplicação pertencem ao Framework EBSA e são decisões separadas.

A lista exata dos quatro cenários `CRITICAL` está registrada como `GI-SAFRA-001`. Não há evidência nominal suficiente para inferir os quatro; classificação permanece dependente de decisão humana formal.

### RB-SAFRA-010 — Protocolo não é chamado
Não exigir workflow de ticket técnico para cada protocolo.

### RB-SAFRA-011 — Escalonamento separado
Comitê técnico/negócio/executivo é relação da tratativa, não status.

### RB-SAFRA-012 — SLA múltiplo
SLA deriva de eventos definidos; duração derivável não vira fonte primária.

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
   - acionar Bruno Palhão para escalonamento executivo; ou
   - decidir o ownership por conta própria.

Jiane participa desse fluxo como candidata a owner e não como governança global.

### RB-SAFRA-015 — Recorrência
Recorrência é métrica; não promove automaticamente nível de crise.

### RB-SAFRA-016 — Integridade temporal
Eventos não podem violar sequência temporal sem justificativa administrativa auditada.

### RB-SAFRA-017 — Idempotência
Duplo clique, retry ou refresh não pode duplicar abertura, passo, encerramento, cancelamento ou notificação.

### RB-SAFRA-018 — Administração executiva
Bruno Palhão possui visão executiva de analytics sobre todos os cards e métricas, sem recebimento de e-mails operacionais e sem manutenção técnica da plataforma.

### RB-SAFRA-019 — Analytics por audiência
O Frontend deverá tratar analytics por audiência, com pelo menos três perspectivas a detalhar posteriormente:

- Bruno — todos os cards e métricas;
- donos de card — métricas dos cards sob sua responsabilidade;
- Jair — analytics de governança.

O detalhamento de componentes, filtros, KPIs e visualizações fica reservado à fase de Frontend.

### RB-SAFRA-020 — Identidade do proponente
No 12º card, nome e e-mail devem vir da sessão Microsoft autenticada e não podem depender de digitação livre.

## 3. Regras legadas de TI preservadas

### LEGACY-INC-001
Uma aplicação não pode ter dois incidentes ativos simultaneamente.

### LEGACY-INC-002
Preservar coerência entre failure_started_at, detected_at, response_started_at e recovered_at.

### LEGACY-INC-003
MTTD, MTTR, MTBF, downtime e disponibilidade são derivados de timestamps.

### LEGACY-INC-004
Cronômetro é reconstruído a partir de timestamps persistidos.

## 4. State machine alvo

Estados mínimos:

```text
ACTIVE
RESOLVED
CANCELLED
```

Escalonamento não cria status adicional.

## 5. Autoridade

### Usuário autenticado
Pode visualizar cards e executar START, END e CANCEL conforme regras auditáveis do produto.

### Scenario owner
É o responsável formal pelo card e pelo protocolo operacional junto ao seu time. Recebe as comunicações do próprio card e responde pela estrutura do procedimento, mas não possui exclusividade sobre START/END/CANCEL.

### Papéis administrativos
Os subtipos administrativos e suas responsabilidades estão registrados em `docs/DECISOES.md`. A implementação fina de RBAC permanece deferida ao SAFRA-C04.

## 6. Decisões humanas abertas

1. quatro cenários CRITICAL;
2. thresholds 2/4/10/11;
3. origem do mínimo da curva A;
4. múltiplas tratativas simultâneas;
5. fechamento com passos incompletos/NA;
6. papéis e delegação finais;
7. identity provider;
8. service class;
9. RTO/RPO;
10. REPLICA;
11. canal de notificação;
12. aprovadores de cenários;
13. retenção;
14. janela semanal;
15. métricas/thresholds quantitativos específicos por cenário, quando aplicável.

## 7. Precedência

```text
Matriz v3
 > decisão posterior explícita da reunião de 22/09
 > Protocolos v2
 > consolidação metodológica
 > implementação legada
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
- 0 aceites -> Jair decide diretamente ou aciona Bruno para escalonamento executivo.


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
- impacto qualitativo não redefine criticidade nem escalonamento automaticamente.

### RB-SAFRA-025 — Impacto quantitativo
Impacto quantitativo é uma medição estruturada com métrica, valor, unidade, fonte e referência temporal.

- valor sem fonte não é confirmado;
- desconhecido não vira zero;
- uma tratativa pode ter múltiplas medições;
- não existe score agregado ou threshold automático sem regra de negócio aprovada;
- impacto quantitativo não altera automaticamente criticidade, escalonamento, status ou SLA.


### RB-SAFRA-026 — Criticidade sem inferência
Os quatro cenários `CRITICAL` não podem ser definidos por inferência.

- Matriz v3 sem coluna formal de criticidade;
- reunião confirma existência de quatro temas críticos, mas não os nomeia;
- termos como “crítico” dentro de gatilho/protocolo não equivalem a `scenario_version.criticality = CRITICAL`;
- até resolução de `GI-SAFRA-001`, nenhuma regra produtiva deve assumir a lista dos quatro;
- C06 deve preservar a pendência no seed/reconciliação.


### RB-SAFRA-027 — Engine de SLA determinística
**Status: IMPLEMENTED**

A engine de SLA é determinística e derivada de eventos/timestamps server-side.

Estados canônicos:
- `ON_TRACK`;
- `BREACHED`;
- `COMPLETED_ON_TIME`;
- `COMPLETED_LATE`;
- `NOT_MEASURABLE`;
- `NOT_APPLICABLE` somente quando uma regra explícita declarar não aplicabilidade.

Regras:
- SLA textual sem `start_event`, `end_event` e alvo estruturado permanece `NOT_MEASURABLE`;
- ausência do evento inicial => `NOT_MEASURABLE`;
- evento final exatamente no deadline => `COMPLETED_ON_TIME`;
- breach ocorre somente após o deadline;
- CANCEL antes do end_event não equivale a cumprimento;
- CANCEL após o deadline preserva breach;
- relógio anterior ao start é inválido;
- cálculos usam `timestamptz`;
- alvo estruturado aceita apenas MINUTE/HOUR/DAY e valor > 0;
- a engine não publica SLAs de cenário por inferência.

Implementação:
- `private.safra_sla_target_interval`;
- `private.safra_evaluate_sla`;
- `private.safra_treatment_event_time`;
- `private.safra_treatment_sla_state`.

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
