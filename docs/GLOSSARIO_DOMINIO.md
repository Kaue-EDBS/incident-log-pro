# GLOSSÁRIO DE DOMÍNIO — Painel Safra

**Versão:** 2.0  
**Data:** 01/10/2026  
**Status:** CANÔNICO — SAFRA-C03 / C03-AUD2  
**Versão anterior:** `docs/historico/GLOSSARIO_DOMINIO_v1.1_ate_2026-10-01.md` (25/09/2026), preservada sem alteração.  
**O que mudou na 2.0:** decisões D-50 a D-73 (produto único, criticidade, trava por pessoa, encerramento em duas partes, avisos, Safra corrente, solicitante, escalonamento fora do Painel).  
**Autoridade:** este documento congela o vocabulário funcional do Painel Safra. Alteração material exige decisão registrada.

## 1. Objetivo

Evitar que frontend, banco, documentação, testes e usuários usem palavras diferentes para conceitos distintos.

Regra geral:

- um termo canônico deve representar um único conceito;
- sinônimos informais podem aparecer na interface apenas quando não alterarem o significado;
- nomes técnicos de tabelas/campos devem respeitar estas distinções;
- termos deste glossário não podem ser redefinidos silenciosamente em fases posteriores.

---

## 2. Vocabulário congelado

### 2.1 Cenário

**Definição:** identidade estável de uma contingência conhecida e governada pelo Painel Safra.

O cenário representa **o tipo de situação que pode ocorrer**, não uma ocorrência real.

Exemplos de atributos associados:
- código;
- nome;
- área responsável;
- owner vigente;
- versões publicadas;
- áreas potencialmente impactáveis.

**Não é:**
- uma tratativa;
- um chamado;
- um incidente específico;
- uma proposta;
- um protocolo ativo.

**Relação principal:** um cenário pode gerar muitas tratativas ao longo do tempo.

---

### 2.2 Versão de cenário

**Definição:** fotografia versionada e imutável do conteúdo operacional válido de um cenário em determinado período.

Pode conter:
- gatilho;
- modo de detecção;
- modo de ativação;
- criticidade;
- protocolo;
- SLAs;
- observações e regras vigentes.

**Regra:** uma versão publicada não é sobrescrita. Alteração material exige nova versão.

**Efeito operacional:** no START, a tratativa fica vinculada à versão vigente naquele instante por `scenario_version_id`.

**Não é:**
- o cenário em si;
- um histórico editável;
- a tratativa.

---

### 2.3 Gatilho

**Definição:** condição de negócio que torna um cenário elegível para avaliação/acionamento.

O gatilho responde:

> “Qual condição caracteriza este cenário?”

Exemplos conceituais:
- atraso superior ao limite aprovado;
- sistema indisponível no período crítico;
- divergência acima da regra definida.

**Não é:**
- o mecanismo que percebe a condição;
- o START;
- uma notificação.

---

### 2.4 Detecção

**Definição:** forma pela qual o gatilho ou sinal relacionado ao cenário é percebido.

Pode ser:
- MANUAL;
- AUTOMATIC;
- MIXED.

A detecção responde:

> “Como ficamos sabendo que a condição ocorreu?”

**Regra:** detectar não cria tratativa automaticamente no MVP.

**Não é:**
- gatilho;
- START;
- protocolo;
- tratamento.

---

### 2.5 START

**Definição:** ação humana auditável que ativa formalmente um cenário publicado no Painel Safra e cria uma tratativa. Na interface: **"Abrir protocolo"**.

Efeitos mínimos:
- cria a tratativa;
- registra o **solicitante** (2.20) e o horário oficial do servidor;
- congela `scenario_version_id`;
- gera evento de auditoria (`TREATMENT_OPENED`);
- inicia a escada de avisos (2.22) e o aviso de abertura, quando a M05 existir.

**Quem pode:** qualquer usuário Microsoft corporativo autenticado (D-63), **exceto o dono vigente daquele card** (D-65).

**Trava:** cada pessoa tem no máximo uma tratativa em andamento por cenário; outra só depois de fechar a parte dela (D-57/D-66).

**Não inicia cronômetro de SLA** (D-62).

**Não é:**
- detecção;
- gatilho;
- aprovação de cenário;
- abertura de chamado (D-05);
- início informal do trabalho operacional fora do Painel.

