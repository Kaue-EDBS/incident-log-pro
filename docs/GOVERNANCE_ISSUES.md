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
| 001 | Quais são os 4 cenários CRITICAL? | RESOLVED (D-55) — os 11 são CRITICAL |
| 002 | Thresholds dos cenários 2, 4, 10 e 11 | RESOLVED (D-139) — sem detecção automática |
| 003 | Fonte do mínimo da curva A (cenário 9) | RESOLVED (D-139) — sem detecção automática |
| 004 | Tratativas simultâneas do mesmo cenário | RESOLVED (D-57) |
| 005 | Canal de notificações e platform admins | DECIDED (D-58) — implementação na M05 |
| 006 | Janela oficial da "Safra corrente" | DECIDED (D-59) — implementação na F04/M05 |
| 007 | Publicação formal do 12º card | RESOLVED (D-60, M10: D-125 a D-130) |
| 008 | Janela da governança semanal | RESOLVED (D-61) — fora do escopo |
| 009 | Eventos dos SLAs textuais | RESOLVED (D-62) — sem cronômetro de SLA |
| 010 | Liberação de START por card | RESOLVED (D-63) |
| 011 | Avisos também pelo Teams? Para pessoa ou canal? | OPEN — DEFERRED_TO_M05 |
| 012 | Backup diário atende a meta de RPO 5 min / RTO 30 min (D-23)? | RESOLVED (D-93) — meta revista: RPO até 24 h, RTO até 4 h |
| 013 | Tamanho da instância do banco antes de liberar o acesso | RESOLVED (D-116) — fica como está, risco aceito |
| 014 | Região dos dados (Londres) atende a LGPD? | RESOLVED (D-116) — fica em Londres |
| 015 | Cabeçalhos de segurança e domínio próprio | RESOLVED (D-116) — fica em painelsafra.lovable.app |
| 016 | Avisar antes do cancelamento automático de 72 h? | RESOLVED (D-112) — 24 h, 12 h e 1 h antes |
| 017 | Trocar o envio provisório pelo aplicativo do TI | OPEN — aguarda o TI (envio automático já funciona, D-133) |
| 018 | Na governança semanal, protocolo encerrado sozinho (72 h) conta na semana em que a última parte concluiu ou na do encerramento automático? | OPEN — hoje: última parte (como os Indicadores, D-117) |
| 019 | Pode registrar ação de governança em semana futura ou muito antiga? | OPEN — hoje: qualquer semana |
| 020 | Por quanto tempo guardar os e-mails enviados (texto e destinatário)? | OPEN — hoje: para sempre |
| 021 | Quem opera os e-mails e a Safra quando o Kaue não está? | OPEN — hoje: só o Kaue |
| 022 | Limitar quantos protocolos uma pessoa abre/cancela por hora? | OPEN — hoje: sem limite (um por card ao mesmo tempo) |
| 023 | Até quanto tempo atrás pode ser o "problema começou"? | OPEN — hoje: qualquer data passada |
| 024 | Apagar do banco tabelas e funções sem uso (medições de impacto, sistemas, funções antigas)? | OPEN — hoje: mantidas |

## GI-SAFRA-001 — Definição nominal dos quatro cenários CRITICAL

**Status:** RESOLVED (D-55) — aplicado em 01/10/2026 (migration `20261001120000`)  
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

Aplicado em 01/10/2026: os 11 cenários estão na `scenario_version` 2, CRITICAL; a versão 1 ficou RETIRED (migration `20261001120000`).

### Regra de implementação futura

Quando resolvido:

- criticidade entra em nova/publicada `scenario_version`;
- tratativas antigas continuam vinculadas à criticidade da versão congelada no START;
- nenhuma alteração retroativa de histórico.


---

# Demais pendências

As decisões abaixo não devem ser completadas pela aplicação, por migration ou por LLM sem aprovação humana explícita.

## GI-SAFRA-002 — Thresholds ainda abertos dos cenários 2, 4, 10 e 11

