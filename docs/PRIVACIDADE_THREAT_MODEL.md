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

**WAITING_HUMAN_DECISION** para classificação formal. O produto não foi desenhado para tratar categorias sensíveis da LGPD.

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

`retention_policy = WAITING_HUMAN_DECISION`.

Até decisão formal:

- não implementar exclusão automática;
- não presumir retenção infinita;
- preservar histórico necessário à auditoria;
- não destruir tratativas no fluxo normal.

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
| T-04 | owner A operar cenário B | C04 + RLS |
| T-05 | updater encerrar protocolo | RB-SAFRA-005 |
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

## 10. Pendências

- base legal / enquadramento formal: **WAITING_HUMAN_DECISION**;
- retenção: **WAITING_HUMAN_DECISION**;
- sensibilidade formal: **WAITING_HUMAN_DECISION**;
- identity provider: **Microsoft Entra ID corporativo via SSO — APPROVED**;
- política de notificações/e-mail: **WAITING_HUMAN_DECISION**.

## 11. Atualização

Mudança de identidade, integração, dados pessoais, retenção, arquivos ou exposição deve atualizar este documento e `PROJECT_PROFILE.yaml`.
