# Roadmap — Painel Safra / incident-log-pro

**Versão:** 3.0  
**Data:** 30/09/2026  
**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Produto:** Painel Safra — Torre de Governança de Contingências (único produto do repositório, D-50)  
**Regra de execução:** GitHub-first; não reescrever histórico publicado; documentação viva ao fim de cada etapa.

> **Sobre esta versão (D-54).** O roadmap guarda só o **plano**: fases, estado, gates e critérios. Relatos de fases já concluídas, evidências e decisões estão nos documentos donos (mapa abaixo). A versão 2.2 completa, sem alteração, está em `docs/historico/ROADMAP_v2.2_ate_2026-09-30.md`. A numeração das seções foi preservada da v2.2 para não quebrar referências.

---

# 0. Resumo executivo

O `incident-log-pro` nasceu como um monitor de confiabilidade de aplicações de TI, centrado em `applications`, `incidents`, MTTD, MTTR, MTBF, downtime e disponibilidade. Por decisão D-50 (30/09/2026), esse núcleo foi descontinuado: o Painel Safra é o único produto do repositório, e as tabelas e telas do Reliability Monitor foram removidas.

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

---

# Mapa de documentos — quem é dono de cada assunto

| Assunto | Documento dono |
|---|---|
| Onde estamos agora | `docs/STATUS.md` |
| Decisões e ADRs | `docs/DECISOES.md` |
| Pendências de governança (GI) | `docs/GOVERNANCE_ISSUES.md` |
| Ficha técnica do projeto | `docs/PROJECT_PROFILE.yaml` |
| Arquitetura e modelo de dados | `docs/ARQUITETURA.md` |
| Vocabulário e modelo de domínio | `docs/GLOSSARIO_DOMINIO.md` |
| Regras de negócio (RB-SAFRA) | `docs/REGRAS_NEGOCIO.md` |
| Privacidade e ameaças | `docs/PRIVACIDADE_THREAT_MODEL.md` |
| Destino das capacidades | `docs/MATRIZ_PARIDADE.md` |
| Engine de SLA | `docs/C07_SLA_ENGINE.md` |
| Rollback e banco descartável | `docs/ROLLBACK_E_BANCO_DESCARTAVEL.md` |
| Auditorias por fase | `docs/AUDITORIA_*.md` |
| Histórico | `docs/historico/` |

As seções 3 a 10 da v2.2 (estado técnico, PROJECT_PROFILE, pessoas e papéis, decisões, modelo de domínio, baseline dos 11 cenários, dívida de decisão e contratos de regras) foram substituídas por este mapa: o conteúdo vive nos documentos acima.

---

# 11. Estado das fases

> **Atenção (01/10/2026):** as especificações das fases futuras **M01, M04, M05, F01, F02 e F04** foram escritas antes das decisões D-55 a D-73 e ainda não foram revistas. Elas serão auditadas uma a uma, quando chegar a vez de cada fase. Até lá, em caso de conflito, valem `DECISOES.md`, `REGRAS_NEGOCIO.md` e `GLOSSARIO_DOMINIO.md` v2.0.

## EIXO 1 — COMEÇO