---

### 2.6 Protocolo

**Definição:** procedimento operacional definido para responder ao cenário.

O protocolo pertence ao conhecimento do cenário/versionamento e é executado pelo owner com sua equipe.

**Regra central:** o Painel Safra governa a contingência, mas não executa nem controla checklist passo a passo do protocolo.

**Não é:**
- chamado;
- tratativa;
- checklist do Painel;
- status.

---

### 2.7 Tratativa

**Definição:** instância real e auditável criada quando um cenário publicado recebe START. Na interface: **"protocolo"** (aberto).

A tratativa representa **uma ocorrência operacional específica daquele cenário** dentro do Painel.

**Situações (D-72):**

| Situação | Condição |
|---|---|
| Em andamento | nenhuma parte fechada |
| Aguardando dono | só o solicitante fechou a parte dele |
| Aguardando solicitante | só o dono fechou a parte dele |
| Encerrado | as duas partes fechadas |
| Cancelado | o solicitante ou o dono cancelou, com motivo |

Pode possuir:
- versão congelada;
- solicitante;
- dono no momento do START (snapshot);
- horários de abertura e de fechamento de cada parte;
- áreas efetivamente impactadas;
- eventos;
- avisos enviados;
- END ou CANCEL.

**Não é:**
- cenário;
- protocolo como procedimento (2.6);
- proposta;
- chamado externo.

---

### 2.8 Owner (dono do card)

**Definição:** pessoa formalmente responsável pelo card/cenário e pela condução do protocolo operacional com sua equipe. Na interface: **"dono do card"**.

O dono:
- responde pelo conteúdo/procedimento do card;
- recebe o aviso de abertura e a escada de avisos do próprio card (D-58/D-67);
- fecha a **parte do dono** de cada tratativa do seu card (D-66);
- pode cancelar a tratativa, com motivo (D-66);
- participa da governança relacionada ao cenário.

**Regras:**
- ownership depende de vínculo explícito com o cenário;
- o dono **não abre** protocolo dos próprios cards; pode abrir de cards de outros donos, e nesse caso é o solicitante (D-65);
- platform/governance/executive admin não viram dono por herança.

**Não é:**
- sinônimo de administrador;
- o solicitante do próprio card.

---

### 2.9 Área responsável

**Definição:** área organizacional que responde primariamente pelo cenário.

É atributo do catálogo do cenário.

**Não é:**
- área necessariamente impactada em toda ocorrência;
- owner individual;
- visão “Geral”.

---

### 2.10 Área impactada

**Definição:** área que sofre ou pode sofrer consequência da contingência.

Existem dois níveis distintos:

1. **área potencialmente impactável** — relação prevista no catálogo do cenário;
2. **área efetivamente impactada** — relação registrada na tratativa real.

**Regra:** “Geral” é visão agregadora e não área operacional.

---

### 2.11 SLA

**Definição:** compromisso temporal medido entre eventos definidos (`start_event`, `end_event`, alvo, unidade, aplicabilidade).

**No MVP, nenhum card usa SLA (D-62).** Não existe cronômetro de prazo nem "prazo estourado" nos 11 cards. Os prazos da Matriz v3 permanecem apenas como **texto de referência** no protocolo. As 4 horas da escada de avisos (2.22) **não são SLA**.

O conceito, a tabela `scenario_slas` e a engine do C07 continuam no domínio para uso futuro, por decisão nova.

**Não é:**
- SLO do software;
- RTO/RPO;
- criticidade;
- aviso (2.22).

---

### 2.12 Criticidade

**Definição:** classificação de severidade do cenário/protocolo para fins de governança e comunicação.

Valores canônicos: CRITICAL, HIGH, MODERATE.

**Situação atual (D-55):** os 11 cenários são **CRITICAL** (versão 2). Cenário novo vindo do 12º card nasce CRITICAL (D-60).

**Regra:** criticidade é atributo versionado do cenário; mudar exige nova versão.

**Não é:**
- `service_class` ou `application_criticality` da aplicação;
- status da tratativa.

---

### 2.13 END

**Definição:** ação humana auditável que fecha uma **parte** da tratativa porque a necessidade foi atendida. Na interface: **"Encerrar"** / botão **"Resolvido"**.

