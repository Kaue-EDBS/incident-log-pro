# AUDITORIA C06 — REABERTURA (C06-AUD2)

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C06 — Seed canônico da Matriz v3  
**Data:** 01/10/2026  
**Estado:** CONCLUÍDA  
**Migration:** `20261001220000_c06_aud2_governance_issue_texts.sql` (CI verde: App Smoke #242, Database Disposable #280; aplicada e conferida no PRIMARY, 37 = 37)  
**Testes/verificadores novos:** `c06_aud2_package.test.sql` (10) e `.github/scripts/check-c06-staging-integrity.py`

---

## 1. O que o C06 cuida (em linguagem simples)

Levar os **11 cards da Matriz v3** (planilha `EDB06 - Matriz Contingencia v3.xlsx`) para o banco **sem redigitar nada**, e provar que planilha e banco dizem a mesma coisa. O C06 original foi feito em 25/09/2026. Esta rodada refez a conferência com o banco de hoje (cards na versão 2 CRITICAL) e fez uma auditoria própria.

---

## 2. Os 7 passos do C06

| # | Passo | Resultado | Evidência |
|---|---|---|---|
| 1 | Pipeline versionado XLSX → parser → staging → validação → diff → aprovação → seed → reconciliação | PASS | `scripts/c06_matrix_pipeline.py` 1.0.0; artefatos em `docs/data-contracts/`; `C06_02_PIPELINE.md` |
| 2 | Importar sem redigitação | PASS | o parser recusa planilha com assinatura diferente da aprovada (`b0cca8cc…`); textos preservados literalmente |
| 3 | Validar os campos | PASS | dono, área responsável, áreas impactadas, protocolo (5 passos), SLA textual, ferramenta e EDB05/EDB06 nos 11 cards; 0 erros |
| 4 | Exatamente os 11 cenários | PASS | 11 no PRIMARY; nenhum fora de `SAFRA-01..11`; nenhuma proposta publicada |
| 5 | Lacunas viram GI, sem valor inventado | PASS | `X h`, `X min`, lead time/fila, capacidade → GI-SAFRA-002; mínimo curva A → GI-SAFRA-003 (ambas D-56, V2/V3) |
| 6 | P1–P4 não publicados por inferência | PASS | os 4 marcos de produto seguem `NOT_PUBLISHED`; critérios revistos (achado 5) |
| 7 | Reconciliação de 100% dos campos | PASS | planilha reprocessada hoje: mesma assinatura, staging idêntico, `NO_DIFF`; PRIMARY = staging em 11 cenários × 18 campos |

**Nomes dos cards:** a lista resumida do ROADMAP usa nomes curtos; o banco guarda o nome literal da planilha. Decisão do owner: **fica o nome literal** (D-74); a exibição da quebra de linha do SAFRA-04/05 é tema da C08.

---

## 3. Auditoria própria

### C06-AUD2-01 — Planilha fora do alcance — MÉDIA — RESOLVIDO

A planilha não estava mais na máquina, então a ligação planilha → staging não podia ser refeita. O owner forneceu o arquivo; o parser rodou com a assinatura esperada e gerou staging idêntico ao registrado (`242a31fc…`), validação `PASS` e diff `NO_DIFF`. A planilha **não** vai para o repositório (que está público); fica com o owner em local controlado.

### C06-AUD2-02 — Registros de conferência descreviam o estado de 25/09 — MÉDIA — CORRIGIDO

`c06_matriz_v3_reconciliation.json` e `c06_02_field_reconciliation.json` descreviam a versão 1 com criticidade vazia. Novo registro `c06_aud2_reconciliation_2026-10-01.json` com o estado atual: versão 2 PUBLISHED CRITICAL, versão 1 RETIRED, `source_reference` da v2 igual ao da v1, e **criticidade vinda da D-55 (decisão do owner), não da planilha**. Os arquivos de 25/09 ficam como histórico.

### C06-AUD2-03 — Staging sem proteção no CI — BAIXA — CORRIGIDO

Uma edição manual do staging não seria percebida. Novo verificador no App Smoke Test confere a assinatura do staging, a cadeia de hashes (manifesto, validação, diff, aprovação, reconciliação) e a igualdade com os 24 blocos de dados embutidos no teste de reconciliação.

### C06-AUD2-04 — Textos das pendências desatualizados no banco — BAIXA — CORRIGIDO

As descrições de GI-002/003/005/006/007 e a resolução da GI-009 citavam decisões antigas (a GI-009 ainda falava da escada 2h/3h/4h, substituída pela D-67). A migration alinha os textos com `GOVERNANCE_ISSUES.md`; **nenhum status mudou**. A função de resolução da C01-AUD2 também passou a gravar o texto novo, para um banco reconstruído chegar ao mesmo resultado.

### C06-AUD2-05 — Marcos P2–P4 pediam conceitos removidos — BAIXA — CORRIGIDO

`P1_P4.json` 1.2.0: "SLA começa/roda certo" virou "escada de avisos começa/roda certo" (D-67); "escalonamento auditável" saiu (D-73); "SLA à prova de adulteração" virou "horários de encerramento à prova de adulteração" (D-66); entrou "encerramento em duas partes funciona" (D-66). O verificador recusa critérios começando com `SLA_` ou `ESCALATION_`.

### C06-AUD2-06 — Testes antigos afirmavam pendências "abertas" — BAIXA — CORRIGIDO

`c07_governance_issues`, `c08_pre_gate_governance` e `c01_aud2_governance_alignment` exigiam GI-001/009/010 `OPEN`. Passavam no CI só porque o banco descartável não tem o login do Kaue (a resolução da C01-AUD2 depende dele); no PRIMARY elas estão `RESOLVED`. Os testes agora aceitam os dois estados válidos: aberta, ou resolvida **somente** com decisão citada (D-55, D-62, D-63).

### Verificado e correto

- 7 áreas e 10 ferramentas no catálogo; 20 vínculos de áreas impactadas e 11 de ferramentas na versão vigente;
- SLA textual preservado literalmente; `scenario_slas` vazio (D-62);
- donos: Daniel (01, 02, 03, 07, 10, 11), Jiane (04, 05, 06, 08), Renato (09); nenhum admin com ownership;
- EDB05 = 2 cards (01, 03), EDB06 = 9.

---

## 4. Gate

**PASS.** Planilha = staging = banco em 100% dos campos; lacunas preservadas como GI; nenhum valor inferido; P1–P4 não publicados.