| Fase | Tema | Estado | Onde ver |
|---|---|---|---|
| C00 | Baseline e contenção P0 | CONCLUÍDO (+ C00-AUD e C00-AUD2 concluídas) | `AUDITORIA_C00_*` |
| C01 | Documentação canônica e PROJECT_PROFILE | CONCLUÍDO (+ C01-AUD e C01-AUD2 concluídas) | `AUDITORIA_C01_*` |
| C02 | Threat model e abuso de negócio | CONCLUÍDO (+ C02-AUD e C02-AUD2 concluídas em 01/10) | `AUDITORIA_C02_*` |
| C03 | Glossário e modelo de domínio | CONCLUÍDO (+ C03-AUD2 em 01/10, glossário v2.0) | `GLOSSARIO_DOMINIO.md`, `AUDITORIA_C03_*` |
| C04 | Identidade, RBAC e RLS | CONCLUÍDO (+ C04-AUD2 em 01/10) | `DECISOES.md` ADR-023 a 033, `AUDITORIA_C04_*` |
| C05 | Schema v2, migrations e invariantes | CONCLUÍDO (+ C05-AUD2 em 01/10, drift zerado) | `ARQUITETURA.md`, `AUDITORIA_C05_*` |
| C06 | Seed canônico da Matriz v3 | CONCLUÍDO (+ C06-AUD2 em 01/10, planilha = banco) | `AUDITORIA_C06_*`, `data-contracts/` |
| C07 | Engine de SLA | CONCLUÍDO | `C07_SLA_ENGINE.md` |
| C08 | UX do COMEÇO | **EM EXECUÇÃO** — START implementado; homologação com sessão real pendente | abaixo |
| C09 | Fundação operacional | NÃO INICIADO | abaixo |

## EIXO 2 — MEIO

M01 a M11: NÃO INICIADOS. M06 (escalonamento) **CANCELADO** pela D-73; M07 (ponte com incidents de TI) **CANCELADO** pela D-50.

## EIXO 3 — FIM

F01 a F09: NÃO INICIADOS.

---

## SAFRA-C08 — UX do COMEÇO

**Estado: EM EXECUÇÃO — START end-to-end implementado e promovido; pendente homologação UX com sessão Microsoft corporativa real antes das demais telas.**

### Gate pré-C08 — pendências que impediram iniciar a UX

Antes de implementar qualquer tela ou RPC de START, a execução foi pausada para tratar:

1. `GI-SAFRA-001` — criticidade nominal;
2. `GI-SAFRA-002` — thresholds de ativação dos cenários 2/4/10/11;
3. `GI-SAFRA-003` — fonte do mínimo curva A do cenário 9;
4. `GI-SAFRA-009` — decomposição dos SLAs textuais.

Regra do gate:
- nenhuma dessas lacunas pode virar default silencioso;
- nenhuma UI pode apresentar dado inferido como decisão de negócio;
- C08 só começa depois de documentado o comportamento seguro do MVP para os quatro itens.

### Gate pré-C08 — FECHADO

As pendências que interromperam a entrada no C08 foram tratadas assim:
- criticidade ausente = estado explícito, sem default;
- threshold/fonte ausente = automação NOT_CONFIGURED, START manual permitido;
- SLA textual = política formal de estruturação; nenhuma inferência;
- nenhuma versão PUBLISHED foi reescrita.

Migration operacional:
`20260927133000_pre_c08_governance_nonblocking.sql`.

Próximo passo exato:
`SAFRA-C08.1 — regressão/contrato transacional e autorização do START`.

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

### C08.1 — Regressão de autorização do START — IMPLEMENTADO / AUTOMATED PASS

Testar com cenário PUBLISHED real:
- usuário Microsoft corporativo autenticado consegue START;
- anon/outsider não consegue START;
- START por não-owner é permitido conforme regra de negócio;
- scenario_version_id é resolvida e congelada no backend;
- ator e timestamp são server-side;
- payload não consegue trocar owner/criticidade/version_id;
- UI, REST/RPC e server-side produzem decisão equivalente;
- retry/duplo clique não duplica tratativa.


#### Ponto de retomada do próximo chat

O START técnico está pronto:
- migration aplicada no PRIMARY;
- App Smoke 129 PASS;
- Database Disposable 167 PASS;
- pgTAP C08 24/24 PASS;
- deny-by-default preservado;
- Lovable runtime ready no HEAD validado.

O próximo passo NÃO é redesenhar o backend.

Próxima ação:
```text
HOMOLOGAR_START_COM_SESSAO_MICROSOFT_REAL
```