O END tem **duas partes** (D-66):
- **parte do solicitante** — fechada pelo solicitante;
- **parte do dono** — fechada pelo dono do card.

Regras:
- cada parte é fechada pela própria pessoa, logada no próprio perfil (D-64);
- o botão "Resolvido" do aviso só abre o Painel e pede confirmação;
- cada parte grava autor e horário do servidor;
- quando o solicitante fecha a parte dele, a trava (D-57) é liberada e os avisos param (D-67);
- a tratativa só fica **Encerrada** quando as duas partes estão fechadas.

**Não é:**
- CANCEL;
- exclusão.

---

### 2.14 CANCEL

**Definição:** ação humana auditável usada quando a tratativa não deve ser considerada resolução válida, por exemplo abertura incorreta ou duplicada. Na interface: **"Cancelar"**.

Regras (D-66):
- **o solicitante ou o dono** pode cancelar, sozinho, logado no próprio perfil;
- motivo **sempre obrigatório**;
- preserva o histórico; grava autor e horário;
- não conta como resolvido.

**Não é:**
- END;
- delete físico;
- forma de parar avisos sem justificativa.

---

### 2.15 Escalonamento — FORA DO PAINEL

**D-73 (01/10/2026):** o escalonamento é feito pelos **donos de card, em conjunto**, por avaliação própria, **fora do Painel**. O termo não faz parte do vocabulário do produto e a fase M06 foi cancelada.

---

### 2.16 Pós-mortem

**Definição:** análise posterior ao encerramento de uma contingência para registrar causa, aprendizado e ações preventivas quando exigido pela regra do cenário ou pela governança.

Pode possuir:
- owner;
- prazo;
- conclusão;
- causa-raiz;
- ação preventiva;
- prazo próprio, quando o protocolo do card prever (por exemplo, "pós-mortem ≤ 48h"), como texto de referência; não é SLA medido no MVP (D-62).

**Não é:**
- requisito automático de todas as tratativas, salvo decisão de negócio;
- substituto do END;
- nota livre sem governança.

---

### 2.17 Recorrência

**Definição:** repetição observável de tratativas relacionadas ao mesmo cenário dentro de uma janela de análise.

É usada para:
- analytics;
- governança semanal;
- identificação de padrão;
- priorização de melhoria.

**Regra:** recorrência é indicador e não promove crise/escalonamento automaticamente.

**Não é:**
- criticidade;
- breach de SLA;
- nova categoria de status.

---

### 2.18 Proposta de cenário

**Definição:** submissão de um possível novo cenário pelo 12º card para avaliação de governança.

A proposta:
- possui **proponente** identificado pela sessão Microsoft;
- registra problema e impacto na Safra;
- passa por triagem e definição do dono (ADR-014);
- tem o conteúdo escrito pelo próprio proponente (D-60).

**Regra:** proposta não é cenário produtivo e não aceita START.

**Não é:**
- cenário publicado;
- tratativa.

---

### 2.19 Publicação de cenário

**Definição:** ato de governança que torna uma versão de cenário elegível para uso operacional.

Fluxo (D-60/D-68): proponente escreve → **Jair aprova** → **um admin técnico publica**. Quem propõe não aprova nem publica; proposta do Jair é aprovada pelo Kaue; aprovador e publicador são pessoas diferentes. Nasce CRITICAL.

Somente cenário/versão em estado publicado pode receber START.

---

### 2.20 Solicitante

**Definição (D-71):** pessoa que abriu o protocolo (executou o START). Fonte: `treatments.opened_by`.

O solicitante:
- fecha a **parte do solicitante** (D-66);
- recebe a pergunta "foi resolvido?" na escada de avisos até fechar a parte dele (D-67);
- pode cancelar, com motivo.

**Não é:** o dono do card (D-65) nem "usuário" em geral (qualquer pessoa autenticada).

---

### 2.21 Parte do solicitante / parte do dono

**Definição (D-66):** as duas metades do encerramento de uma tratativa. Cada parte tem autor e horário próprios e alimenta os relatórios: tempo de encerramento pelo solicitante, tempo de encerramento pelo dono e a visão consolidada com a diferença entre os dois.

---

### 2.22 Aviso e escada de avisos

