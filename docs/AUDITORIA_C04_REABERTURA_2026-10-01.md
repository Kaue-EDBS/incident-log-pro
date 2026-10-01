# AUDITORIA C04 — REABERTURA (C04-AUD2)

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C04 — Identidade, RBAC e RLS  
**Data:** 01/10/2026  
**Estado:** CONCLUÍDA — com uma ação recomendada ao owner (desligar o login por e-mail no Lovable)  
**Migration:** `20261001180000_c04_aud2_identity_hardening.sql` (CI verde: App Smoke #236, Database Disposable #274; aplicada e conferida no PRIMARY)  
**Testes novos:** `c04_aud2_identity_authz.test.sql` (18) e `c04_aud2_hardening.test.sql` (8)

---

## 1. O que o C04 cuida (em linguagem simples)

**Quem pode entrar** (identidade), **o que cada pessoa pode fazer** (papéis/RBAC) e **quais linhas do banco cada um enxerga** (RLS). Esta rodada testou os 7 pontos pedidos pelo owner e fez, a pedido dele, uma auditoria própria além deles.

---

## 2. Os 7 testes do C04

| # | Teste | Resultado | Evidência |
|---|---|---|---|
| 1 | `anon` bloqueado para ler e escrever | PASS | `c00_security_regression` (schema público inteiro), `c05_schema_v2`, smoke HTTP das 17 tabelas, smoke de RPC |
| 2 | Sessão expirada não produz efeito | PASS | `c04_aud2_identity_authz`: token expirado e sessão revogada são recusados no START, sem tratativa nem evento |
| 3 | START/END/CANCEL com as regras de autorização | PASS (START) / CONTRATO (END/CANCEL) | START: `c08`, `c01_aud2_package`, `c02_aud2_owner_start`. END/CANCEL não existem (F01/F02): teste prova que não há função nem escrita direta para isso; regras D-64/D-66 viram testes obrigatórios da F01/F02 |
| 4 | Elevação de privilégio pelo payload | PASS | papel forjado no JWT, `app_metadata` ou `user_metadata` não dá papel nem acesso à auditoria; START não aceita dono/versão/horário; dono não se autoatribui |
| 5 | Separação Jair / Bruno / Jiane | PASS | Jair é o único `safra_governance_admin` e lê a auditoria; Bruno só `safra_executive_admin`, sem poder técnico nem auditoria; Jiane só `scenario_owner`, sem governança. Bruno terá visão consolidada em analytics (F04), sem poder técnico (RB-SAFRA-018) |
| 6 | Platform admin não herda ownership | PASS | `c06_02_rbac_ownership`, `c06_1_owner_no_inheritance_no_fallback` |
| 7 | REST/RPC com as mesmas regras da UI | PASS | UI só chama RPCs governadas (`check-c06-1-ui-auth-coherence`); `authenticated` sem acesso direto às tabelas; regras aplicadas no banco |

**Achado nesta etapa:** troca e revogação de papel e sessão revogada só eram testadas pela função `private.safra_c04_selftest`, rodada uma vez no PRIMARY em 25/09 e fora do CI. **Tratamento:** os mesmos casos foram trazidos para o CI e a função foi removida.

---

## 3. Auditoria própria (além dos 7 pontos)

### C04-AUD2-01 — Cadastro podia ser "ocupado" por login não-Microsoft — ALTA — CORRIGIDO

O gatilho que liga um login (`auth.users`) ao cadastro (`private.safra_principals`) usava só o e-mail, sem conferir provedor nem confirmação. Com o login por e-mail ligado e o cadastro aberto no Lovable (confirmado por print do owner), alguém poderia criar conta com o e-mail de um dos **7 cadastros ainda sem login** e ocupá-lo. Não ganharia poderes (o predicado exige Microsoft), mas a pessoa real ficaria sem o papel.

Verificado no PRIMARY: **nenhuma ocupação ocorreu** (2 logins, ambos Microsoft e confirmados).

**Correção:** o gatilho só liga logins com `provider = azure`, não anônimos; também reage a mudança de `raw_app_meta_data`. Cadastro já ligado nunca é religado. Testes: `c04_aud2_hardening`.

**Ação recomendada ao owner:** desligar o método **Email** no Lovable Cloud Auth (ADR-023: Microsoft é o único login). Manter "Disable sign-up" desligado, senão quem ainda não entrou não consegue entrar pela Microsoft.

### C04-AUD2-02 — Conta `sandbox_exec` do Lovable ignora as regras — ALTA — RISCO ACEITO

A conta interna `sandbox_exec` (usada pelas ferramentas do Lovable) tem `BYPASSRLS`, lê tabelas de `auth` (inclusive tokens) e grava nas tabelas Safra. O projeto está como "editável pelo workspace".

**Decisão do owner (01/10/2026):** o workspace "Inteligência's Lovable" é fechado para o time técnico. A segurança do app vale para quem usa o **app**; o acesso ao **Lovable** é restrito ao time. Não é corrigível pelo código (conta da plataforma).

### C04-AUD2-03 — Objetos novos nasciam abertos — MÉDIA — CORRIGIDO

Os privilégios padrão do schema `public` davam acesso total a `anon`/`authenticated` em toda tabela, sequência e função nova, e `EXECUTE` a `PUBLIC` em toda função nova.

**Correção:** `ALTER DEFAULT PRIVILEGES` para o papel `postgres`: objetos novos em `public` nascem fechados para `anon`/`authenticated`, e funções novas não recebem `EXECUTE` para `PUBLIC`. Testes: `c04_aud2_hardening` cria tabela, função e sequência e confere que nascem fechadas.

**Risco residual:** os privilégios padrão do papel `supabase_admin` (plataforma) e do schema `storage` continuam abertos; não há buckets nem tabelas nossas nesses caminhos. A proteção final continua sendo o teste do schema público inteiro (`c00_security_regression`).

### C04-AUD2-04 — Restos de teste no PRIMARY — BAIXA — CORRIGIDO

`private.safra_c04_selftest` e `private.safra_c04_test_runs` (28 registros de 25/09) removidos.

### Verificado e correto

- nenhuma policy RLS em `public`/`private` (deny-by-default; acesso só por RPC governada);
- todas as funções `SECURITY DEFINER` com `search_path = ''`;
- nenhuma tabela em Realtime, nenhum bucket de Storage, nenhuma view, nenhuma extensão no `public`;
- todos os logins são Microsoft e corporativos; nenhum papel ativo em cadastro inativo;
- `anon` sem `USAGE` no schema `private`.

### Fora do alcance por SQL

Duração da sessão/JWT, MFA e política de senha são configurações do Lovable Cloud Auth e do Microsoft Entra (MFA é controle corporativo externo, ADR-033).

---

## 4. Gates

| Gate | Resultado |
|---|---|
| G5 / ID-001 / ID-002 / AUDIT-001 (C04) | **PASS** — agora com regressão no CI, não só autoteste no PRIMARY |

Pendência para F01/F02: testes das regras de END/CANCEL (D-64/D-66) quando os comandos existirem.
