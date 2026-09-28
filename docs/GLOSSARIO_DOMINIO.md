# GLOSSÁRIO DE DOMÍNIO — Painel Safra

**Versão:** 1.1  
**Data:** 25/09/2026  
**Status:** CANÔNICO — SAFRA-C03 / READY_FOR_C05  
**Autoridade:** este documento congela o vocabulário funcional do Painel Safra. Alteração material exige decisão registrada.

> **C03-AUD aberta em 28/09/2026 às 06:13 BRT.** A autoridade conceitual deste glossário permanece válida durante a reauditoria. Foram autorizadas correções de nomenclatura de rota, separação visual Safra × Reliability legado, separação de hooks por domínio e atualização dos metadados/estado pós-C05–C08. Fonte de acompanhamento: `docs/AUDITORIA_C03_REABERTURA_2026-09-28.md`.

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

**Definição:** ação humana auditável que ativa formalmente um cenário publicado no Painel Safra e cria uma tratativa.

Efeitos mínimos:
- cria a tratativa;
- persiste ator;
- persiste timestamp oficial server-side;
- congela `scenario_version_id`;
- inicia os SLAs cujo `start_event` corresponda ao START;
- gera evento de auditoria;
- dispara comunicações aplicáveis de forma idempotente.

**Quem pode:** qualquer usuário Microsoft autenticado, conforme regras de autorização vigentes.

**Não é:**
- detecção;
- gatilho;
- aprovação de cenário;
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

**Definição:** instância real e auditável criada quando um cenário publicado recebe START.

A tratativa representa **uma ocorrência operacional específica daquele cenário** dentro do Painel.

Estados mínimos:
- ACTIVE;
- RESOLVED;
- CANCELLED.

Pode possuir:
- versão congelada;
- ator de abertura;
- tempos;
- áreas efetivamente impactadas;
- eventos;
- SLAs;
- escalonamentos;
- END ou CANCEL.

**Não é:**
- cenário;
- protocolo;
- proposta;
- chamado externo.

---

### 2.8 Owner

**Definição:** pessoa formalmente responsável pelo card/cenário e pela condução do protocolo operacional com sua equipe.

O owner:
- responde pelo conteúdo/procedimento do card;
- recebe comunicações do próprio card;
- participa da governança relacionada ao cenário.

**Regra:** ownership depende de vínculo explícito com o cenário.

**Regra adicional:** owner não possui exclusividade sobre START, END ou CANCEL.

**Não é:**
- sinônimo de administrador;
- papel herdado automaticamente por platform admin;
- usuário que necessariamente executou o START.

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

**Definição:** compromisso temporal do protocolo medido entre eventos definidos.

Cada SLA deve possuir:
- `start_event`;
- `end_event`;
- valor-alvo;
- unidade;
- regra de aplicabilidade.

**Regra:** duração é derivada de timestamps persistidos; não deve existir como número manual quando puder ser calculada.

**Regra:** um cenário pode ter múltiplos SLAs simultâneos.

**Não é:**
- SLO do software;
- RTO;
- RPO;
- criticidade;
- simples cronômetro visual.

---

### 2.12 Criticidade

**Definição:** classificação de severidade do cenário/protocolo para fins de governança e comunicação.

Valores canônicos:
- CRITICAL;
- HIGH;
- MODERATE.

**Regra:** criticidade é atributo versionado do cenário.

**Não é:**
- `service_class` da aplicação;
- `application_criticality`;
- nível de escalonamento;
- status da tratativa.

---

### 2.13 END

**Definição:** ação humana auditável que encerra uma tratativa ACTIVE porque a necessidade que motivou sua ativação foi concluída.

Efeito principal:
- transição `ACTIVE -> RESOLVED`;
- persiste ator e timestamp server-side;
- gera evento de auditoria;
- fecha somente os SLAs cujo `end_event` corresponda ao evento de resolução;
- dispara comunicação aplicável.

**Quem pode:** qualquer usuário Microsoft autenticado, conforme regras vigentes.

**Não é:**
- CANCEL;
- exclusão;
- garantia automática de que todo SLA foi cumprido.

---

### 2.14 CANCEL

**Definição:** ação humana auditável usada quando a tratativa não deve ser considerada resolução válida, por exemplo abertura incorreta, duplicada ou cenário inadequado.

Efeito principal:
- transição `ACTIVE -> CANCELLED`;
- exige justificativa;
- preserva histórico;
- persiste ator e timestamp;
- gera evento de auditoria.

**Regra:** CANCEL não equivale a SLA cumprido.

**Não é:**
- END;
- delete físico;
- mecanismo para limpar métricas desfavoráveis.

---

### 2.15 Escalonamento

**Definição:** elevação formal da governança de uma tratativa quando o contexto exige envolvimento técnico, de negócio ou executivo adicional.

