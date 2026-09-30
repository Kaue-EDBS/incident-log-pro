# MATRIZ DE PARIDADE — Reliability Monitor x Painel Safra

> Controla o destino de cada capacidade durante a evolução do `incident-log-pro`.

Legenda: **KEEP**, **REUSE**, **REDESIGN**, **MERGE**, **REMOVE**, **PARK**, **BUILD**.

## 1. Matriz funcional

| Capacidade | Legado | Destino Safra | Decisão |
|---|---|---|---|
| React/TanStack/Vite | funcional | fundação web | KEEP |
| layout responsivo | funcional | base da nova UX | REUSE |
| applications | funcional | removida pela D-50 | REMOVE |
| incidents | funcional | removida pela D-50 | REMOVE |
| abertura de incidente | funcional | removida; o único START é "Abrir Protocolo" (treatment) | REMOVE |
| cronômetro persistente | funcional | `LiveTimer` reutilizado no START; relógios/SLA | REUSE |
| timestamps | funcional | regra de fuso horário (`src/lib/metrics.ts`) reutilizada; timestamps de incidente removidos | REUSE |
| MTTD/MTTR/MTBF | funcional | removidos pela D-50; métricas do protocolo em F04/M05 | REMOVE |
| downtime/disponibilidade | funcional | removidos pela D-50 | REMOVE |
| histórico de incidentes | funcional | tela removida; histórico auditável Safra a construir | REMOVE + BUILD |
| indicadores | funcional | tela removida; torre corporativa a construir | REMOVE + BUILD |
| filtros | funcional | componente removido; filtros Safra a construir | REMOVE + BUILD |
| dados demo XPTO/ABC/SEP | seed | apagados com as tabelas (D-50) | REMOVE |
| RLS antiga aberta | insegura | removida | REMOVE |
| RLS C00 safra_access | transitória | substituída no C04; tabelas removidas na D-50 | REMOVE |
| client Supabase browser | ativo | leitura/operação autorizada | KEEP |
| mutations críticas no browser | atuais | RPC transacional | REDESIGN |
| modo TV | inexistente | visão executiva | BUILD |
| cenário versionado | inexistente | catálogo | BUILD |
| treatment | inexistente | operação | BUILD |
| scenario owner | inexistente | autorização | BUILD |
| áreas impactadas | inexistente | impacto real | BUILD |
| SLA múltiplo | inexistente | engine temporal | BUILD |
| escalonamento | inexistente | técnico/negócio/executivo | BUILD |
| proposal workflow | inexistente | governança | BUILD |
| trilha Safra | inexistente | auditoria | BUILD |
| identidade corporativa | inexistente | obrigatória | BUILD |
| RBAC definitivo | inexistente | obrigatório | BUILD |
| integrações externas | fora do MVP | uma por ciclo | PARK |

## 2. Segurança

| Item | Antes C00 | Depois C00 | Alvo |
|---|---|---|---|
| `.env` no Git | sim | não | não |
| `anon` lê tabelas | sim | não | não |
| policies abertas | sim | não | não |
| RLS efetiva | não | sim | sim |
| login funcional | não | sim | sim |
| RBAC final | não | sim | sim |
| owner isolation | não | sim | sim |
| START server-side | não | sim — C08 / `safra_start_treatment` | sim |
| END server-side | não | não — DEFERRED_TO_F01/F02 | sim |
| CANCEL server-side | não | não — DEFERRED_TO_F01/F02 | sim |

## 3. Domínio

### Legado — removido pela D-50

```text
Application
 -> Incident
 -> timestamps
 -> reliability metrics
```

Descontinuado em 30/09/2026. Mantido aqui só como registro.

### Alvo

```text
Operational Area
 -> Scenario
 -> Scenario Version
 -> Owner
 -> SLA / Steps / Impact
 -> Treatment
 -> Steps / Events / Escalations
 -> Closure / Governance
```

## 4. Critério de migração

Antes de remover fluxo legado:

1. identificar consumidor;
2. confirmar equivalência;
3. migrar dados/regras;
4. testar;
5. obter evidência;
6. desativar somente depois.

## 5. Pendências de paridade

- 11 cenários — CONCLUÍDO;
- schema v2 — CONCLUÍDO;
- RBAC — CONCLUÍDO no escopo atual;
- login Microsoft — CONCLUÍDO no escopo da aplicação;
- START RPC — CONCLUÍDO no C08;
- END/CANCEL RPCs — DEFERRED_TO_F01/F02;
- timeline;
- SLA engine;
- notificações;
- visão por área;
- governança;
- pós-mortem;
- relatório executivo.

## 5.1 Lição da reauditoria C00-AUD2

Em 27/09/2026 a abertura de incidente foi trocada pelo START Safra sem decisão registrada, e o hook legado foi removido depois por "não ter consumidor". O critério da seção 4 não foi seguido. A partir de agora, remover ou substituir um fluxo exige decisão em `DECISOES.md` antes do código.

## 6. Regra de atualização

Toda funcionalidade adicionada, substituída ou removida deve atualizar esta matriz antes de ser considerada concluída.