**Status:** RESOLVED (D-139, 03/10/2026) — o Painel não terá detecção automática (M11 cancelada); todo protocolo é aberto manualmente e os limites não são necessários.
**Histórico:** OPEN — DEFERRED_TO_PRODUCT_V2 (D-56)  
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

**Status:** RESOLVED (D-139, 03/10/2026) — sem detecção automática; SAFRA-09 segue com abertura manual e a fonte do mínimo não é necessária.
**Histórico:** OPEN — DEFERRED_TO_PRODUCT_V2 (D-56)  
**Decisão do owner (30/09/2026):** como no GI-002, o mínimo só serve à detecção automática, que fica para a V2/V3 do produto. SAFRA-09 segue com START manual (D-46).  
**Bloqueia START/C08:** não.  
**Bloqueia automação objetiva da ruptura:** sim.

É necessário definir qual fonte/regra oficial determina o saldo mínimo de um SKU curva A.

**Regra aprovada D-46:** enquanto a fonte não existir, SAFRA-09 opera por START manual e nenhuma ruptura é classificada automaticamente.

## GI-SAFRA-004 — Treatments simultâneos do mesmo cenário

**Status:** RESOLVED (D-57) — aplicado em 01/10/2026 (migration `20261001120000`)  
**Fase:** SAFRA-M01.  
**Decisão do owner (30/09/2026):** trava **por pessoa e por card**. Uma pessoa pode ter vários cards abertos, mas só uma tratativa `ACTIVE` por card até encerrá-la. Pessoas diferentes podem abrir o mesmo card ao mesmo tempo.

Decidir se um cenário pode possuir mais de uma tratativa `ACTIVE` simultaneamente. Até decisão, nenhuma constraint de unicidade será criada.

## GI-SAFRA-005 — Canal/provider de notificações e comportamento dos platform admins

**Status:** DECIDED (D-58, revista pela D-111 em 02/10/2026: Jair não recebe e-mail; só e-mail) — fila e regras prontas na M05; envio aguarda o TI  
**Fase:** SAFRA-M05.  
**Decisão do owner (30/09/2026):** avisos por e-mail (Microsoft 365) e Teams. Dono do card recebe pelos dois; Jair recebe só por e-mail, de todos os protocolos; platform admins não recebem, salvo se forem donos do card.

Definir:
- provider/canal produtivo;
- se platform admins recebem comunicação operacional e em quais condições.

## GI-SAFRA-006 — Janela temporal oficial da “Safra corrente”

**Status:** RESOLVED (D-59, implementada em 02/10/2026 com D-118/D-119) — botão só do Kaue em Administração  
**Fase:** M05/F04.  
**Decisão do owner (30/09/2026):** a Safra é aberta e encerrada manualmente no sistema, por marcação do Kaue.

Definir o período exato usado em métricas, e-mails e análises da Safra corrente.

## GI-SAFRA-007 — Publicação formal do 12º card após ownership

**Status:** RESOLVED (D-60, implementada em 02/10/2026 com D-125 a D-129): protocolo e conteúdo aprovados pelo Jair; criticidade CRITICAL; sem SLA; versão 1 publicada por um admin  
**Fase:** SAFRA-M10.  
**Decisão do owner (30/09/2026):** o conteúdo é escrito pelo usuário que propôs; o Jair aprova; um platform admin publica; o card novo nasce CRITICAL.

Após definição do owner, ainda precisa ser decidido:
- quem aprova protocolo;
- quem aprova SLA;
- quem aprova criticidade;
- quando a primeira versão se torna `PUBLISHED`.

## GI-SAFRA-008 — Janela oficial da governança semanal

**Status:** RESOLVED (D-61) — fora do escopo da aplicação  
**Fase:** SAFRA-F05.  
**Decisão do owner (30/09/2026):** dia, horário e ritual da reunião semanal ficam fora do Painel. A F05 continua, com a tela de resumo e o registro das ações decididas.