**Aviso:** comunicação enviada pelo servidor sobre uma tratativa, com destinatários decididos no servidor.

- **Aviso de abertura (D-58):** ao abrir, avisa o dono do card e o Jair.
- **Escada de avisos (D-67):** em **2h** e **4h** desde a abertura, enquanto o solicitante não fechar a parte dele: e-mail ao dono pedindo que cobre o solicitante e pergunta "foi resolvido?" ao solicitante. Depois que o solicitante fecha, nenhum aviso a mais. Tempo corrido, 24h por dia.

Canal: e-mail decidido; Teams em aberto (GI-SAFRA-011).

**Não é:** SLA (2.11); a hora do último aviso não marca prazo estourado.

---

### 2.23 Safra corrente

**Definição (D-59/D-69):** período operacional que começa quando o Kaue marca "Safra iniciada" e termina quando ele marca "Safra encerrada". A Safra corrente começou em **01/10/2026**.

Proteções (D-70): encerrar exige digitar `ENCERRAR SAFRA`; 7 dias para reabrir sem apagar dados. O encerramento é o marco da política de retenção.

---

### 2.24 Card

**Definição:** representação visual de um cenário (ou da proposta, no 12º card) na interface. Não é entidade de domínio própria. "Dono do card" = owner do cenário.

---

## 3. Relações canônicas

```text
PROPOSTA DE CENÁRIO (12º card)
        |   proponente escreve -> Jair aprova -> admin técnico publica (D-60/D-68)
        v
CENÁRIO --- dono do card (1 vigente)
        |
        +--> VERSION 1 (RETIRED)
        +--> VERSION 2 (PUBLISHED, CRITICAL)
               |   gatilho, detecção, protocolo, criticidade
               v
             START  (solicitante; nunca o dono do card)
               |
               v
           TRATATIVA
        Em andamento
          |  aviso de abertura + escada 2h/4h
          |
          +--> parte do solicitante fechada --> Aguardando dono
          +--> parte do dono fechada --------> Aguardando solicitante
          |            (as duas) ------------> Encerrado
          |
          +--> CANCEL (solicitante ou dono, com motivo) --> Cancelado
                         |
                         v
                 histórico / analytics
                         +--> tempos por parte e consolidado
                         +--> recorrência
                         +--> pós-mortem quando aplicável
```

---

## 4. Termos que não podem ser usados como sinônimos

| Não confundir | Motivo |
|---|---|
| cenário × tratativa | tipo conhecido × ocorrência real |
| cenário × versão | identidade estável × conteúdo vigente |
| gatilho × detecção | condição × forma de perceber |
| START × detecção | ativação humana × percepção do sinal |
| protocolo × tratativa | procedimento × instância real |
| dono do card × solicitante | responsável formal do card × quem abriu o protocolo (nunca a mesma pessoa no mesmo card) |
| protocolo × chamado | procedimento/ocorrência governada pelo Painel × atendimento em sistema operacional (OTRS etc.); "chamado" não é termo do Painel (D-05) |
| aviso × SLA | comunicação de acompanhamento × compromisso temporal medido (sem uso nos cards, D-62) |
| parte do solicitante × parte do dono | fechamento de quem abriu × fechamento do dono; o protocolo só encerra com as duas |
| área responsável × área impactada | responsabilidade × consequência |
| SLA × SLO/RTO/RPO | compromisso do protocolo × objetivos técnicos do software |
| criticidade × escalonamento | classificação do cenário × avaliação conjunta dos donos fora do Painel (D-73) |
| END × CANCEL | resolução válida × invalidação/encerramento não resolutivo |
| recorrência × crise | indicador histórico × decisão de escalonamento |
| proposta × cenário | candidato em governança × entidade publicada |
| incidente TI × tratativa Safra | domínio legado retirado pela D-50 × domínio de contingência; "incidente" não é termo do Painel Safra |

---

## 5. Termos de interface permitidos

- **"Abrir protocolo"** = START.
- **"Encerrar"** e o botão **"Resolvido"** = END da parte de quem clica.
- **"Cancelar"** = CANCEL.
- **"Em andamento", "Aguardando dono", "Aguardando solicitante", "Encerrado", "Cancelado"** = situações da tratativa (D-72).
- **"Dono do card"** = owner; **"Solicitante"** = quem abriu.
- **"Card"** = representação visual de cenário/proposta, não entidade de domínio.
- **"Geral"** = visão agregada, não área.
- **Proibido na interface:** "chamado" (D-05), "incidente" (D-50) e "escalonamento" (D-73).