Níveis previstos:
- NONE;
- TECHNICAL_CRISIS;
- BUSINESS_CRISIS;
- EXECUTIVE.

**Regra:** escalonamento é estrutura separada do status da tratativa.

**Regra:** recorrência sozinha não promove escalonamento automaticamente.

**Não é:**
- criticidade;
- status;
- START;
- nova tratativa.

---

### 2.16 Pós-mortem

**Definição:** análise posterior ao encerramento de uma contingência para registrar causa, aprendizado e ações preventivas quando exigido pela regra do cenário ou pela governança.

Pode possuir:
- owner;
- prazo;
- conclusão;
- causa-raiz;
- ação preventiva;
- SLA próprio.

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
- possui proponente identificado pela sessão Microsoft;
- registra problema e impacto na Safra;
- passa por triagem;
- recebe definição de ownership;
- precisa de governança antes de publicação.

**Regra:** proposta não é cenário produtivo e não aceita START.

**Não é:**
- cenário publicado;
- tratativa;
- protocolo genérico.

---

### 2.19 Publicação de cenário

**Definição complementar:** ato de governança que torna uma versão de cenário elegível para uso operacional.

Somente cenário/versão em estado publicado pode receber START.

**Regra:** proposta aprovada não deve ser tratada como publicada até cumprir o fluxo formal de governança definido em M10.

---

## 3. Relações canônicas

```text
PROPOSTA DE CENÁRIO
        |
        v
governança / aprovação / publicação
        |
        v
CENÁRIO
        |
        +--> VERSION 1
        |      +-- gatilho
        |      +-- detecção
        |      +-- protocolo
        |      +-- criticidade
        |      +-- SLA(s)
        |
        +--> VERSION 2 ...
               |
               v
              START
               |
               v
           TRATATIVA
        ACTIVE
          |
          +--> escalonamento(s)
          +--> áreas efetivamente impactadas
          +--> eventos / SLA(s)
          |
          +--> END -----> RESOLVED
          |
          +--> CANCEL --> CANCELLED
                         |
                         v
                 histórico / analytics
                         |
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
| owner × ator do START | responsável formal × quem executou a ação |
| área responsável × área impactada | responsabilidade × consequência |
| SLA × SLO/RTO/RPO | compromisso do protocolo × objetivos técnicos do software |
| criticidade × escalonamento | classificação do cenário × nível de governança da ocorrência |
| END × CANCEL | resolução válida × invalidação/encerramento não resolutivo |
| recorrência × crise | indicador histórico × decisão de escalonamento |
| proposta × cenário | candidato em governança × entidade publicada |
| incidente TI × tratativa Safra | domínio legado de confiabilidade × domínio de contingência |

---

## 5. Termos de interface permitidos

- “Abrir protocolo” pode ser usado como rótulo de UX para START, desde que o domínio continue registrando a ação como START.
- “Encerrar” pode ser usado como rótulo de UX para END.
- “Cancelar” corresponde a CANCEL.
- “Card” é apenas representação visual de cenário/proposta e não entidade de domínio.
- “Geral” é visão agregada, não área.

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
| SLAs | `scenario_slas` vinculados à `scenario_version` | versionados |
| ocorrência real | `treatments` | estado controlado |
| áreas realmente impactadas | `treatment_impacted_areas` | pertencem à tratativa |
| impacto qualitativo observado | `treatments.impact_summary` | auditável |
| impacto quantitativo observado | `treatment_impact_measurements` | append/auditável |
| eventos operacionais | `treatment_events` | append-only |
| escalonamento | `treatment_escalations` | entidade separada do status |
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
treatment 1 ---- N treatment_escalations
treatment 1 ---- N treatment_impact_measurements
scenario_proposal 1 ---- N owner_responses
```

Para um cenário publicado, deve existir **exatamente um owner ativo** no instante operacional. Histórico de owners é preservado por validade temporal.

### 8.3 Estados canônicos

#### Cenário — catálogo

[DERIVADO — contrato técnico para C05]

```text
ACTIVE
INACTIVE
```

`ACTIVE` significa que o cenário pertence ao catálogo operacional. Isso não basta para START: precisa também existir uma versão corrente `PUBLISHED`.

#### Versão de cenário

[DERIVADO — contrato técnico para C05]

```text
DRAFT
PUBLISHED
RETIRED
```

Regras:
- apenas `PUBLISHED` pode ser usada em START;
- no máximo uma versão `PUBLISHED` corrente por cenário;
- `PUBLISHED` nunca é editada in-place;
- nova publicação aposenta/substitui a versão corrente sem reescrever histórico;
- o termo antigo `VALIDATED` não é estado canônico do banco; validação é parte do processo de governança anterior à publicação.

#### Tratativa

```text
ACTIVE
RESOLVED
CANCELLED
```

Transições permitidas:

```text
START  -> ACTIVE
ACTIVE -> RESOLVED   via END
ACTIVE -> CANCELLED  via CANCEL + motivo
```