Depois da homologação:
- registrar evidências;
- corrigir somente problemas encontrados;
- continuar as demais telas do SAFRA-C08.


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
- métricas aplicáveis: métricas do protocolo Safra a definir em F04/M05 (MTTD/MTTR/MTBF/disponibilidade de TI retiradas pela D-50);
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

## SAFRA-M06 — Escalonamento e comitê — CANCELADO (D-73)

O escalonamento é feito pelos donos de card, em conjunto, fora do Painel. Texto abaixo mantido só como registro.

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

## SAFRA-M07 — Ponte com incidents de TI — CANCELADO

Cancelado pela D-50 (30/09/2026). O domínio de incidentes de TI foi removido; não há ponte a construir.

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

### Métricas de confiabilidade de TI — RETIRADAS

MTTD, MTTR, MTBF e disponibilidade saíram com a D-50. As métricas do protocolo Safra serão definidas nesta fase, sem inferência.

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

O dia, o horário e o ritual da reunião ficam fora do Painel (D-61). O período coberto pelo resumo é definido no desenho desta fase.

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
2. C01 — concluído (reauditorias concluídas em 01/10);
3. C02 — concluído (reauditorias concluídas em 01/10).

## Bloco 1 — Domínio e backend
4. C03 — concluído;
5. C04 — concluído (C04-AUD2 em 01/10);
6. C05 — concluído (C05-AUD2 em 01/10, drift zerado);
7. C06 — concluído (C06-AUD2 em 01/10);
8. C07 — concluído.

## Bloco 2 — COMEÇO utilizável
9. C08 — UX START (em execução);
10. C09 — backup/restore/capacidade.

## Bloco 3 — MEIO
11. M01 — state machine;
12. M02 — audit trail/acompanhamento mínimo;
13. M03 — timeline;
14. M04 — SLA runtime;
15. M05 — notificações;
16. ~~M06 — escalonamento~~ — cancelado (D-73);
17. ~~M07 — ponte TI~~ — cancelado (D-50);
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
30. F09 — release e operação.

# 20. Gates de produto — melhorados

## P0 — SAFE TO REFACTOR — PASS

- secrets tratados;
- anon bloqueado;
- baseline documentada.

## P1 — DOMAIN READY

**Publication status: NOT_PUBLISHED**

Só passa quando:

- C02 fechado;
- glossário aprovado;
- role model aprovado/implementável;
- schema aprovado;
- 11 cenários reconciliados;
- governance issues catalogadas;
- nenhuma regra crítica depende de suposição.

## P2 — START READY

**Publication status: NOT_PUBLISHED**

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

**Publication status: NOT_PUBLISHED**

Só passa quando:

- timeline confiável;
- eventos auditáveis;
- concorrência tratada;
- SLA runtime correto;
- escalonamento auditável;
- nenhuma dependência de checklist operacional existe.

## P4 — CLOSE READY

**Publication status: NOT_PUBLISHED**

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

> Fonte oficial: `docs/DECISOES.md`. Lista abaixo mantida como referência de planejamento.

| ADR | Decisão | Estado |
|---|---|---|
| ADR-001 | evoluir `incident-log-pro` | APPROVED |
| ADR-002 | Lovable Cloud PRIMARY; REPLICA=false | APPROVED |
| ADR-003 | service_class=CRITICO; SLO 99,95%; RTO 30; RPO 5 | APPROVED |
| ADR-004 | Microsoft Entra ID / SSO | APPROVED |
| ADR-005 | operações críticas via função/RPC transacional | APPROVED — implementação funcional nas fases próprias |
| ADR-006 | Geral = visão, não área | APPROVED |
| ADR-007 | ativação humana no MVP | APPROVED |
| ADR-008 | OTRS fora do MVP | APPROVED |
| ADR-009 | integrações uma por ciclo | PROPOSED |
| ADR-010 | tooling de migrations | APPROVED — supabase/migrations é a autoridade canônica |
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


---

# 28. Próximo passo

Ver `docs/STATUS.md`.