---

## 6. Regra de mudança

Qualquer mudança material nestas definições deve:

1. registrar decisão em `docs/DECISOES.md`;
2. atualizar `docs/REGRAS_NEGOCIO.md` quando afetar regra;
3. atualizar `docs/ROADMAP.md` se alterar sequência ou escopo;
4. reavaliar migrations/API/UI/testes afetados;
5. preservar compatibilidade histórica das tratativas já registradas.


---

## 7. Impacto — formalização do domínio

### 7.1 Regra estrutural

Impacto pertence à ocorrência/tratativa quando descreve o que efetivamente aconteceu. Um cenário pode registrar **impacto esperado/potencial**, mas o impacto real só existe na tratativa.

```text
CENÁRIO / VERSÃO
  -> impacto esperado ou potencial

TRATATIVA
  -> impacto observado ou efetivo
```

### 7.2 Impacto qualitativo

**Definição:** descrição textual e contextual das consequências da contingência, sem depender de uma medida numérica.

Pode responder, por exemplo:
- o que foi afetado;
- como a operação foi afetada;
- quais áreas foram atingidas;
- qual consequência operacional foi percebida.

**No cenário/versão:** descreve o tipo de impacto que pode ocorrer.

**Na tratativa:** descreve o impacto efetivamente observado naquela ocorrência.

**Regra:** impacto qualitativo não é criticidade e não promove escalonamento automaticamente.

**Regra:** a descrição deve registrar fatos/contexto operacional, evitando inferências ou números sem fonte.

### 7.3 Impacto quantitativo

**Definição:** medida estruturada da magnitude do impacto observado, sempre composta por pelo menos:

- métrica;
- valor;
- unidade;
- fonte/origem;
- instante ou período de referência.

Exemplos de formato, sem definir quais métricas são obrigatórias:

```text
métrica = pedidos_afetados
valor = 120
unidade = pedidos
fonte = sistema/origem declarada
medido_em = timestamp
```

ou

```text
métrica = percentual_operacao_afetada
valor = 18.5
unidade = percentual
fonte = origem declarada
medido_em = timestamp
```

**Regra:** ausência de fonte impede tratar o valor como impacto quantitativo confirmado.

**Regra:** não inventar zero quando o valor for desconhecido. Usar ausência/null/UNKNOWN conforme contrato da fase de dados.

**Regra:** impacto quantitativo não altera automaticamente:
- criticidade;
- escalonamento;
- estado da tratativa;
- cumprimento de SLA.

Qualquer automação futura baseada em limiar exige regra de negócio própria e versionada.

### 7.4 O que não será criado no C03

O C03 **não** cria:
- score único de impacto;
- faixas baixa/média/alta inventadas;
- pesos;
- fórmula financeira;
- threshold automático;
- conversão automática de impacto em criticidade.

Esses itens só podem existir quando houver fonte de negócio e decisão explícita.

### 7.5 Modelo conceitual recomendado

[DERIVADO — desenho para implementação futura em C05/F04]

```text
treatments
  impact_summary            # qualitativo

treatment_impact_measurements
  id
  treatment_id
  metric_code
  metric_label
  value_numeric
  unit
  source_type
  source_reference
  measured_at
  recorded_by
  created_at
```

Uma tratativa pode possuir zero, uma ou várias medições quantitativas.

### 7.6 Distinções adicionais congeladas

| Não confundir | Motivo |
|---|---|
| impacto qualitativo × impacto quantitativo | descrição contextual × medida estruturada |
| impacto esperado × impacto observado | expectativa do cenário × efeito real da tratativa |
| impacto × criticidade | consequência da ocorrência × classificação governada do cenário |
| impacto × SLA | magnitude do efeito × compromisso temporal |
| impacto quantitativo desconhecido × zero | ausência de medida × valor medido igual a zero |


---

## 8. Contrato de handoff para SAFRA-C05

