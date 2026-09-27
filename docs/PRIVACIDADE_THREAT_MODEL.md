# PRIVACIDADE E THREAT MODEL — Painel Safra

> Documento canônico de privacidade e baseline de ameaças.
> O aprofundamento de abuso de negócio ocorre no SAFRA-C02.

## 1. Escopo

Aplicação interna de governança de contingências. Dados pessoais só devem existir quando necessários para identidade, autorização, atribuição, auditoria e comunicação operacional.

## 2. Categorias de dados

### Esperados

- ID de usuário interno;
- nome;
- e-mail corporativo;
- papel funcional;
- vínculo com área/cenário;
- autoria de START/UPDATE/END/CANCEL;
- responsável por tratativa.

### Texto livre

Notas, causa e resolução podem receber dados pessoais incidentalmente.

**Regra:** texto livre não deve armazenar credenciais, secrets ou dados pessoais sem finalidade operacional.

### Dados pessoais sensíveis

**Fora do escopo intencional aprovado.** O produto não foi desenhado para coletar categorias sensíveis. Ocorrência incidental em texto livre deve ser minimizada e tratada como exceção de privacidade.

### Crianças e adolescentes

Fora do escopo funcional.

## 3. Finalidades

- autenticação;
- autorização;
- governança operacional;
- auditoria;
- comunicação;
- histórico;
- melhoria de processo;
- métricas agregadas.

## 4. Minimização

Evitar CPF, telefone pessoal, endereço residencial, credenciais, tokens, senhas, dados médicos, bancários ou conteúdo sem relação com o protocolo.

## 5. Retenção

**APPROVED.**

- dados pessoais identificáveis permanecem até o encerramento formal da Safra e enquanto necessários para auditoria/pós-mortem;
- depois da finalidade, eliminar ou anonimizar;
- histórico operacional e métricas podem permanecer entre Safras sem identificação pessoal quando ela não for necessária;
- tratativas não são destruídas silenciosamente no fluxo normal.

## 6. Acesso

### Atual

- `anon` sem acesso ao banco;
- Microsoft Entra ID corporativo homologado via SSO;
- autorização governada por `private.safra_principals` + `private.safra_role_grants`;
- predicado corporativo exige sessão válida, não anônima, provider Azure e e-mail pertencente a `editoradobrasil.com.br` ou `editoradobrasil1.onmicrosoft.com`;
- `app_metadata.safra_access` foi removido como mecanismo de autorização;
- ownership de cenário depende de vínculo explícito em `scenario_owners`, sem herança automática de papel administrativo.

### Evolução posterior ao C02

Os controles desenhados no C02 foram materializados progressivamente em C04/C05/C06/C07. O threat model continua sendo a fonte das ameaças e do contrato de teste; a implementação corrente é descrita em ROADMAP, STATUS, ARQUITETURA e migrations canônicas.

### Identidade corporativa

O Painel Safra utiliza Microsoft Entra ID corporativo via SSO. O acesso funcional é restrito aos domínios `editoradobrasil.com.br` e `editoradobrasil1.onmicrosoft.com`.

O sistema deve armazenar somente os atributos necessários à identidade, autorização e auditoria, evitando replicar informações do diretório corporativo sem finalidade funcional.

## 7. Ameaças baseline

| ID | Ameaça | Controle atual / contrato |
|---|---|---|
| T-01 | acesso anônimo | grants mínimos + RLS; smoke HTTP/RPC de negação |
| T-02 | secret no Git/browser | `.env` fora do tracking + browser recusa `sb_secret_`/service_role |
| T-03 | elevação de privilégio | RBAC governado no banco; `user_metadata` e flag legado `safra_access` não autorizam |
| T-04 | usuário autenticado executar START/END/CANCEL de forma indevida | predicado corporativo canônico + RPC transacional + guards de estado; END/CANCEL ainda sem RPC produtiva |
| T-05 | elevação de responsabilidade/role pelo cliente | role mapping server-side + vínculo explícito de owner + trilha de RBAC |
| T-06 | cancelamento sem justificativa ou para mascarar SLA | motivo obrigatório + somente de ACTIVE + CANCEL não conta como sucesso + histórico preservado |
| T-07 | exclusão física | treatments/ownership/eventos protegidos contra destruição/reescrita |
| T-08 | edição retroativa de versão | version freeze + treatment congela `scenario_version_id` |
| T-09 | dado pessoal indevido em texto livre | minimização + finalidade + UX/revisão |
| T-10 | integração/proposta cria protocolo sem governança | ativação humana; proposal não publica card/cenário automaticamente |
| T-11 | retry/double submit duplica ação | idempotência + unique key + advisory lock + correlation ID |
| T-12 | ausência de fonte aparece como OK | estados explícitos `NOT_MEASURABLE`/`NOT_CONFIGURED` e sem inferência |
| T-13 | service role no browser | proibido + guard de inicialização do client |
| T-14 | auditoria manipulável ou exfiltrada pelo frontend | persistência DB/server + roles + sessão corporativa canônica |
| T-15 | token antigo/revogado reutiliza role já vinculada | `auth.sessions` viva + expiração JWT + domínio/provider aprovados também nas funções de RBAC |
| T-16 | timestamps/eventos futuros alteram leitura histórica | server clock + append-only + engine temporal com `as_of` |

