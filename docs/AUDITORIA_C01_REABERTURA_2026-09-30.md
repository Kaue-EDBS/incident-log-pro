# AUDITORIA C01 — SEGUNDA REABERTURA (C01-AUD2)

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C01 — Documentação canônica e PROJECT_PROFILE  
**Data de abertura:** 30/09/2026  
**Estado:** EM EXECUÇÃO — documentação reconciliada; migration de alinhamento dos GI pendente de aplicação no PRIMARY; perguntas dos GI em andamento com o owner  
**Decisões geradas:** D-52, D-53, D-54 (`docs/DECISOES.md`)

---

## 1. O que o C01 cuida (em linguagem simples)

O C01 define **quais arquivos são a fonte oficial de cada assunto** e mantém a **ficha técnica** do sistema (`PROJECT_PROFILE.yaml`). Se a ficha ou os documentos oficiais estiverem errados, quem for mexer no projeto parte de uma premissa errada.

Esta rodada comparou o que os documentos afirmam com o estado real do código e do banco PRIMARY em 30/09/2026.

---

## 2. O que foi conferido e bateu

| Item | Documento dizia | Realidade no PRIMARY |
|---|---|---|
| Usuários de login | 2 | 2, todos Microsoft (`azure`), nenhum fora dos domínios aprovados |
| Pessoas cadastradas vinculadas ao login | 2 | 2 |
| Papéis ativos | 9 | 9 (mais 1 papel temporário de teste já revogado) |
| Acesso anônimo | nenhum | nenhum |
| Tabelas sem RLS | nenhuma | nenhuma |
| Domínios aceitos | 2 | 2 |

---

## 3. Achados

### C01-AUD2-01 — Ficha técnica desatualizada

**O que era:** `known_drift: []` (sem diferença entre banco e repositório), `legacy_applications_incidents_preserved: true`, `legacy_it_rules_registered: 4`, `legacy implementation` como fonte de precedência, e sem GI-SAFRA-010 nem métricas do protocolo.

**Realidade:** 31 migrations no PRIMARY contra 28 arquivos no repositório (C00-AUD2-07); legado removido pela D-50.

**Tratamento:** ficha corrigida; `known_drift` agora lista as 3 versões, com a fase responsável (C05); regra D-52 registrada na ficha.

### C01-AUD2-02 — Pendências de governança em três lugares divergentes

**O que era:**

| Item | `DECISOES.md` | `GOVERNANCE_ISSUES.md` | Banco |
|---|---|---|---|
| GI-004 a 008 | OPEN / DEFERRED | WAITING_HUMAN_DECISION | OPEN, texto começando com "WAITING_HUMAN_DECISION" |
| GI-009 | OPEN | RESOLVED_FOR_C08 | OPEN |
| GI-010 | existia | não existia | não existia |

Pela regra do próprio C01, `WAITING_HUMAN_DECISION` bloqueia o fechamento. Isso contradizia o `unknown_material_count = 0`.

**Tratamento (D-53):**
- `GOVERNANCE_ISSUES.md` virou a fonte oficial única, com vocabulário de status e tabela-resumo;
- statuses padronizados (GI-004 a 008 como `OPEN — DEFERRED_TO_<fase>`; GI-009 como `OPEN — NON_BLOCKING (D-47)`);
- GI-SAFRA-010 criado;
- `DECISOES.md` passa a indexar;
- migration `20260930150000_c01_aud2_governance_issues_alignment.sql` alinha o banco (troca só o início do texto das GI-004 a 008 e insere a GI-010), com teste `c01_aud2_governance_alignment.test.sql`.

### C01-AUD2-03 — Documentos oficiais ausentes da lista

`GOVERNANCE_ISSUES.md` e `GLOSSARIO_DOMINIO.md` (canônico desde o C03) não estavam no README nem na ficha.

**Tratamento:** incluídos nos dois.

### C01-AUD2-04 — STATUS e ROADMAP violando a regra de autoridade do C01

**O que era:** `STATUS.md` com 3.153 linhas de histórico acumulado; `ROADMAP.md` com 3.060 linhas repetindo estado, perfil, pessoas, decisões, modelo de domínio e regras que têm documento próprio.

**Tratamento (D-54):**
- originais movidos **sem alteração** para `docs/historico/STATUS_ate_2026-09-30.md` e `docs/historico/ROADMAP_v2.2_ate_2026-09-30.md` (por `git mv`, preservando o histórico de linhas);
- novo `STATUS.md` (~70 linhas) só com o estado atual;
- novo `ROADMAP.md` v3.0 (~1.380 linhas) com mapa de documentos, tabela de estado das fases, fases em aberto (C08, C09, MEIO, FIM), jornada, testes, gates e critérios. Numeração de seções preservada.

### C01-AUD2-05 — Dados pessoais na ficha

**O que era:** bloco `jair_runtime_access` com e-mail e horário de login de uma pessoa.

**Tratamento:** removido. A ficha agora só indica que o cadastro de pessoas é `private.safra_principals` e os papéis são `private.safra_role_grants`. A evidência de acesso continua na auditoria do C04. O dado permanece no histórico Git, que não é reescrito.

### C01-AUD2-06 — Descrição do projeto no Lovable

A descrição do projeto no Lovable ainda descreve o monitor de MTTR. **Ação do owner** (fora do repositório).

### C01-AUD2-07 — Exposição pelo repositório público

Em 30/09/2026 o repositório ficou público para rodar o CI com minutos gratuitos. Ficaram visíveis e-mails e papéis de 9 pessoas e a matriz de contingência. Não há segredo versionado (C00). Isso contraria D-48 (uso interno) e a minimização de dados. **Decisão e comunicação a cargo do owner.**

### C01-AUD2-08 — Recorrência de drift

Causa: o Lovable permite alterar o banco por caminhos que não salvam o arquivo de migration.

**Tratamento (D-52):** toda mudança no banco nasce como arquivo no repositório; conferência PRIMARY × repositório no início de cada sessão; regra registrada em `AGENTS.md`, `DECISOES.md` e na ficha.

---

## 4. Fora do escopo, encaminhado

- Estado da C02-AUD (ficha e STATUS dizem "em execução"; roadmap dizia "concluído") → próxima reauditoria.
- Drift de 3 migrations → reauditoria do C05.

---

## 5. Gate de fechamento

- [x] ficha técnica coerente com o PRIMARY
- [x] fonte única dos GI definida e statuses padronizados nos documentos
- [ ] migration de alinhamento dos GI aplicada no PRIMARY e registrada
- [ ] CI verde com a migration nova
- [ ] rodada de perguntas dos GI com o owner concluída e registrada
- [ ] `unknown_material_count = 0` recertificado ao final
