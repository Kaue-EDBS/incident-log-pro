# AUDITORIA C03 — REABERTURA CORRETIVA

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C03 — Glossário e modelo de domínio  
**Data de abertura:** 28/09/2026  
**Horário:** 06:13 BRT  
**Estado:** EM EXECUÇÃO  
**Natureza:** reauditoria de vocabulário, fronteiras de domínio, schema, hooks, rotas e interface contra o estado atual do Painel Safra

---

## 1. Objetivo

Revalidar o glossário e o modelo de domínio após a implementação de C05–C08, garantindo que documentação, banco, types, hooks, RPCs, rotas e interface usem os mesmos conceitos sem sinônimos concorrentes.

O fechamento histórico do C03 é preservado. Esta rodada registra uma nova fotografia do sistema já evoluído.

## 2. Escopo obrigatório

1. Definir formalmente o vocabulário canônico do domínio, incluindo cenário, versão, gatilho, detecção, START, protocolo, tratativa, owner, áreas, SLA, criticidade, END, CANCEL, escalonamento, pós-mortem, recorrência e proposta/publicação de cenário.
2. Formalizar `Geral` como visão agregada e nunca como área operacional.
3. Separar cenário, versão de cenário e tratativa em schema e interface.
4. Definir impacto qualitativo e caminho para impacto quantitativo, sem classificar os quatro cenários `CRITICAL` sem evidência.
5. Consolidar a autoridade funcional em `docs/GLOSSARIO_DOMINIO.md`, sem entidade C05 ambígua ou definição concorrente.

## 3. Evidências positivas da abertura

A reauditoria confirmou:

- `docs/GLOSSARIO_DOMINIO.md` já define formalmente o vocabulário central do Painel Safra;
- o PRIMARY possui as áreas operacionais `COMERCIAL`, `DAF`, `E_COMMERCE`, `LOGISTICA`, `PCP`, `POS_VENDAS` e `TI`;
- não existe área operacional `Geral`/`GERAL` no PRIMARY;
- o schema distingue corretamente `scenarios`, `scenario_versions` e `treatments`;
- não existe entidade concorrente `scenario_impacted_areas`; a relação potencial é `scenario_version_impacted_areas` e a ocorrência usa `treatment_impacted_areas`;
- impacto esperado usa `scenario_versions.expected_impact_summary`;
- impacto observado qualitativo usa `treatments.impact_summary`;
- impacto quantitativo possui estrutura própria em `treatment_impact_measurements`;
- as 11 versões atualmente PUBLISHED permanecem com `criticality = NULL`;
- `GI-SAFRA-001` continua OPEN e proíbe inferir os quatro cenários CRITICAL sem evidência;
- não foram encontrados `TODO`, `FIXME`, `HACK`, `@ts-ignore`, `as any` ou `as unknown as` nas rotas/hooks centrais auditados.

## 4. Pendências corretivas aprovadas

### C03-AUD-01 — rota Safra com nomenclatura de incidente

**Estado:** IMPLEMENTED / PENDING_CI em 28/09/2026 às 06:22 BRT  
**Severidade original:** MEDIUM / SEMÂNTICA

A rota canônica do START foi migrada para:

`/tratativas/nova`

Implementação:

- fluxo START movido para `src/routes/tratativas.nova.tsx`;
- `/novo-incidente` preservado somente como redirect de compatibilidade para `/tratativas/nova`;
- `AppLayout` aponta exclusivamente para a rota canônica nova;
- rótulo de UX `Abrir Protocolo` foi preservado;
- o domínio continua registrando START como criação de `treatment`, nunca como `incident`;
- `routeTree.gen.ts` foi reconciliado com a nova rota.

Foi criado o gate permanente:

`.github/scripts/check-c03-route-coherence.py`

O gate reprova se:

- a rota canônica deixar de existir;
- o redirect legado deixar de apontar para `/tratativas/nova`;
- a navegação voltar a apontar para `/novo-incidente`;
- houver referência funcional ao path legado fora do redirect/arquivo gerado;
- o route tree perder ou duplicar a rota canônica.

Validação estática da branch:

- rota canônica presente: PASS;
- redirect legado presente: PASS;
- referências de `AppLayout` à rota nova: 2;
- referências de `AppLayout` à rota antiga: 0;
- registros tipados de `/tratativas/nova` no route tree: 3 mapas + 1 FileRoutesByPath.

**Pendência restante deste item:** executar App Smoke/typecheck/build/lint quando a franquia do GitHub Actions voltar a estar disponível. Até lá, a correção está implementada, mas o fechamento formal permanece dependente do CI.

### C03-AUD-02 — fronteira visual Safra × Reliability Monitor legado