Esta seção transforma o glossário em contrato de implementação. O C05 pode decidir detalhes físicos de PostgreSQL, índices, tipos e estratégia de migration, mas não pode alterar estas fronteiras sem nova decisão de domínio.

### 8.1 Fonte de verdade por conceito

| Conceito | Fonte de verdade | Mutabilidade |
|---|---|---|
| identidade do cenário | `scenarios` | estável |
| conteúdo operacional vigente | `scenario_versions` | nova versão; versão publicada é imutável |
| owner atual do cenário | `scenario_owners` | temporal, com validade |
| área responsável atual | `scenarios.responsible_area_id` | governada; histórico operacional deve ser preservado na tratativa |
| áreas potencialmente impactáveis | relação da `scenario_version` | versionada |
| sistemas/ferramentas associados | relação da `scenario_version` | versionada |
| SLAs | `scenario_slas` vinculados à `scenario_version` | versionados; **vazio no MVP (D-62)** |
| ocorrência real | `treatments` | estado controlado |
| áreas realmente impactadas | `treatment_impacted_areas` | pertencem à tratativa |
| impacto qualitativo observado | `treatments.impact_summary` | auditável |
| impacto quantitativo observado | `treatment_impact_measurements` | append/auditável |
| eventos operacionais | `treatment_events` | append-only |
| ~~escalonamento~~ | `treatment_escalations` | **sem uso (D-73)**; remoção na reauditoria do C05 |
| proposta de novo cenário | `scenario_proposals` | nunca equivale a cenário publicado |
| decisão aberta de governança | `governance_issues` | permanece explícita até resolução |

### 8.2 Cardinalidades canônicas

```text
scenario 1 ---- N scenario_versions
scenario 1 ---- N scenario_owners (histórico temporal)
scenario_version 1 ---- N scenario_slas
scenario_version 1 ---- N potential_impacted_areas
scenario_version 1 ---- N associated_systems
scenario 1 ---- N treatments
scenario_version 1 ---- N treatments
treatment 1 ---- N treatment_events
treatment 1 ---- N treatment_impacted_areas
treatment 1 ---- N treatment_escalations   (sem uso, D-73)
treatment 1 ---- N treatment_impact_measurements
scenario_proposal 1 ---- N owner_responses
```

Para um cenário publicado, deve existir **exatamente um owner ativo** no instante operacional. Histórico de owners é preservado por validade temporal.

### 8.3 Estados canônicos

#### Cenário — catálogo

```text
ACTIVE
INACTIVE
```

`ACTIVE` significa que o cenário pertence ao catálogo operacional. Isso não basta para START: precisa também existir uma versão corrente `PUBLISHED`.

#### Versão de cenário

```text
DRAFT
PUBLISHED
RETIRED
```

Regras:
- apenas `PUBLISHED` pode ser usada em START;
- no máximo uma versão `PUBLISHED` corrente por cenário;
- `PUBLISHED` nunca é editada in-place;
- nova publicação aposenta a versão corrente sem reescrever histórico (aplicado na versão 2 CRITICAL, D-55).

#### Tratativa

Status técnico:

```text
ACTIVE
RESOLVED
CANCELLED
```

Partes do encerramento (D-66/D-72), registradas separadamente enquanto o status é `ACTIVE`:

```text
parte do solicitante: aberta | fechada (autor + horário)
parte do dono:        aberta | fechada (autor + horário)
```

Transições:

```text
START                          -> ACTIVE (Em andamento)
ACTIVE + fecha parte solicitante -> ACTIVE (Aguardando dono)
ACTIVE + fecha parte dono        -> ACTIVE (Aguardando solicitante)
ACTIVE + as duas partes fechadas -> RESOLVED (Encerrado)
ACTIVE + CANCEL (solicitante ou dono, motivo) -> CANCELLED (Cancelado)
```

Não existe transição silenciosa de `RESOLVED` ou `CANCELLED` para `ACTIVE`.

### 8.4 Elegibilidade para START

START é permitido somente quando todas as condições forem verdadeiras:

```text
scenario.lifecycle_status = ACTIVE
AND scenario.current_version_id aponta para version.status = PUBLISHED
AND sessão corporativa válida
AND solicitante ≠ dono vigente do cenário (D-65)
AND o solicitante não tem outra tratativa ACTIVE com a parte dele aberta nesse cenário (D-57/D-66)
```