Não existe transição silenciosa de `RESOLVED` ou `CANCELLED` para `ACTIVE`.

### 8.4 Elegibilidade para START

START é permitido somente quando todas as condições estruturais forem verdadeiras:

```text
scenario.lifecycle_status = ACTIVE
AND scenario.current_version_id aponta para version.status = PUBLISHED
AND sessão/autorização válida
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

Valores válidos quando definidos:

```text
CRITICAL
HIGH
MODERATE
```

Por causa de `GI-SAFRA-001`:

- `scenario_versions.criticality` **não pode receber default**;
- deve aceitar ausência explícita enquanto a classificação nominal não estiver resolvida;
- quando não nula, deve aceitar somente os três valores canônicos;
- ausência não equivale a `MODERATE`;
- C06 não pode preencher criticidade por inferência.

### 8.10 SLA

SLA pertence à versão do cenário.

Cada registro precisa referenciar:
- `scenario_version_id`;
- `start_event`;
- `end_event`;
- alvo;
- unidade;
- aplicabilidade.

Regras:
- timestamps oficiais são a fonte primária;
- duração é calculada;
- CANCEL não equivale a SLA cumprido;
- ausência do evento necessário significa SLA **não mensurável**, não `OK`;
- múltiplos SLAs podem coexistir.

### 8.11 END e CANCEL — semântica de persistência

#### RESOLVED
Quando `status = RESOLVED`:
- `closed_by` obrigatório;
- `closed_at` obrigatório e server-side;
- campos de cancelamento devem permanecer nulos.

#### CANCELLED
Quando `status = CANCELLED`:
- `cancelled_by` obrigatório;
- `cancelled_at` obrigatório e server-side;
- `cancellation_reason` obrigatório;
- `closed_by/closed_at` não representam resolução e devem permanecer nulos.

CANCEL preserva START e todo o histórico anterior.

### 8.12 Eventos e audit trail

`treatment_events` é append-only.

Eventos mínimos canônicos:

```text
TREATMENT_OPENED
NOTE_ADDED
IMPACT_AREA_ADDED
IMPACT_AREA_REMOVED
ESCALATION_CHANGED
SLA_BREACHED
TREATMENT_RESOLVED
TREATMENT_CANCELLED
ADMIN_CORRECTION_RECORDED
```

Regras:
- evento possui ator quando houver ação humana;
- `occurred_at` oficial é server-side;
- `correlation_id` deve ser persistido para mutations críticas;
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

A regra ainda está deferida para M01.

Portanto, **C05 não deve criar constraint de unicidade que impeça duas tratativas ACTIVE do mesmo cenário** até existir decisão formal.

### 8.17 Proposta de cenário

`scenario_proposals` é entidade separada.

C05 deve garantir estruturalmente:
- proposta não possui `scenario_id` produtivo por default;
- proposta não recebe START;
- conversão/publicação depende do fluxo M10;
- enum completo do lifecycle da proposta pode permanecer deferido a M10, sem inventar estados finais agora.

### 8.18 Governance issue

`governance_issues` registra pendência material sem preencher default.

Para `GI-SAFRA-001`:
- issue permanece OPEN;
- seed C06 não define os quatro CRITICAL;
- resolução futura gera decisão registrada e versão de cenário apropriada.

### 8.19 Itens explicitamente fora do C05

C05 não deve decidir por conta própria:
- os quatro cenários CRITICAL;
- thresholds dos cenários 2, 4, 10 e 11;
- mínimo oficial da curva A;
- regra de múltiplas tratativas simultâneas;
- métricas/thresholds quantitativos específicos;
- fluxo final de publicação do 12º card;
- provider/canal de e-mail;
- janela semanal de governança.

### 8.20 Checklist de aceite para entrada no C05

Antes de escrever migration, o implementador deve conseguir responder sem interpretação:

- qual entidade representa identidade do cenário? → `scenarios`;
- qual entidade guarda conteúdo mutável? → `scenario_versions`;
- qual entidade representa ocorrência real? → `treatments`;
- qual versão vale na tratativa? → `scenario_version_id` congelada no START;
- owner histórico vem de onde? → `owner_id_at_start`;
- área responsável histórica vem de onde? → `responsible_area_id_at_start`;
- áreas potenciais vêm de onde? → versão do cenário;
- áreas reais vêm de onde? → tratativa;
- criticidade desconhecida vira MODERATE? → não;
- CANCEL usa `closed_at`? → não;
- impacto quantitativo desconhecido vira zero? → não;
- recorrência é tabela transacional? → não;
- múltiplos ACTIVE do mesmo cenário são proibidos no C05? → não, decisão M01;
- proposta é cenário? → não;
- versão publicada pode ser UPDATE in-place? → não.

Se qualquer resposta acima for implementada de forma diferente, a mudança precisa voltar ao domínio antes de ser codificada.
