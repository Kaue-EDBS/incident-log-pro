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
- regra transitória exige sessão autenticada e `app_metadata.safra_access=true`.

### Alvo

RBAC no SAFRA-C04 por papel, área e vínculo com cenário.

### Identidade corporativa

O Painel Safra utilizará Microsoft Entra ID corporativo via SSO.

O sistema deve armazenar somente os atributos necessários à identidade, autorização e auditoria, evitando replicar informações do diretório corporativo sem finalidade funcional.

## 7. Ameaças baseline

| ID | Ameaça | Controle |
|---|---|---|
| T-01 | acesso anônimo | bloqueado no C00 |
| T-02 | secret no Git | `.env` fora do tracking |
| T-03 | elevação de privilégio | usar `app_metadata`; RBAC futuro |
| T-04 | usuário autenticado executar START/END/CANCEL de forma indevida | auditoria + backend transacional + C04/C05 |
| T-05 | elevação de responsabilidade/role pelo cliente | role mapping server-side + C04 |
| T-06 | cancelamento sem justificativa | CANCELLED + motivo |
| T-07 | exclusão física | proibida no fluxo normal |
| T-08 | edição retroativa de versão | snapshot por scenario_version |
| T-09 | dado pessoal indevido em texto livre | minimização + UX |
| T-10 | integração cria protocolo | ativação humana |
| T-11 | retry duplica ação | idempotência |
| T-12 | ausência de fonte aparece como OK | estados explícitos |
| T-13 | service role no browser | proibido |
| T-14 | auditoria manipulável pelo frontend | persistência backend/DB |

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

- base legal / enquadramento formal: **DEFERRED_TO_PRIVACY_OWNER_BEFORE_REAL_USER_RELEASE**;
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
- a política final de implementação deve ser validada no gate de privacidade antes do release.


## 12. Riscos residuais do SAFRA-C02 — 25/09/2026

| ID | Risco residual | Estado | Fase responsável | Bloqueia C02? |
|---|---|---|---|---|
| RR-C02-01 | uso indevido de START/END/CANCEL por usuário autenticado | DEFERRED_CONTROL | C04/C05/F01/F02 | não |
| RR-C02-02 | role/claim desatualizado em sessão autenticada | DEFERRED_CONTROL | C04 | não |
| RR-C02-03 | enumeração ou leitura excessiva de dados internos | DEFERRED_CONTROL | C04/F08 | não |
| RR-C02-04 | dado pessoal indevido em texto livre/log/notificação | DEFERRED_CONTROL | C08/M05/F08 | não |
| RR-C02-05 | duplicidade por retry/concorrência | DEFERRED_CONTROL | C05 | não |
| RR-C02-06 | manipulação de estado/timestamp para afetar SLA | DEFERRED_CONTROL | C05/C07/M04/F01/F02 | não |
| RR-C02-07 | alteração de cenário/owner/criticidade afetando histórico | DEFERRED_CONTROL | C05/C06/M10 | não |
| RR-C02-08 | destinatário de notificação incorreto ou duplicado | DEFERRED_CONTROL | M05 | não |
| RR-C02-09 | enquadramento/base legal formal ainda não registrado | DEFERRED_GOVERNANCE | privacy owner antes de liberar usuários reais | não para C02; sim para release se continuar aberto |

### Regra de fechamento

O C02 pode ser encerrado porque todos os riscos materiais identificados possuem controle definido, fase responsável, teste esperado e risco residual explícito.

O fechamento de G3.5, THREAT-001 e AUTHZ-001 neste ciclo significa modelo de ameaça e contrato de autorização aprovados. Não significa implementação final de RLS, RBAC, RPCs ou constraints; isso permanece em C04/C05 e fases dependentes.
