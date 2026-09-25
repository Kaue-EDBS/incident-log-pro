# GLOSSÁRIO DE DOMÍNIO — Painel Safra

**Versão:** 1.0  
**Data:** 25/09/2026  
**Status:** CANÔNICO — SAFRA-C03  
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