### 7.1 Abuse cases canônicos

| ID | Ação de abuso | Resultado obrigatório | Controle atual / fase |
|---|---|---|---|
| AB-START-01 | usuário sem sessão corporativa válida tenta START | rejeitar sem criar treatment/evento | `safra_is_corporate_user()` dentro da RPC; C08 |
| AB-START-02 | retry do mesmo START com mesma chave/payload | devolver a mesma tratativa, sem duplicar evento | idempotency key + advisory lock + digest |
| AB-START-03 | mesma idempotency key com payload/ator/cenário diferente | rejeitar `SAFRA_START_IDEMPOTENCY_CONFLICT` | RPC START |
| AB-END-01 | END prematuro, repetido ou em estado terminal | rejeitar; END só parte de ACTIVE e usa horário oficial | guard já existe; command/RPC fica DEFERRED_TO_F01/F02 |
| AB-CANCEL-01 | CANCEL usado para apagar falha, parar relógio ou esconder histórico | exigir motivo; preservar tratamento/eventos; não contabilizar como sucesso | constraint/guard + engine SLA; command/RPC DEFERRED_TO_F01/F02 |
| AB-AUTHZ-01 | token expirado, sessão revogada ou domínio externo reutiliza role ligada ao `sub` | role lookup/audit retornam vazio/false e nenhum dado sensível | predicado corporativo também nas funções RBAC; C02-AUD |
| AB-OWNER-01 | cliente tenta trocar owner, criticidade ou versão de tratativa ativa | bloquear rewrite; nova decisão/versionamento não altera snapshot já aberto | no direct grants + owner history guard + version freeze |
| AB-API-01 | cliente enumera tabelas pela Data API | 401/403/sem grant; RLS permanece defense-in-depth | smoke cobre superfície Safra inteira |
| AB-DATA-01 | cliente tenta INSERT/UPDATE/DELETE direto em tabelas Safra | negar por grant/RLS; mutações críticas somente por RPC governada | C05/C08 |
| AB-LEAK-01 | usuário autenticado tenta extrair RBAC audit/roles sem sessão válida | retornar vazio/false; audit só para admin corporativo válido | C02-AUD |
| AB-TIME-01 | cliente adultera `opened_at`, timestamps ou relógio de SLA | ignorar input de relógio; usar server clock e campos imutáveis | C05/C07/C08 |
| AB-VERSION-01 | editar versão publicada/retirada para alterar tratativa ativa | rejeitar edição retroativa; tratamento continua na versão congelada | version guards |
| AB-RETRY-01 | duas requisições concorrentes disputam a mesma chave START | exatamente uma tratativa e um `TREATMENT_OPENED` | advisory lock + unique key + teste concorrente |
| AB-SLA-01 | tentar “parar” SLA via CANCEL, evento futuro ou `as_of` manipulado | CANCEL não é sucesso; futuro não reescreve snapshot; raw evaluator não é client-callable | C07 |
| AB-CARD-01 | publicar 12º card/proposta sem governança | proposta não entra no catálogo produtivo automaticamente | DEFERRED_TO_M10; sem RPC produtiva de publicação nesta fase |

### 7.2 Threat → controle → evidência

| Classe | Controles | Evidências obrigatórias |
|---|---|---|
| autorização | canonical corporate predicate, live session, role mapping, owner mapping | `c01_corporate_domains.test.sql`, `c02_threat_model_authz.test.sql`, direct RPC denial |
| Data API | revoke grants + RLS deny-by-default | direct API smoke cobrindo legado + 17 tabelas Safra |
| START/retry | server-side RPC, immutable snapshot, idempotency, advisory lock, correlation ID | C08 pgTAP + C02 conflito de chave + teste concorrente real |
| histórico/versionamento | guards de versão/owner/treatment + append-only | C05/C06 tests |
| tempo/SLA | server timestamps + engine de SLA + snapshot histórico | matriz adversarial C07 |
| END/CANCEL | guard terminal e motivo obrigatório; commands ainda futuros | testes de guard atuais + contrato AB-END/AB-CANCEL antes da RPC futura |
| proposta/12º card | proposal separado de scenario produtivo | contrato AB-CARD-01; implementação futura M10 |
| minimização | campos necessários, texto livre governado, sem secrets | privacy review + D-49 |

## 8. Trust model

Não confiar em:

- browser;
- parâmetros do cliente;
- `user_metadata`;
- owner enviado como texto sem validação;
- origem externa sem contrato;
- estado calculado só no frontend.

Confiar apenas após validação em Auth, `app_metadata` administrado, RLS, funções/RPC, constraints e eventos persistidos.

## 9. Privacy by design

Toda nova funcionalidade deve responder:

