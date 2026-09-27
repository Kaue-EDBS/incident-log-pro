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

Cada abuse case deve permanecer rastreável por **ID, pré-condição, ação maliciosa/abusiva, resultado esperado, controle, fase e teste/evidência**.

| ID | Pré-condição | Ação maliciosa / abuso | Resultado esperado | Controle | Fase | Teste / evidência |
|---|---|---|---|---|---|---|
| AB-START-01 | usuário tenta acionar cenário sem sessão corporativa canônica válida | chamar START com domínio externo, JWT expirado, sessão revogada/inexistente ou identidade anônima | rejeitar sem criar `treatment`, snapshot ou evento | `safra_is_corporate_user()` dentro da RPC; actor por `auth.uid()`; sessão viva | C08 + C02-AUD | `c01_corporate_domains.test.sql`, `c02_threat_model_authz.test.sql`, `c08_start_end_to_end.test.sql` |
| AB-START-02 | cenário publicado e sessão válida; uma requisição START já foi processada | repetir o mesmo START com a mesma idempotency key e o mesmo payload | retornar a mesma tratativa; não criar segundo treatment nem segundo `TREATMENT_OPENED` | unique idempotency key + digest + `pg_advisory_xact_lock` + correlation ID | C08 + C02-AUD | retry sequencial em `c08_start_end_to_end.test.sql`; concorrência real em `.github/scripts/test-safra-start-concurrency.sh` |
| AB-START-03 | existe START associado à idempotency key | reutilizar a mesma chave com payload, cenário, ator ou impacto diferente | rejeitar com `SAFRA_START_IDEMPOTENCY_CONFLICT`; estado original permanece intacto | digest/payload canônico + comparação server-side | C08 + C02-AUD | `c02_threat_model_authz.test.sql` |
| AB-END-01 | existe tratativa ACTIVE ou já terminal | encerrar prematuramente, encerrar duas vezes ou executar END em estado terminal | END só pode partir de ACTIVE; repetição/terminal deve ser rejeitada; ator e tempo vêm do servidor | terminal-state guard + transição explícita + futuro command/RPC governado | F01/F02 | guard atual em `c05_terminal_state_guards.test.sql`; **contrato futuro obrigatório**: testes positivos/negativos de END antes de liberar RPC |
| AB-CANCEL-01 | existe tratativa ACTIVE ou terminal | usar CANCEL para apagar falha, parar SLA, esconder histórico, cancelar repetidamente ou sem motivo | exigir motivo; CANCEL apenas de ACTIVE; preservar treatment/eventos; CANCEL não vira sucesso de SLA | constraint de motivo + terminal-state guard + append-only + engine SLA | C05/C07 + F01/F02 | `c05_terminal_state_guards.test.sql`, `c07_nonnegative_clock_cancel_semantics.test.sql`; **contrato futuro obrigatório** para RPC CANCEL |
| AB-AUTHZ-01 | `sub` pertence a principal com role governada | reutilizar role com domínio externo, sessão revogada/inexistente ou JWT expirado | `safra_has_role=false`, roles vazias e audit sem dados | predicado corporativo canônico também nas funções de RBAC | C02-AUD | `c02_threat_model_authz.test.sql` + verificação direta no PRIMARY |
| AB-OWNER-01 | cenário/owner já está publicado/vinculado ou há tratativa ativa | trocar owner pelo cliente ou reescrever ownership histórico | mutação direta negada; mudança governada e auditável; tratamento ativo conserva snapshot | sem grants diretos + owner history guard + mapping governado | C05/C06 | `c05_technical_guards.test.sql`, `c06_1_owner_mutation_governance.test.sql`, direct API ownership denial |
| AB-CRIT-01 | versão de cenário publicada/retirada ou tratativa já aberta | alterar criticidade retroativamente para modificar leitura histórica | rejeitar rewrite da versão; tratamento ativo mantém snapshot/versionamento original | version freeze + sem grants diretos + nova versão para mudança futura | C05/C06 | guards de `scenario_versions` em `c05_technical_guards.test.sql` e testes de version freeze |
| AB-API-01 | atacante possui somente publishable/anon key ou endpoint conhecido | enumerar tabelas Safra via Data API | `401/403`; nenhum dado devolvido; RLS continua defense-in-depth | revoke de grants + RLS + superfície explícita de smoke | C00/C05 + C02-AUD | `.github/scripts/test-safra-direct-api.sh` cobrindo legado + 17 tabelas Safra |
| AB-DATA-01 | cliente tenta contornar RPC governada | executar INSERT/UPDATE/DELETE diretamente em tabelas Safra | negar por grants/RLS; mutação crítica continua somente por RPC/command governado | deny-by-default + RLS + RPC transacional | C05/C08 | `c05_technical_guards.test.sql`, direct API mutation denial e testes C08 |
| AB-LEAK-01 | usuário conhece RPCs de RBAC/auditoria | enumerar roles ou eventos de auditoria sem sessão corporativa válida ou sem papel administrativo | roles vazias/false; audit retorna zero linhas; nenhum e-mail interno é exposto | sessão corporativa canônica + role admin + grants de EXECUTE restritos | C02-AUD/C04 | `c02_threat_model_authz.test.sql`, direct RPC denial |
| AB-TIME-01 | cliente controla payload ou tenta editar linha persistida | adulterar `opened_at`, timestamps de eventos ou relógio do SLA | ignorar/rejeitar tempo do cliente; usar server clock; sequência inválida bloqueada | timestamps server-side + temporal guards + append-only | C05/C07/C08 | `c05_technical_guards.test.sql`, `c07_boundary_adversarial_matrix.test.sql`, C08 START |
| AB-VERSION-01 | cenário possui versão publicada/retirada e tratamentos apontam para ela | editar versão antiga para mudar uma tratativa ativa/histórica | rejeitar edição retroativa; treatment permanece ligado ao `scenario_version_id` congelado | version freeze + snapshot de versão no START | C05/C08 | testes de version freeze C05 + snapshot C08 |
| AB-RETRY-01 | duas transações START simultâneas usam a mesma chave e payload | double submit/retry concorrente tenta duplicar abertura | exatamente um treatment e um `TREATMENT_OPENED`; ambas resolvem para o mesmo treatment | advisory lock + unique key + idempotência server-side | C08 + C02-AUD | `.github/scripts/test-safra-start-concurrency.sh` |
| AB-SLA-01 | tratamento possui SLA estruturado ou leitura histórica por `as_of` | tentar “parar” SLA via CANCEL, inserir evento futuro ou manipular referência temporal | CANCEL não vira sucesso; evento futuro não reescreve snapshot; relógio inválido vira estado explícito | engine determinística + server clock + historical snapshot guard | C07 | `c07_boundary_adversarial_matrix.test.sql`, `c07_nonnegative_clock_cancel_semantics.test.sql`, `c07_historical_snapshot_clock_guard.test.sql` |
| AB-CARD-01 | usuário possui sessão válida e acesso ao fluxo de proposta | transformar proposta/12º card em cenário produtivo sem aceite/governança | proposta permanece separada; não entra no catálogo produtivo nem cria scenario automaticamente | proposal separado de scenario + ownership/governança humana + ausência de RPC produtiva de publicação automática | M10 | **contrato futuro obrigatório**: proposta não altera catálogo produtivo; publicação exige fluxo de aprovação; cenário/card só nasce após governança definida |

#### Regra de não antecipação funcional

Os contratos de abuso de **END, CANCEL e 12º card** estão definidos agora para que a implementação futura nas fases responsáveis já nasça testável. Esta reauditoria **não autoriza** criar RPC/command produtivo dessas funcionalidades antes de F01/F02/M10.

Antes de qualquer PASS funcional futuro:

- END deve possuir teste de ACTIVE → RESOLVED, END repetido, END em terminal, ator/timestamp server-side e idempotência;
- CANCEL deve possuir teste de motivo obrigatório, ACTIVE → CANCELLED, repetição/terminal, preservação de histórico, impacto em SLA e idempotência;
- 12º card deve possuir teste de separação proposal/scenario, governança de owner, ausência de autopublicação e trilha auditável da decisão.

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
| RR-C02-02 | role/claim desatualizado ou sessão revogada | CONTROLLED_VERIFIED_C02_AUD | canonical predicate em role lookup/audit; domínio externo, sessão revogada e JWT expirado verificados em CI + PRIMARY | não |
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