Definir periodicidade/horário e corte de dados do ritual de governança semanal.


## GI-SAFRA-009 — Mapeamento formal dos eventos dos SLAs textuais

**Status:** RESOLVED (D-62) — nenhum card terá cronômetro de SLA; engine aposentada (D-75); a escada de avisos (D-67, completada pela D-76: 2h, 4h e de hora em hora) é requisito da M05/F01  
**Nota anterior (histórico):** a regra D-47 destravou o C08. A política abaixo não é mais usada: não há SLA (D-62) e a engine foi aposentada (D-75).  
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

Com isso, a decomposição deixou de ser ambígua para C08. **Superada:** nenhum SLA será materializado (D-62/D-75).

## GI-SAFRA-010 — Liberação de START por card

**Status:** RESOLVED (D-63)  
**Fase:** —  
**Decisão do owner (01/10/2026):** fica como está: qualquer usuário corporativo autenticado abre qualquer um dos 11 cards. Restrição futura exige decisão nova.  
**Bloqueia START/C08:** não.

Definir quais dos 11 cards podem ser abertos e por quem. Até decisão, os 11 cenários publicados continuam startáveis por qualquer usuário corporativo autenticado (D-51, D-06). Nenhum card é bloqueado por inferência.

---

### Persistência operacional

As issues `GI-SAFRA-001..010` também estão materializadas em `public.governance_issues`.

No banco:
- `OPEN` representa a decisão ainda pendente;
- resolução exige `RESOLVED` + ator + timestamp + texto de resolução;
- ausência de decisão nunca é convertida em default.

## GI-SAFRA-011 — Avisos pelo Teams

**Status:** OPEN — DEFERRED_TO_M05
**Fase:** SAFRA-M05.
**Bloqueia START/C08:** não.

A D-58 previa e-mail e Teams para o dono do card. Na revisão da escada de avisos (D-67, 01/10/2026), o owner confirmou o **e-mail** e ficou **em dúvida sobre o Teams**.

Perguntas em aberto:
1. Os avisos também vão pelo Teams?
2. Se sim, por **mensagem direta** à pessoa ou num **canal**? Num canal, todos os membros veem os dados do protocolo (ameaça de vazamento registrada no C02-AUD2).

Até a decisão, a M05 deve considerar apenas e-mail.

> **Atualização 01/10/2026 (C06-AUD2):** as descrições das pendências abertas (002, 003, 005, 006, 007) e a resolução da 009 foram atualizadas também no banco (migration `20261001220000`), com o mesmo conteúdo deste documento. Nenhum status mudou.

## GI-SAFRA-012 — Backup diário x meta de RPO 5 min / RTO 30 min