**Estado:** IMPLEMENTED / PENDING_CI em 28/09/2026 às 06:27 BRT  
**Severidade original:** MEDIUM-HIGH / UX E DOMÍNIO

A navegação foi separada visualmente em duas fronteiras explícitas, sem criar telas Safra inexistentes.

Estado atual:

```text
SAFRA
- Abrir Protocolo  -> /tratativas/nova

RELIABILITY / LEGADO TI
- Visão Geral TI   -> /
- Incidentes TI    -> /incidentes
- Aplicações TI    -> /aplicacoes
- Indicadores TI   -> /indicadores
```

Regras aplicadas:

- `Incidente TI` não é apresentado como sinônimo de `Tratativa Safra`;
- a raiz `/` permanece identificada como visão do Reliability/Legado TI enquanto não existir dashboard Safra próprio;
- nenhum link artificial de `Visão Safra` ou `Tratativas` foi criado antes de sua implementação funcional;
- desktop usa agrupamento visual com títulos de domínio;
- mobile mostra a fronteira ativa no cabeçalho e identifica cada item como `Safra` ou `TI`;
- o legado permanece acessível, porém explicitamente rotulado como legado técnico.

Foi criado o gate permanente:

`.github/scripts/check-c03-domain-boundary.py`

O gate reprova se:

- os grupos `SAFRA_NAV` e `LEGACY_TI_NAV` forem removidos;
- os rótulos TI voltarem a ficar ambíguos;
- o START deixar de apontar para `/tratativas/nova`;
- o mobile deixar de informar a fronteira Safra × TI.

**Pendência restante deste item:** App Smoke/typecheck/build/lint quando a franquia do GitHub Actions estiver novamente disponível. Até lá, a correção está implementada e protegida por gate estático versionado.

### C03-AUD-03 — hooks de dois domínios no mesmo módulo

**Estado:** OPEN / ALTERAÇÃO AUTORIZADA  
**Severidade:** LOW / HIGIENE TÉCNICA

`src/lib/queries.ts` mistura hoje queries do Reliability Monitor e do domínio Safra.

**Direção aprovada:**

Separar fronteiras de código, preferencialmente em:

- `src/lib/legacy-incident-queries.ts`;
- `src/lib/safra-queries.ts`;

ou estrutura equivalente que preserve a distinção explícita entre os dois domínios.

Não alterar comportamento funcional durante a separação.

### C03-AUD-04 — glossário canônico com metadados e linguagem pré-C05

**Estado:** OPEN / ALTERAÇÃO AUTORIZADA  
**Severidade:** LOW / DOCUMENTAÇÃO

O cabeçalho atual ainda registra:

- versão 1.1;
- data 25/09/2026;
- `READY_FOR_C05`.

Além disso, trechos de handoff ainda usam linguagem futura (`C05 deve criar`) para estruturas que já existem no PRIMARY.

**Direção aprovada:**

Atualizar `docs/GLOSSARIO_DOMINIO.md` sem alterar regras de negócio:

- registrar esta reauditoria;
- distinguir `CONTRATO DEFINIDO NO C03` de `IMPLEMENTADO EM C05+`;
- atualizar metadados;
- manter o glossário como autoridade única do vocabulário;
- eliminar formulações que possam sugerir que estruturas já existentes ainda são apenas propostas.

## 5. Regras que não serão alteradas nesta rodada

Continuam congeladas:

- `Geral` é visão agregada, nunca área operacional;
- cenário é identidade estável;
- versão é conteúdo versionado;
- tratativa é ocorrência real;
- START cria tratativa;
- END resolve tratativa;
- CANCEL cancela sem apagar histórico;
- proposta não é cenário publicado;
- impacto não é criticidade;
- criticidade desconhecida permanece `NULL`;
- os quatro `CRITICAL` só podem ser definidos com evidência suficiente e decisão formal;
- versão PUBLISHED não é reescrita in-place;
- incidente TI não é tratativa Safra.

## 6. Gate de fechamento

C03-AUD somente poderá ser encerrada quando:

- a rota canônica de START usar nomenclatura de tratativa;
- o redirect legado estiver explícito e testado;
- a navegação separar Safra e Reliability/Legado TI;
- hooks/queries estiverem separados por domínio;
- `docs/GLOSSARIO_DOMINIO.md` refletir o estado pós-C05–C08;
- não existir entidade ou campo C05 com definição concorrente;
- `Geral` continuar ausente de `operational_areas`;
- impacto e criticidade continuarem sem inferência indevida;
- App Smoke/typecheck/build/lint puderem ser reexecutados quando a cota do GitHub Actions estiver disponível.

> **C03 permanece historicamente fechado; C03-AUD está EM EXECUÇÃO e ainda não foi recertificado.**