O client não escolhe uma versão histórica. O backend resolve a versão corrente e persiste `scenario_version_id`.

### 8.5 Snapshot obrigatório no START

A tratativa deve preservar contexto suficiente para não depender de relações futuras mutáveis.

[DERIVADO — requisito de auditabilidade para C05]

Persistir no START:

- `scenario_id`;
- `scenario_version_id`;
- `opened_by`;
- `opened_at` server-side;
- `owner_id_at_start`;
- `responsible_area_id_at_start`.

A criticidade, gatilho, protocolo e SLAs históricos são obtidos da `scenario_version_id` congelada e não precisam ser duplicados na tratativa.

Se owner ou área responsável mudar depois, a tratativa antiga continua mostrando quem respondia no momento do START. O vínculo atual do cenário continua separado para operação futura.

### 8.6 Owner

`scenario_owner` é responsabilidade de negócio, não role administrativa genérica.

Contrato:

- vínculo explícito `scenario_id + user_id`;
- validade temporal `valid_from/valid_to`;
- no máximo um vínculo ativo por cenário;
- cenário não pode ser publicado para uso operacional sem owner ativo;
- platform/governance/executive admin não viram owner por herança;
- `owner_id_at_start` da tratativa é snapshot histórico.

### 8.7 Área responsável e áreas impactadas

#### Área responsável
- exatamente uma área responsável corrente por cenário publicado;
- representa quem responde primariamente pelo cenário;
- snapshot `responsible_area_id_at_start` preserva o contexto da tratativa.

#### Área potencialmente impactável
- pertence à **versão do cenário**, não à tratativa;
- relação N:N;
- informa quem pode ser afetado segundo aquela versão.

#### Área efetivamente impactada
- pertence à tratativa;
- relação N:N;
- pode ser subconjunto, conjunto igual ou diferente do potencial previsto;
- não deve reescrever a versão do cenário.

Para C05, usar relação versionada, preferencialmente nomeada `scenario_version_impacted_areas`, evitando o nome ambíguo `scenario_impacted_areas`.

### 8.8 Sistemas/ferramentas associados

Ferramentas de detecção, origem, apoio ou monitoramento podem mudar entre versões.

Para C05, a relação deve ser versionada, preferencialmente `scenario_version_systems`.

Uma tratativa histórica não deve passar a mostrar uma ferramenta nova apenas porque a versão atual do cenário mudou.

### 8.9 Criticidade

Valores válidos: `CRITICAL`, `HIGH`, `MODERATE`.

- `scenario_versions.criticality` **não recebe default**;
- os 11 cenários estão em `CRITICAL` na versão 2 (D-55); a versão 1 preserva `NULL` como histórico;
- cenário novo nasce `CRITICAL` (D-60);
- mudar criticidade exige nova versão.

### 8.10 SLA

SLA pertence à versão do cenário (`scenario_slas`), mas **no MVP nenhum card tem SLA** (D-62): a tabela permanece vazia e START não inicia relógio.

Se um SLA for criado no futuro por decisão nova, continuam valendo: timestamps oficiais como fonte, duração calculada, CANCEL não equivale a cumprido, evento ausente = não mensurável.

### 8.11 END e CANCEL — semântica de persistência

**Contrato para F01/F02 (D-66/D-72):**

#### Partes do END
- parte do solicitante: autor (= solicitante) e horário do servidor;
- parte do dono: autor (= dono vigente) e horário do servidor;
- só quem é dono da parte pode fechá-la;
- `RESOLVED` exige as duas partes fechadas; o horário de `RESOLVED` é o da segunda parte;
- os campos atuais `closed_by/closed_at` (um só fechamento) **não bastam** e precisam ser substituídos ou complementados na F01.

#### CANCELLED
- `cancelled_by` = solicitante ou dono;
- `cancelled_at` server-side;
- `cancellation_reason` obrigatório;
- campos das partes do END permanecem como estavam (não representam resolução).

CANCEL preserva START e todo o histórico anterior.

### 8.12 Eventos e audit trail

`treatment_events` é append-only.

Eventos canônicos:

