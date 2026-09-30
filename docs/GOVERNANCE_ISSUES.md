# GOVERNANCE ISSUES — Painel Safra

**Data de criação:** 25/09/2026  
**Status:** CANÔNICO — **fonte oficial única das pendências de governança** (C01-AUD2, 30/09/2026)  
**Objetivo:** registrar lacunas de decisão de negócio sem convertê-las em defaults, inferências ou regras implementadas.

## Como este arquivo se relaciona com os outros

- **Este arquivo é o dono** do texto, do status e do critério de fechamento de cada GI.
- `docs/DECISOES.md` só aponta para cá; quando um GI é resolvido, a decisão que o resolve ganha um ID `D-xx` lá.
- A tabela `public.governance_issues` no banco **espelha** o status daqui (`OPEN` ou `RESOLVED`). Se divergir, vale este arquivo e o banco é corrigido.

## Vocabulário de status

| Status | Significa |
|---|---|
| `OPEN — NON_BLOCKING (D-xx)` | pergunta sem resposta, mas existe regra segura aprovada; nada fica travado |
| `OPEN — DEFERRED_TO_<fase>` | pergunta sem resposta, conscientemente adiada para a fase indicada |
| `OPEN — DEFERRED_TO_PRODUCT_V2` | adiada para uma versão futura do produto (V2/V3), fora do MVP |
| `DECIDED (D-xx) — aplicação pendente` | respondida, mas a mudança técnica ainda não foi aplicada; o banco continua `OPEN` até a aplicação |
| `RESOLVED (D-xx)` | respondida por decisão registrada em `DECISOES.md` e aplicada |

Nenhum GI aberto conta como `UNKNOWN`: todos têm regra segura ou fase responsável.

## Resumo

| GI | Pergunta | Status |
|---|---|---|
| 001 | Quais são os 4 cenários CRITICAL? | DECIDED (D-55) — aplicação pendente |
| 002 | Thresholds dos cenários 2, 4, 10 e 11 | OPEN — DEFERRED_TO_PRODUCT_V2 (D-56) |
| 003 | Fonte do mínimo da curva A (cenário 9) | OPEN — NON_BLOCKING (D-46) |
| 004 | Tratativas simultâneas do mesmo cenário | OPEN — DEFERRED_TO_M01 |
| 005 | Canal de notificações e platform admins | OPEN — DEFERRED_TO_M05 |
| 006 | Janela oficial da "Safra corrente" | OPEN — DEFERRED_TO_F04_M05 |
| 007 | Publicação formal do 12º card | OPEN — DEFERRED_TO_M10 |
| 008 | Janela da governança semanal | OPEN — DEFERRED_TO_F05 |
| 009 | Eventos dos SLAs textuais | OPEN — NON_BLOCKING (D-47) |
| 010 | Liberação de START por card | OPEN — NON_BLOCKING (D-51) |

## GI-SAFRA-001 — Definição nominal dos quatro cenários CRITICAL

**Status:** DECIDED (D-55) — aplicação pendente  
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

### Decisão do owner — D-55 — 30/09/2026

Os **11 cenários são CRITICAL**. A comunicação de abertura vai para o **dono do card**; a diretoria fica fora do fluxo por ora. A decisão prevalece sobre a menção a "quatro temas" da reunião de 22/09.

Aplicação técnica pendente: nova `scenario_version` (versão 2) para cada cenário. Ao aplicar, este GI passa a `RESOLVED (D-55)` aqui e no banco.

### Regra de implementação futura

Quando resolvido:

- criticidade entra em nova/publicada `scenario_version`;
- tratativas antigas continuam vinculadas à criticidade da versão congelada no START;
- nenhuma alteração retroativa de histórico.


---

# Demais pendências

As decisões abaixo não devem ser completadas pela aplicação, por migration ou por LLM sem aprovação humana explícita.

## GI-SAFRA-002 — Thresholds ainda abertos dos cenários 2, 4, 10 e 11

**Status:** OPEN — DEFERRED_TO_PRODUCT_V2 (D-56)  
**Decisão do owner (30/09/2026):** o aviso/detecção automática fica para uma versão futura do produto (V2 ou V3). Os números não são necessários agora; START segue manual (D-45).  
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

**Status:** OPEN — NON_BLOCKING (D-46)  
**Bloqueia START/C08:** não.  
**Bloqueia automação objetiva da ruptura:** sim.

É necessário definir qual fonte/regra oficial determina o saldo mínimo de um SKU curva A.

**Regra aprovada D-46:** enquanto a fonte não existir, SAFRA-09 opera por START manual e nenhuma ruptura é classificada automaticamente.

## GI-SAFRA-004 — Treatments simultâneos do mesmo cenário

**Status:** OPEN — DEFERRED_TO_M01  
**Fase:** SAFRA-M01.

Decidir se um cenário pode possuir mais de uma tratativa `ACTIVE` simultaneamente. Até decisão, nenhuma constraint de unicidade será criada.

## GI-SAFRA-005 — Canal/provider de notificações e comportamento dos platform admins

**Status:** OPEN — DEFERRED_TO_M05  
**Fase:** SAFRA-M05.

Definir:
- provider/canal produtivo;
- se platform admins recebem comunicação operacional e em quais condições.

## GI-SAFRA-006 — Janela temporal oficial da “Safra corrente”

**Status:** OPEN — DEFERRED_TO_F04_M05  
**Fase:** M05/F04.

Definir o período exato usado em métricas, e-mails e análises da Safra corrente.

## GI-SAFRA-007 — Publicação formal do 12º card após ownership

**Status:** OPEN — DEFERRED_TO_M10  
**Fase:** SAFRA-M10.

Após definição do owner, ainda precisa ser decidido:
- quem aprova protocolo;
- quem aprova SLA;
- quem aprova criticidade;
- quando a primeira versão se torna `PUBLISHED`.

## GI-SAFRA-008 — Janela oficial da governança semanal

**Status:** OPEN — DEFERRED_TO_F05  
**Fase:** SAFRA-F05.

Definir periodicidade/horário e corte de dados do ritual de governança semanal.


## GI-SAFRA-009 — Mapeamento formal dos eventos dos SLAs textuais

**Status:** OPEN — NON_BLOCKING (D-47)  
**Nota:** a regra D-47 destravou o C08; a pergunta segue aberta porque a materialização dos SLAs elegíveis ainda depende de nova versão governada.  
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

## GI-SAFRA-010 — Liberação de START por card

**Status:** OPEN — NON_BLOCKING (D-51)  
**Fase:** governança futura (a definir).  
**Bloqueia START/C08:** não.

Definir quais dos 11 cards podem ser abertos e por quem. Até decisão, os 11 cenários publicados continuam startáveis por qualquer usuário corporativo autenticado (D-51, D-06). Nenhum card é bloqueado por inferência.

---

### Persistência operacional

As issues `GI-SAFRA-001..010` também estão materializadas em `public.governance_issues`.

No banco:
- `OPEN` representa a decisão ainda pendente;
- resolução exige `RESOLVED` + ator + timestamp + texto de resolução;
- ausência de decisão nunca é convertida em default.
