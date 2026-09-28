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

### C03-AUD-02 — identidade única do Painel Safra durante a migração do Reliability

**Estado:** IMPLEMENTED / PENDING_CI — refinado em 28/09/2026 às 06:34 BRT  
**Severidade original:** MEDIUM-HIGH / UX E DOMÍNIO

A decisão de domínio foi refinada: **Reliability Monitor não é um segundo produto nem uma área funcional paralela**. Ele é somente a base técnica anterior que está sendo transformada, passo a passo, no Painel Safra e nunca teve adoção operacional real.

Portanto, a UX não deve ensinar ao usuário uma separação "Safra × Reliability".

Estado atual:

```text
PRODUTO VISÍVEL
Painel Safra
└── Operação Safra
    └── Abrir Protocolo -> /tratativas/nova

BASE TÉCNICA TRANSITÓRIA — NÃO EXPOSTA NA NAVEGAÇÃO
- /incidentes
- /aplicacoes
- /indicadores
- código/queries/metrics do antigo Reliability Monitor
```

Regras aplicadas:

- `Painel Safra` é a única identidade de produto apresentada ao usuário;
- referências visuais a `Reliability`, `Legado TI`, `Incidentes TI`, `Aplicações TI` e `Indicadores TI` foram removidas do `AppLayout`;
- a raiz `/` agora redireciona para `/tratativas/nova`;
- após autenticação corporativa, o usuário também aterrissa diretamente em `/tratativas/nova`;
- links de recuperação/home do shell apontam para o fluxo Safra;
- as rotas antigas continuam preservadas no código por enquanto, mas não fazem parte da navegação funcional;
- a retirada definitiva do código antigo será feita por etapa própria, sem misturar com esta correção de domínio.

O gate permanente `.github/scripts/check-c03-domain-boundary.py` foi ajustado para reprovar se:

- a identidade `Painel Safra` desaparecer;
- Reliability/Legado TI voltar a aparecer na navegação;
- rotas antigas voltarem a ser expostas pelo `AppLayout`;
- `/` ou o pós-login deixarem de levar ao fluxo Safra;
- o código transitório antigo for removido antes da migração controlada correspondente.

**Pendência restante deste item:** App Smoke/typecheck/build/lint quando a franquia do GitHub Actions estiver novamente disponível. Até lá, a correção está implementada e o entendimento de produto ficou alinhado ao processo real de migração.

### C03-AUD-03 — remoção do legado Reliability da camada de aplicação

**Estado:** IMPLEMENTED / PENDING_CI em 28/09/2026  
**Severidade original:** LOW / HIGIENE TÉCNICA

A decisão foi refinada após confirmar que o Reliability Monitor nunca teve adoção operacional real. Em vez de separar hooks legacy × Safra e perpetuar dois domínios na aplicação, o legado foi removido da camada de frontend/runtime.

#### Removido

Rotas:

- `src/routes/incidentes.index.tsx`;
- `src/routes/incidentes.$id.tsx`;
- `src/routes/aplicacoes.tsx`;
- `src/routes/indicadores.tsx`.

Hooks/queries e tipos legados:

- `src/lib/queries.ts`;
- `src/lib/types.ts`;
- `src/lib/metrics.ts`.

Componentes exclusivos do Reliability:

- `src/components/Filters.tsx`;
- `src/components/MetricCard.tsx`;
- `src/components/StatusBadge.tsx`.

Estilo morto:

- `pulse-incident` e respectivo `@keyframes pulse-ring`.

#### Preservado e reorganizado

- hooks Safra movidos para `src/lib/safra-queries.ts`;
- utilitários neutros de timezone/timer preservados em `src/lib/analytics-time.ts`;
- `LiveTimer` foi desacoplado de `metrics.ts`;
- teste C07 de timezone foi redirecionado para `analytics-time.ts`;
- `routeTree.gen.ts` não registra mais `/incidentes`, `/aplicacoes` ou `/indicadores`.

#### Fora do escopo desta remoção

As tabelas `public.applications` e `public.incidents`, migrations históricas, tipos gerados do Supabase e testes de segurança dessas tabelas **não foram apagados**. A remoção física de persistência exige etapa própria e migration explícita.

Também permanece no manifesto a dependência `recharts`, agora sem import ativo. Ela será removida em manutenção de dependências com lockfile/CI disponível; não bloqueia esta limpeza funcional.

#### Gate de regressão

`.github/scripts/check-c03-domain-boundary.py` agora reprova se:

- qualquer rota/componente/módulo frontend Reliability removido reaparecer;
- o `routeTree` voltar a expor rotas antigas;
- START voltar a depender de `queries.ts`;
- `LiveTimer` ou o teste C07 voltarem a depender de `metrics.ts`.

**Pendência restante deste item:** executar App Smoke/typecheck/build/lint quando a franquia do GitHub Actions voltar a estar disponível.

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
- a navegação expor somente o Painel Safra, mantendo o Reliability apenas como base técnica transitória não navegável;
- o frontend/runtime não contiver mais hooks, rotas ou componentes Reliability sem uso;
- `docs/GLOSSARIO_DOMINIO.md` refletir o estado pós-C05–C08;
- não existir entidade ou campo C05 com definição concorrente;
- `Geral` continuar ausente de `operational_areas`;
- impacto e criticidade continuarem sem inferência indevida;
- App Smoke/typecheck/build/lint puderem ser reexecutados quando a cota do GitHub Actions estiver disponível.

> **C03 permanece historicamente fechado; C03-AUD está EM EXECUÇÃO e ainda não foi recertificado.**
