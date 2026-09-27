# GOVERNANCE ISSUES — Painel Safra

**Data de criação:** 25/09/2026  
**Status:** CANÔNICO  
**Objetivo:** registrar lacunas de decisão de negócio sem convertê-las em defaults, inferências ou regras implementadas.

## GI-SAFRA-001 — Definição nominal dos quatro cenários CRITICAL

**Status:** OPEN — NON_BLOCKING_C08  
**Tipo:** DOMAIN_DECISION  
**Owner de governança:** safra_governance_admin  
**Fase de origem:** SAFRA-C03  
**Fases afetadas:** C06, M05, F07  
**Bloqueia C03:** não  
**Bloqueia classificação produtiva CRITICAL por cenário:** sim  
**Bloqueia START/C08:** não  
**Bloqueia notificação específica de CRITICAL para diretoria:** sim, até decisão formal

### Pergunta

Quais dos 11 cenários publicados devem possuir:

```text
criticality = CRITICAL
```

A reunião registra que existem **quatro temas críticos/super pesados**, mas não identifica nominalmente os quatro de forma inequívoca.

### Evidências revisadas

#### Matriz v3

A planilha `EDB06 - Matriz Contingencia v3.xlsx` contém, para os 11 cenários:

- cenário;
- gatilho;
- acionamento;
- protocolo;
- área responsável;
- dono;
- áreas impactadas;
- SLA-alvo;
- ferramenta;
- acompanhamento/visibilidade;
- participantes de validação;
- mapeamento.

Não há coluna formal de criticidade e não foram encontrados valores `CRITICAL`, `HIGH` ou `MODERATE`.

#### Reunião de 22/09/2026

A reunião confirma:

- três níveis: crítico, alto e moderado;
- CRITICAL deve comunicar a diretoria já na abertura;
- existem quatro temas descritos como “super pesados”.

Porém, o trecho não nomeia os quatro cenários.

Há ainda um exemplo de integração GoDip/Protheus descrito como “extremamente crítico”, mas esse exemplo contextual não constitui lista formal dos quatro cenários.

#### Protocolos v2

O PDF é explicitamente preliminar. A palavra “crítica” aparece em descrições operacionais, por exemplo “lentidão crítica” no cenário de ERP, mas isso descreve condição/gatilho e não comprova a classificação formal do cenário como `CRITICAL`.

### Decisão atual

**NÃO CLASSIFICAR os quatro cenários por inferência.**

Até decisão humana formal:

- nenhum cenário recebe `CRITICAL` apenas por interpretação da LLM;
- não converter ausência de decisão em `HIGH` ou `MODERATE`;
- não usar palavras como “crítico” dentro do texto do protocolo como prova da classificação;
- não ativar regra de comunicação à diretoria baseada em uma lista inferida;
- C06 deve preservar esta pendência durante seed/reconciliação.

### Critério para fechar o issue

O GI-SAFRA-001 só pode ser encerrado quando existir uma das seguintes evidências:

1. material de negócio aprovado que identifique nominalmente os quatro cenários; ou
2. decisão humana formal de governança registrada em `docs/DECISOES.md`, indicando os quatro cenários.

A decisão deve registrar:

- IDs/números dos quatro cenários;
- nomes;
- fonte/autor da decisão;
- data;
- efeito sobre notificações e governança;
- versão a partir da qual a criticidade passa a valer.

### Resolução do bloqueio C08 — 27/09/2026

Decisão D-44:
- `criticality = NULL` é estado explícito de **criticidade não definida**;
- a ausência não bloqueia START;
- a UX deve mostrar a ausência, sem converter para HIGH/MODERATE;
- comunicação/escalonamento dependente de criticidade não executa sem valor;
- futura classificação exige decisão humana + nova `scenario_version`.

A pergunta nominal dos quatro CRITICAL continua aberta para enriquecimento futuro, mas **não impede C08**.

### Regra de implementação futura

Quando resolvido:

- criticidade entra em nova/publicada `scenario_version`;
- tratativas antigas continuam vinculadas à criticidade da versão congelada no START;
- nenhuma alteração retroativa de histórico.


---

# Pendências formais — WAITING_HUMAN_DECISION

As decisões abaixo não devem ser completadas pela aplicação, por migration ou por LLM sem aprovação humana explícita.

## GI-SAFRA-002 — Thresholds ainda abertos dos cenários 2, 4, 10 e 11