1. qual dado pessoal entra?
2. por que é necessário?
3. quem pode ver?
4. quem pode alterar?
5. por quanto tempo fica?
6. qual trilha de auditoria existe?
7. há alternativa com menos dados?
8. há integração externa?
9. existe DATA_RELEASE?
10. o dado aparece em relatório executivo?

## 10. Pendências e deferimentos

- base legal / enquadramento formal: **SATISFIED — confirmação de governança registrada em D-49 em 27/09/2026**;
- retenção: **APPROVED**;
- dados sensíveis: **fora do escopo intencional aprovado**;
- identity provider: **Microsoft Entra ID corporativo via SSO — APPROVED**;
- política/provedor de notificações/e-mail: **DEFERRED_TO_SAFRA_M05**.

## 11. Atualização

Mudança de identidade, integração, dados pessoais, retenção, arquivos ou exposição deve atualizar este documento e `PROJECT_PROFILE.yaml`.


## Política de retenção aprovada — 24/09/2026

**Status: APPROVED**

- fronteira operacional: encerramento formal da Safra;
- extensão permitida: somente enquanto identidade for necessária para auditoria/pós-mortem;
- após a finalidade: eliminar ou anonimizar dados pessoais identificáveis;
- histórico e métricas podem permanecer para análises comparativas entre Safras sem identificação pessoal quando ela não for necessária;
- o gate de privacidade/base legal exigido antes do release com usuários reais foi confirmado como atendido em D-49; a política de retenção permanece obrigatória.


## 12. Riscos residuais do SAFRA-C02 — atualização C02-AUD 27/09/2026

| ID | Risco residual | Estado atual | Controle/fase restante | Bloqueia recertificação? |
|---|---|---|---|---|
| RR-C02-01 | uso indevido de START/END/CANCEL por usuário autenticado | START_CONTROLLED / END_CANCEL_CONTRACT_DEFINED | START C08; END/CANCEL F01/F02 | não, desde que RPC futura cumpra AB-END/AB-CANCEL |
| RR-C02-02 | role/claim desatualizado ou sessão revogada | CONTROLLED_C02_AUD | canonical predicate também em role lookup/audit | sim até testes/PRIMARY confirmarem |
| RR-C02-03 | enumeração ou leitura excessiva de dados internos | CONTROLLED_CURRENT_SURFACE | sem grants diretos + RLS + full Data API smoke | não |
| RR-C02-04 | dado pessoal indevido em texto livre/log/notificação | RESIDUAL_ACCEPTED_WITH_MINIMIZATION | UX C08 + notificações M05 + relatórios F08 | não |
| RR-C02-05 | duplicidade por retry/concorrência | CONTROLLED_START | unique idempotency + advisory lock + retry/conflict/concurrency tests | não |
| RR-C02-06 | manipulação de estado/timestamp para afetar SLA | CONTROLLED_CURRENT_SURFACE | server clock + immutable events + C07; commands END/CANCEL futuros | não |
| RR-C02-07 | alteração de cenário/owner/criticidade afetando histórico | CONTROLLED_HISTORY | owner/version guards + snapshot; novas decisões criam nova versão | não |
| RR-C02-08 | destinatário de notificação incorreto ou duplicado | DEFERRED_TO_M05 | política/provider/dedupe de notificação | não |
| RR-C02-09 | enquadramento/base legal formal | CLOSED_BY_D49 | governança/privacidade | não |

### Regra de fechamento

O C02 pode ser encerrado porque todos os riscos materiais identificados possuem controle definido, fase responsável, teste esperado e risco residual explícito.

O fechamento de G3.5, THREAT-001 e AUTHZ-001 neste ciclo significa modelo de ameaça e contrato de autorização aprovados. Não significa implementação final de RLS, RBAC, RPCs ou constraints; isso permanece em C04/C05 e fases dependentes.


## 13. Auditoria retrospectiva das 7 ações do C02 — 26/09/2026

O fechamento do C02 foi reavaliado contra o roadmap e as implementações posteriores.

| Ação | Estado da especificação C02 | Estado atual da evidência |
|---|---|---|
| ameaças de negócio centrais | PASS | ameaças registradas e preservadas |
| abusos API/dados/retry/SLA | PASS histórico / RECONCILIADO C02-AUD | abuse cases canônicos definidos nas seções 7.1–7.2 e ligados a controles/testes atuais |
| controles + fase responsável | PASS | todos os controles possuem destino; vários já implementados em C04-C07 |
| quatro classes de testes | PASS | positivos, negativos, concorrência/retry e limites/bordas derivados |
| contrato de evidência | PASS | ator, correlation_id, estados, ação, resultado, auditoria, timestamps, notificações e efeitos colaterais definidos |
| riscos residuais | PASS | riscos explicitados e com owner/fase; não significam default ou inferência |
| gates C02 | PASS histórico / RECERTIFICAÇÃO EM EXECUÇÃO | G3.5, THREAT-001 e AUTHZ-001 só voltam a PASS atual após correções, gates e verificação no PRIMARY |

Observação: o C02 aprova modelo de ameaça, abuso e contrato de autorização. A execução integral de todos os testes funcionais permanece distribuída nas fases de implementação previstas no roadmap; isso não reabre o C02.