**Status:** RESOLVED (D-93, 02/10/2026) — meta revista para RPO até 24 h e RTO até 4 h; PITR como melhoria futura
**Fase:** SAFRA-C09 (fundação operacional).
**Bloqueia START/C08:** não.
**Origem:** auditoria somente leitura do lado do Lovable (L-01), 01/10/2026. Espelhada no banco (migration `20261001235000`, CI verde #255/#293, aplicada no PRIMARY: 41 = 41).

O Lovable Cloud informou **backup diário**, sem restauração ponto a ponto (PITR) no plano atual. A D-23 promete **RPO de 5 minutos** (perda máxima de dados) e **RTO de 30 minutos** (tempo para voltar). Com backup diário, a perda pode chegar a 24 horas.

Decidir no C09:
1. melhorar o plano no Lovable/Supabase para ter PITR; ou
2. rever a meta da D-23.

Nenhum valor é assumido até a decisão.

---

## GI-SAFRA-013 — Tamanho da instância do banco antes de liberar o acesso

**Status:** RESOLVED (D-116, 02/10/2026) — decisão final do owner: nada muda
**Fase:** liberação do acesso às pessoas (depois do C09).
**Bloqueia START/C08:** não.
**Origem:** respostas do Lovable ao C09, 02/10/2026. Espelhada no banco (migration `20261002150000`).

O Lovable informou (02/10/2026) que a instância atual é a menor (Tiny: cerca de 1 GB de memória, 2 vCPUs compartilhadas) e que ela não aguenta 400 pessoas abrindo protocolo no mesmo minuto; recomenda subir para Small ou Medium antes de liberar o acesso, o que pode ser feito pelo painel em 2 a 5 minutos e desfeito depois do pico. O teste de capacidade do C09 (D-94) passou num computador do CI mais forte que o Tiny, então não prova a capacidade do Tiny. Decidir: (1) subir a instância antes de liberar o acesso e manter; (2) subir só nos períodos de pico; ou (3) medir antes numa cópia de homologação do mesmo tamanho. Custo a confirmar no painel do Lovable. Bloqueia a liberação do acesso às pessoas (junto com a D-79).

---

## GI-SAFRA-014 — Região dos dados: Londres (AWS eu-west-2)

**Status:** RESOLVED (D-116, 02/10/2026) — decisão final do owner: nada muda
**Fase:** liberação do acesso às pessoas (depois do C09).
**Bloqueia START/C08:** não.
**Origem:** respostas do Lovable ao C09, 02/10/2026. Espelhada no banco (migration `20261002150000`).

O Lovable informou (02/10/2026) que o banco e os backups ficam na AWS eu-west-2 (Londres, Reino Unido). O Painel guarda nome e e-mail corporativo das pessoas e o que elas registram nos protocolos. Decidir com o jurídico ou o encarregado de dados (DPO) da Editora se a guarda fora do Brasil é aceitável pela LGPD (transferência internacional) ou se o banco precisa ficar no Brasil (por exemplo, um projeto Supabase próprio na região de São Paulo). Nenhum valor é assumido.

---

## GI-SAFRA-015 — Cabeçalhos de segurança e domínio próprio

**Status:** RESOLVED (D-116, 02/10/2026) — decisão final do owner: nada muda
**Fase:** liberação do acesso às pessoas (depois do C09).
**Bloqueia START/C08:** não.
**Origem:** respostas do Lovable ao C09, 02/10/2026. Espelhada no banco (migration `20261002150000`).

Origem: auditoria do Lovable L-02 e resposta de 02/10/2026. No endereço painelsafra.lovable.app o Lovable já envia HSTS e nosniff, mas não deixa configurar Content-Security-Policy nem a proteção contra o app ser embutido em outro site (frame-ancestors/X-Frame-Options). Uma CSP pela tag meta no HTML não cobre frame-ancestors, porque o navegador ignora essa regra fora do cabeçalho. Caminho recomendado: subdomínio da Editora (ex.: safra.editoradobrasil.com.br) passando pela Cloudflare da TI, onde a TI configura os cabeçalhos e pode liberar o limite de login para o IP corporativo. Impacto: o novo endereço precisa entrar nas URLs de retorno do login. Decidir: fazer antes ou depois de liberar o acesso.

---

## GI-SAFRA-016 — Aviso antes do cancelamento automático de 72 h

**Status:** RESOLVED (D-112, 02/10/2026) — lembretes 24 h, 12 h e 1 h antes, a quem ainda não concluiu
**Fase:** SAFRA-M05 (avisos).
**Bloqueia START/C08:** não.
**Origem:** auditoria do M01, 02/10/2026. Espelhada no banco junto com o próximo pacote de migration.

Pela D-101, protocolo sem nenhuma parte concluída é cancelado sozinho 72 horas depois da abertura. Hoje o único aviso é a frase na tela "Meus protocolos"; não há e-mail nem lembrete, porque os avisos dependem da M05 (e do chamado do TI para envio de e-mail). Decidir na M05: avisar antes (por exemplo, com 48 h), quem recebe (quem abriu, o dono do card, os dois) e por qual canal. Nenhum valor é assumido.


## GI-SAFRA-017 — Trocar o envio provisório pelo registro de aplicativo da TI
**Status:** OPEN — aguarda o TI  
**Fase:** M05 (troca do remetente)  
**Bloqueia:** nada; os e-mails já saem sozinhos (D-133)

- **Contexto:** D-132 a D-134. Hoje os avisos saem pela conexão Outlook do Kaue, enviados pelo servidor a cada 2 minutos.
- **Passo intermediário (sem depender do TI):** D-133, envio agendado no servidor a cada 2 minutos pela mesma conexão Outlook.
- **Pendente da TI:** MS_CLIENT_ID, MS_CLIENT_SECRET (com validade e responsável pela renovação) e Application Access Policy restrita a painel.safra@.
- **Ao fechar:** configurar MS_* no Lovable (a função passa a usar o aplicativo sozinha) e retirar as funções `*_for_session` e a conexão Outlook pessoal.

## GI-SAFRA-018 — Semana do protocolo encerrado sozinho na governança semanal

**Status:** OPEN — aguarda o owner  
**Fase:** F05 (D-140)  
**Bloqueia:** nada

Quando só uma parte conclui e o protocolo encerra sozinho 72 h depois (D-113), a governança semanal conta o encerramento na semana em que **a última parte concluiu** (mesma regra dos Indicadores, D-117). Assim, um protocolo pode aparecer "em andamento" na reunião de segunda e depois entrar no resumo da semana anterior. Alternativa: contar na semana do **encerramento automático**. Nenhum valor foi mudado sem decisão.

## GI-SAFRA-019 — Semana permitida para registrar ação de governança

**Status:** OPEN — aguarda o owner  
**Fase:** F05 (D-140)  
**Bloqueia:** nada

Hoje dá para navegar e registrar ação em qualquer semana, inclusive futura. Decidir se o registro deve ficar limitado (por exemplo, só a semana atual e as anteriores).

## GI-SAFRA-020 — Retenção dos e-mails na fila

**Status:** OPEN — aguarda o owner · **Fase:** D-141 · **Bloqueia:** nada
A tabela de avisos guarda para sempre o texto do e-mail (até 6.000 caracteres), o e-mail e o nome de quem recebeu. Decidir por quantos dias guardar (depois disso, apagar o texto ou a linha).

## GI-SAFRA-021 — Operação quando o owner não está

**Status:** OPEN — aguarda o owner · **Fase:** D-141 · **Bloqueia:** nada
A conexão Outlook usada no envio é a do Kaue; a fila de e-mails, "Forçar envio agora" e a marcação da Safra são só dele. Se ele estiver fora, ninguém reconecta o envio nem encerra/inicia a Safra. Decidir quem substitui e o que pode fazer (ligado à GI-SAFRA-017).

## GI-SAFRA-022 — Limite de abertura e cancelamento por pessoa

**Status:** OPEN — aguarda o owner · **Fase:** D-141 · **Bloqueia:** nada
Hoje uma pessoa pode abrir e cancelar em sequência no mesmo card, gerando muitos e-mails ao dono. Decidir se há limite (por exemplo, N por hora) e qual.

## GI-SAFRA-023 — Data mínima do "problema começou"

**Status:** OPEN — aguarda o owner · **Fase:** D-141 · **Bloqueia:** nada
O campo só recusa data no futuro; um ano digitado errado distorce o MTTD da Safra. Decidir o limite (por exemplo, até 7 dias antes da abertura).

## GI-SAFRA-024 — Objetos sem uso no banco

**Status:** OPEN — aguarda o owner · **Fase:** D-141 · **Bloqueia:** nada
Sem uso em nenhuma tela ou função: tabela de medições de impacto (C05), tabelas de sistemas da Matriz v3 (só rastreabilidade), funções antigas de tempo e de resolução de GIs, `safra_session_is_live` pública. Apagar exige migration e ajuste de testes; decidir se apaga ou mantém como histórico.