**Status:** OPEN — AUTOMATION_DEFERRED / NON_BLOCKING_C08  
**Bloqueia START/C08:** não.  
**Bloqueia automação do gatilho:** sim.

Pendências preservadas literalmente:
- cenário 2: gatilho contém `X h`;
- cenário 4: gatilho contém `X min`;
- cenário 10: limite de lead time/fila não definido numericamente;
- cenário 11: limiar de capacidade não definido numericamente.

Nenhum valor será inferido.

**Regra aprovada D-45:** enquanto o threshold não existir, SAFRA-02/04/10/11 permanecem disponíveis para START manual. O detector automático fica `NOT_CONFIGURED`.

## GI-SAFRA-003 — Fonte oficial do mínimo da curva A — cenário 9

**Status:** OPEN — AUTOMATION_DEFERRED / NON_BLOCKING_C08  
**Bloqueia START/C08:** não.  
**Bloqueia automação objetiva da ruptura:** sim.

É necessário definir qual fonte/regra oficial determina o saldo mínimo de um SKU curva A.

**Regra aprovada D-46:** enquanto a fonte não existir, SAFRA-09 opera por START manual e nenhuma ruptura é classificada automaticamente.

## GI-SAFRA-004 — Treatments simultâneos do mesmo cenário

**Status:** WAITING_HUMAN_DECISION  
**Fase:** SAFRA-M01.

Decidir se um cenário pode possuir mais de uma tratativa `ACTIVE` simultaneamente. Até decisão, nenhuma constraint de unicidade será criada.

## GI-SAFRA-005 — Canal/provider de notificações e comportamento dos platform admins

**Status:** WAITING_HUMAN_DECISION  
**Fase:** SAFRA-M05.

Definir:
- provider/canal produtivo;
- se platform admins recebem comunicação operacional e em quais condições.

## GI-SAFRA-006 — Janela temporal oficial da “Safra corrente”

**Status:** WAITING_HUMAN_DECISION  
**Fase:** M05/F04.

Definir o período exato usado em métricas, e-mails e análises da Safra corrente.

## GI-SAFRA-007 — Publicação formal do 12º card após ownership

**Status:** WAITING_HUMAN_DECISION  
**Fase:** SAFRA-M10.

Após definição do owner, ainda precisa ser decidido:
- quem aprova protocolo;
- quem aprova SLA;
- quem aprova criticidade;
- quando a primeira versão se torna `PUBLISHED`.

## GI-SAFRA-008 — Janela oficial da governança semanal

**Status:** WAITING_HUMAN_DECISION  
**Fase:** SAFRA-F05.

Definir periodicidade/horário e corte de dados do ritual de governança semanal.


## GI-SAFRA-009 — Mapeamento formal dos eventos dos SLAs textuais

**Status:** RESOLVED_FOR_C08 / PRODUCTIVE_VERSIONING_DEFERRED  
**Fase:** SAFRA-C07/M04.  
**Bloqueia START/C08:** não.

Os 11 cenários possuem SLA textual preservado, mas a estrutura `scenario_slas` exige definição explícita de:

- `start_event`;
- `end_event`;
- alvo estruturado;
- quando um texto representa mais de um relógio.

### Política aprovada D-47

Uma cláusula textual só pode virar `scenario_slas` quando:
- é explicitamente prazo da **tratativa**;
- possui valor e unidade numéricos;
- pode usar `TREATMENT_OPENED` como START;
- pode usar `TREATMENT_RESOLVED` como END;
- não exige criar milestone/evento por interpretação.

Classificação da Matriz v3:
- SAFRA-01 — `tratativa <= 48h` = elegível;
- SAFRA-05 — `tratativa <= 4h` = elegível;
- demais cláusulas = não estruturáveis na versão atual sem nova regra/evento.

Regras:
- detecção/alerta/trigger não vira SLA runtime;
- milestone intermediário não vira END;
- pós-mortem fica em F03;
- “no dia”, “no turno”, “imediata” e similares não viram duração numérica;
- versões PUBLISHED não são reescritas;
- nova estruturação nasce em nova `scenario_version`.

Com isso, a decomposição deixou de ser ambígua para C08. A materialização produtiva dos SLAs elegíveis continua condicionada a nova versão governada.

### Persistência operacional

As issues `GI-SAFRA-001..009` também estão materializadas em `public.governance_issues`.

No banco:
- `OPEN` representa a decisão ainda pendente;
- resolução exige `RESOLVED` + ator + timestamp + texto de resolução;
- ausência de decisão nunca é convertida em default.
