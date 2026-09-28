# MATRIZ DE PARIDADE — Reliability Monitor x Painel Safra

> Controla o destino de cada capacidade durante a evolução do `incident-log-pro`.

Legenda: **KEEP**, **REUSE**, **REDESIGN**, **MERGE**, **REMOVE**, **PARK**, **BUILD**.

## 1. Matriz funcional

| Capacidade | Legado | Destino Safra | Decisão |
|---|---|---|---|
| React/TanStack/Vite | funcional | fundação web | KEEP |
| layout responsivo | funcional | base da nova UX | REUSE |
| applications | legado sem adoção | persistência temporária, sem UI | PARK |
| incidents | legado sem adoção | persistência temporária, sem UI | PARK |
| abertura de incidente | removida do frontend | START de treatment em `/tratativas/nova` | REMOVE |
| cronômetro persistente | funcional | relógios/SLA | REUSE |
| timestamps | funcional | eventos temporais | REUSE |
| MTTD/MTTR/MTBF | removidos do runtime | não são métricas canônicas Safra | REMOVE |
| downtime/disponibilidade | removidos do runtime | eventual analytics Safra terá contrato próprio | REMOVE |
| histórico Reliability | removido do frontend | histórico auditável Safra será construído sobre treatments/events | REDESIGN |
| indicadores Reliability | removidos do frontend | analytics Safra terá contrato próprio | REDESIGN |
| filtros Reliability | removidos do frontend | filtros Safra serão reconstruídos no domínio correto | REDESIGN |
| dados demo XPTO/ABC/SEP | seed | não representar operação real | PARK |
| RLS antiga aberta | insegura | removida | REMOVE |
| RLS C00 safra_access | transitória | RBAC final | REDESIGN |
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

### Legado

```text
Application
 -> Incident
 -> timestamps
 -> reliability metrics
```

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

Critério vigente após C03-AUD-03:

1. o Reliability nunca teve adoção operacional real;
2. frontend, hooks e componentes legados podem ser removidos sem preservar uma experiência paralela;
3. contratos úteis e neutros só são reaproveitados quando possuem destino Safra explícito;
4. persistência legada permanece estacionada até migration própria de retirada;
5. nenhuma tabela é apagada apenas porque sua UI deixou de existir;
6. remoção física exige validação de dados, rollback e gates de banco.

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

## 6. Regra de atualização

Toda funcionalidade adicionada, substituída ou removida deve atualizar esta matriz antes de ser considerada concluída.
