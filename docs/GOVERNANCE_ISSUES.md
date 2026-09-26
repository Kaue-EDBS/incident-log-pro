# GOVERNANCE ISSUES — Painel Safra

**Data de criação:** 25/09/2026  
**Status:** CANÔNICO  
**Objetivo:** registrar lacunas de decisão de negócio sem convertê-las em defaults, inferências ou regras implementadas.

## GI-SAFRA-001 — Definição nominal dos quatro cenários CRITICAL

**Status:** OPEN  
**Tipo:** DOMAIN_DECISION  
**Owner de governança:** safra_governance_admin  
**Fase de origem:** SAFRA-C03  
**Fases afetadas:** C06, M05, F07  
**Bloqueia C03:** não  
**Bloqueia classificação produtiva CRITICAL por cenário:** sim  
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

### Regra de implementação futura

Quando resolvido:

- criticidade entra em nova/publicada `scenario_version`;
- tratativas antigas continuam vinculadas à criticidade da versão congelada no START;
- nenhuma alteração retroativa de histórico.


---

# Pendências formais — WAITING_HUMAN_DECISION

As decisões abaixo não devem ser completadas pela aplicação, por migration ou por LLM sem aprovação humana explícita.

## GI-SAFRA-002 — Thresholds ainda abertos dos cenários 2, 4, 10 e 11

**Status:** WAITING_HUMAN_DECISION  
**Bloqueia:** fechamento completo do SAFRA-C07 para os cenários afetados.

Pendências preservadas literalmente:
- cenário 2: gatilho contém `X h`;
- cenário 4: gatilho contém `X min`;
- cenário 10: limite de lead time/fila não definido numericamente;
- cenário 11: limiar de capacidade não definido numericamente.

Nenhum valor será inferido.

## GI-SAFRA-003 — Fonte oficial do mínimo da curva A — cenário 9

**Status:** WAITING_HUMAN_DECISION  
**Bloqueia:** automação objetiva do gatilho/SLA relacionado à ruptura de estoque.

É necessário definir qual fonte/regra oficial determina o saldo mínimo de um SKU curva A.

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