```text
TREATMENT_OPENED
NOTE_ADDED
IMPACT_AREA_ADDED
IMPACT_AREA_REMOVED
REQUESTER_PART_CLOSED     (parte do solicitante — F01)
OWNER_PART_CLOSED         (parte do dono — F01)
TREATMENT_RESOLVED        (as duas partes fechadas)
TREATMENT_CANCELLED
REMINDER_SENT             (aviso enviado — M05)
ADMIN_CORRECTION_RECORDED
```

Fora de uso: `ESCALATION_CHANGED` (D-73) e `SLA_BREACHED` (D-62).

Regras:
- evento possui ator quando houver ação humana;
- `occurred_at` oficial é server-side;
- `correlation_id` persistido para mutations críticas;
- correção administrativa cria novo evento; não altera evento passado.

### 8.13 Impacto quantitativo — contrato físico mínimo

C05 deve criar estrutura capaz de receber medições futuras sem inventar métricas de negócio.

```text
treatment_impact_measurements
  id
  treatment_id
  metric_code
  metric_label
  value_numeric
  unit
  source_type
  source_reference
  measured_at
  recorded_by
  created_at
```

Invariantes:
- se não existe medição, não criar linha fictícia com zero;
- uma linha de medição exige valor, unidade e referência de fonte suficientes para auditoria;
- métricas/thresholds específicos continuam deferidos para C06/F04;
- tabela não gera score automático.

### 8.14 Recorrência

Recorrência é **métrica derivada**, não entidade transacional obrigatória.

C05 não deve criar status ou tabela de “recorrência” como fonte primária. Ela será calculada a partir de tratativas por cenário e janela temporal definida posteriormente.

### 8.15 Pós-mortem

Pós-mortem está no domínio, mas seu workflow pertence ao F03.

C05 não deve presumir:
- que toda tratativa exige pós-mortem;
- enum/status final do pós-mortem;
- tabela obrigatória nesta migration inicial.

Quando formalizado, deve referenciar a tratativa original e não alterar seu END.

### 8.16 Múltiplas tratativas simultâneas

**Decidido (D-57/D-66):** uma pessoa tem no máximo uma tratativa em andamento por cenário, contada pela parte dela (solicitante); pessoas diferentes podem ter tratativas simultâneas do mesmo cenário. Hoje aplicado por `treatments_one_active_per_person_scenario` (status `ACTIVE`); na F01 a trava passa a considerar a parte do solicitante.

### 8.17 Proposta de cenário

`scenario_proposals` é entidade separada.

C05 deve garantir estruturalmente:
- proposta não possui `scenario_id` produtivo por default;
- proposta não recebe START;
- conversão/publicação depende do fluxo M10;
- enum completo do lifecycle da proposta pode permanecer deferido a M10, sem inventar estados finais agora.

### 8.18 Governance issue

`governance_issues` registra pendência material sem preencher default. Fonte oficial do texto e do status: `docs/GOVERNANCE_ISSUES.md` (D-53); o banco espelha.

### 8.19 Itens ainda sem decisão (não inventar)

- thresholds dos cenários 2, 4, 10 e 11 e mínimo da curva A — V2 do produto (D-56);
- métricas/thresholds quantitativos de impacto — F04;
- avisos pelo Teams e formato (GI-SAFRA-011) — M05;
- período do resumo da governança semanal — F05.

### 8.20 Checklist de aceite

O implementador deve conseguir responder sem interpretação:

- qual entidade representa identidade do cenário? → `scenarios`;
- qual entidade guarda conteúdo mutável? → `scenario_versions`;
- qual entidade representa ocorrência real? → `treatments`;
- qual versão vale na tratativa? → `scenario_version_id` congelada no START;
- quem é o solicitante? → `opened_by`;
- o dono pode abrir protocolo do próprio card? → não (D-65);
- owner histórico vem de onde? → `owner_id_at_start`;
- criticidade atual dos 11? → CRITICAL (D-55);
- há cronômetro de SLA nos cards? → não (D-62);
- a tratativa encerra com um clique? → não; precisa das duas partes (D-66);
- quem cancela? → solicitante ou dono, com motivo;
- mesma pessoa pode ter duas tratativas ativas do mesmo cenário? → não (D-57);
- escalonamento é registrado no Painel? → não (D-73);
- proposta é cenário? → não;
- versão publicada pode ser UPDATE in-place? → não.
