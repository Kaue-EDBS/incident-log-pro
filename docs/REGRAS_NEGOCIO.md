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
Somente owner autorizado do cenário pode iniciar.

### RB-SAFRA-004 — END
Somente owner autorizado pode resolver ou cancelar.

### RB-SAFRA-005 — Atualizadores delegados
Updater pode atualizar andamento, passos e notas, mas não herda START/END.

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

A lista exata dos quatro cenários `CRITICAL` continua `WAITING_HUMAN_DECISION`.

### RB-SAFRA-010 — Protocolo não é chamado
Não exigir workflow de ticket técnico para cada protocolo.

### RB-SAFRA-011 — Escalonamento separado
Comitê técnico/negócio/executivo é relação da tratativa, não status.

### RB-SAFRA-012 — SLA múltiplo
SLA deriva de eventos definidos; duração derivável não vira fonte primária.

### RB-SAFRA-013 — Fonte sem integração
Ausência de fonte nunca aparece como OK. Usar `NO_SOURCE`, `WAITING_INTEGRATION`, `STALE_DATA` ou `UNKNOWN`.

### RB-SAFRA-014 — Novo cenário
Proposta precisa de revisão e aprovação antes da publicação.

### RB-SAFRA-015 — Recorrência
Recorrência é métrica; não promove automaticamente nível de crise.

### RB-SAFRA-016 — Integridade temporal
Eventos não podem violar sequência temporal sem justificativa administrativa auditada.

### RB-SAFRA-017 — Idempotência
Duplo clique, retry ou refresh não pode duplicar abertura, passo, encerramento, cancelamento ou notificação.

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

### Owner
START, END, CANCEL e delegação.

### Updater
Atualiza passos, notas e andamento. Não encerra.

### Viewer / gestão / diretoria
Leitura conforme política.

Papéis funcionais aprovados: `safra_admin`, `scenario_owner`, `scenario_updater`, `manager_viewer`, `executive_viewer` e `viewer`.

Os papéis são independentes e cumulativos, sem herança automática.

A matriz fina de permissões continua **WAITING_HUMAN_DECISION**.

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
15. impacto quantitativo.

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
