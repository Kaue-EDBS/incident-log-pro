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

## 3. ADRs

### ADR-001 — Evoluir incident-log-pro
**APPROVED**.

### ADR-002 — PRIMARY e REPLICA
PRIMARY Lovable Cloud: **APPROVED**.
REPLICA: **WAITING_HUMAN_DECISION**.

### ADR-003 — Service class
**WAITING_HUMAN_DECISION**. Comparar INTERNO x OPERACIONAL.

### ADR-004 — Identity provider
**WAITING_HUMAN_DECISION**.

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
- papéis e delegações;
- identity provider;
- service class;
- RTO/RPO;
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
| Auth | obrigatório; stack Lovable Cloud/Supabase Auth disponível; login frontend ainda não implementado; 0 usuários Auth |
| Papéis privilegiados | obrigatórios; service_role apenas server-side; papéis funcionais ainda propostos |
| Dados pessoais | **sim** — identidade interna, nome, e-mail, papéis, autoria/auditoria e possíveis dados incidentais em texto livre |
| Integrações | nenhuma integração externa ativa no MVP/código atual; futuras entram por ciclo governado |
| REPLICA | **WAITING_HUMAN_DECISION**; nenhuma REPLICA provisionada |
| API | nenhuma API pública; Data API interna existe e é protegida por grants + RLS |
| Regras de domínio | obrigatórias; 17 regras Safra + 4 regras legadas TI registradas; ativação automática de treatment = false |

Este registro descreve o estado atual e não transforma os itens pendentes em decisões aprovadas.
