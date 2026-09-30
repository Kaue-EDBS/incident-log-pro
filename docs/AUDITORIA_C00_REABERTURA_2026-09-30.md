# AUDITORIA C00 — SEGUNDA REABERTURA (C00-AUD2)

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C00 — Baseline e contenção P0  
**Data de abertura:** 30/09/2026  
**Estado:** CONCLUÍDA — 30/09/2026  
**Base auditada:** `main` em `fe14bc3`  
**Decisões geradas:** D-50 e D-51 (`docs/DECISOES.md`)

---

## 1. Motivo da reabertura

A primeira reauditoria (C00-AUD, 27/09/2026) conferiu os controles de segurança do C00 e passou. Esta rodada revisa o C00 por outro ângulo: se a baseline e a contenção protegeram o **produto** que existia, o Reliability Monitor/MTTR, ou se o Painel Safra o absorveu sem decisão.

A reabertura não invalida o fechamento histórico do C00 nem o da C00-AUD.

---

## 2. Os cinco passos do C00

| # | Passo | Resultado | Observação |
|---|---|---|---|
| 1 | Registrar e preservar a baseline, com histórico Git intacto | **PARCIAL** | Histórico preservado. A baseline `8c38efe` já era um commit do roadmap Safra e registrou schema e rotas, mas não o comportamento funcional do MTTR. Sem esse registro, o fluxo pôde sumir sem que nenhum gate percebesse. |
| 2 | Remover o `.env` do tracking e tratar a exposição | **PASS** | Só havia URL, project ref e chave publishable. |
| 3 | Bloquear o acesso `anon` às estruturas internas | **PASS** | Coberto por pgTAP e smoke HTTP. |
| 4 | Habilitar RLS e remover policies abertas | **PASS, com acoplamento** | A contenção das tabelas do MTTR foi feita com nome e regra Safra (`safra_c00_*`, `app_metadata.safra_access`, depois `safra_is_corporate_user()`). |
| 5 | Testar diretamente o acesso não autorizado | **PASS para segurança** | Provava a negação indevida, mas nenhum teste provava que o uso legítimo do MTTR continuava funcionando. |

---

## 3. Achados

### C00-AUD2-01 — "Novo Incidente" substituído sem decisão

`/novo-incidente` passou a ser "Abrir Protocolo | Painel Safra" no C08.1 e cria uma tratativa Safra. Não restou nenhum caminho de interface para registrar um incidente de TI.

A troca contrariava D-02, `ARQUITETURA.md` §9 ("não são substitutos de `scenarios`/`treatments`") e o SAFRA-M07 ("incidente TI pode existir sem protocolo").

**Tratamento:** D-50 descontinua o Reliability Monitor/MTTR e torna "Abrir Protocolo" o único START. D-02 passa a SUPERSEDED e o M07 é cancelado.

### C00-AUD2-02 — Remoção justificada por raciocínio circular

A C00-AUD-04 removeu `useStartIncident()` por "não ter consumidor". Ele só estava sem consumidor porque o C08.1 tinha acabado de trocar a rota. O critério da `MATRIZ_PARIDADE.md` §4 (confirmar equivalência, migrar, testar e só então desativar) não foi aplicado.

**Tratamento:** a D-50 registra a decisão que faltava. A matriz ganhou a seção 5.1: remover ou substituir um fluxo exige decisão antes do código.

### C00-AUD2-03 — Matriz de paridade contraditória

`incidents` estava como **KEEP**, e "abertura de incidente" estava como **REDESIGN → START de treatment**.

**Tratamento:** a matriz foi reconciliada com a D-50; as capacidades do MTTR estão como **REMOVE**.

### C00-AUD2-04 — Privilégio sem consumidor

O banco ainda concedia INSERT e UPDATE em `public.incidents` para `authenticated`, mas nenhuma tela ativa usava o INSERT.

**Tratamento:** as tabelas são removidas (item 4).

### C00-AUD2-05 — Duas identidades de produto na interface

O menu dizia "Painel Safra"; Visão Geral, Incidentes, Aplicações e Indicadores diziam "Reliability Monitor".

**Tratamento:** as telas do MTTR foram removidas. A Visão Geral virou "Em obras", e o menu tem só Visão Geral e Abrir Protocolo.

### C00-AUD2-06 — Dados fictícios exibidos como operação real

As 3 aplicações demo (XPTO, ABC e SEP) e 15 incidentes apareciam no app publicado, embora a matriz os classificasse como PARK. Conferência no PRIMARY em 30/09/2026: 12 eram o seed fictício de 14/08 e 3 eram cliques de teste na interface antiga (14/08, 20/08 e 25/09; recuperação 30 s a 1 min depois, sem causa, responsável ou notas). Nenhum era incidente real. A documentação anterior falava em 14.

**Tratamento:** apagados junto com as tabelas.

---

## 4. Alterações desta rodada

### Banco

- migration `supabase/migrations/20260930120000_c00_aud2_retire_reliability_monitor.sql`:
  - remove triggers, `public.incidents`, `public.applications`, `public.validate_incident_timestamps()` e `public.set_updated_at()`;
  - não usa `CASCADE`: uma dependência desconhecida aborta a migration inteira;
  - confere no fim que os quatro objetos não existem mais;
- `c00_security_regression.test.sql` reescrito (8 asserções):
  - as tabelas e os helpers do MTTR não existem;
  - a contenção do C00 vale para **todo** o schema `public`: RLS em todas as tabelas, zero grants para `anon`, nenhuma policy para `anon`, nenhuma policy `USING/WITH CHECK (true)`, policies abertas da baseline ausentes;
- `c02_threat_model_authz.test.sql`: as 4 asserções sobre os helpers do MTTR viram 2 asserções de remoção (plano 26 → 24);
- `.github/scripts/test-safra-direct-api.sh`: `applications` e `incidents` saem da lista de tabelas testadas.

### Interface

- removidas as rotas `/incidentes`, `/incidentes/$id`, `/aplicacoes` e `/indicadores`;
- removidos `Filters`, `MetricCard`, `StatusBadge`, `src/lib/types.ts` e os hooks `useApplications`, `useIncidents`, `useIncident` e `useUpdateIncident`;
- `src/lib/metrics.ts` perde as funções de MTTD/MTTR/MTBF/downtime/disponibilidade e mantém só a regra de fuso horário do C07 (Regra 2) e a formatação de tempo usada pelo `LiveTimer`;
- `/` passa a mostrar "Em obras" com atalho para Abrir Protocolo;
- `src/integrations/supabase/types.ts`: removidos os tipos das duas tabelas. O Lovable deve regenerar esse arquivo depois da migration.

### Documentação

- `DECISOES.md`: D-50, D-51, D-02 SUPERSEDED, GI-SAFRA-010 e métricas do protocolo como DEFERRED_TO_F04_M05;
- `MATRIZ_PARIDADE.md`, `ARQUITETURA.md` §9, `ROADMAP.md` (D-02, tabela de cenários, M05, M07, métricas), `REGRAS_NEGOCIO.md` §3, `GLOSSARIO_DOMINIO.md` e `README.md`.

---

## 5. Evidências locais

| Verificação | Resultado |
|---|---|
| typecheck (`tsc --noEmit`) | PASS |
| build | PASS |
| lint zero-warning | PASS (com `endOfLine: auto`, porque o clone Windows usa CRLF; o repositório está em LF) |
| contrato de fuso horário C07, host UTC | PASS |
| contrato de fuso horário C07, host Asia/Tokyo | PASS |
| testes de banco (pgTAP), smoke Data API/RPC, rollback | não executado localmente (sem Supabase CLI/Docker); **PASS no CI** — ver seção 7 |

---

## 6. Aplicação no PRIMARY — 30/09/2026

Sequência:
1. merge por fast-forward de `c00-aud2-retire-reliability-monitor` na `main` (`dc23457`), **sem CI**, por decisão do owner (minutos do GitHub esgotados);
2. Lovable sincronizou `dc23457`; o owner publicou o app;
3. verificação prévia de dependências no PRIMARY: nenhuma policy, view, função ou trigger externo às próprias tabelas;
4. migration aplicada pelo conector do Lovable Cloud numa transação única, com registro da versão em `supabase_migrations.schema_migrations`.

Conferência pós-aplicação:

| Verificação | Esperado | Resultado |
|---|---|---|
| `public.applications` | ausente | ausente |
| `public.incidents` | ausente | ausente |
| `validate_incident_timestamps()` | ausente | ausente |
| `set_updated_at()` | ausente | ausente |
| versão `20260930120000` registrada | 1 | 1 |
| grants de `anon` em `public` | 0 | 0 |
| tabelas `public` sem RLS | 0 | 0 |
| policies para `anon` | 0 | 0 |
| policies `USING/WITH CHECK (true)` | 0 | 0 |
| cenários | 11 | 11 |
| treatments | 0 | 0 |

### C00-AUD2-07 — Drift: migrations no PRIMARY ausentes do repositório

Encontradas no `schema_migrations` do PRIMARY, sem arquivo em `supabase/migrations/` e sem SQL guardado no histórico (`statements` nulo):

| Versão | Nome |
|---|---|
| `20260928075934` | `c04_reaudit_legacy_surface_hardening` |
| `20260928090910` | `c05_notification_delivery_state_machine` |
| `20260928095246` | `c05_fk_indexes_and_clock_ownership` |

Isso contraria a autoridade única de migrations do C05 (ADR-035): o banco real tem objetos que o repositório não reconstrói. **Não bloqueia a C00-AUD2**; encaminhado para a reauditoria do C05.

## 7. Gate de fechamento

A C00-AUD2 só fecha quando:

- [x] o Database Disposable Test e o App Smoke Test passarem no GitHub — ambos SUCCESS em `e9c4031` (Database Disposable run `36745901521`), com o repositório temporariamente público para usar runners gratuitos;
- [x] a migration estiver aplicada no Lovable Cloud PRIMARY e registrada em `supabase_migrations.schema_migrations`;
- [x] a consulta de verificação no PRIMARY confirmar a ausência dos quatro objetos e a contenção de `anon`;
- [x] o app publicado mostrar "Em obras" na Visão Geral e o Abrir Protocolo funcionando — conferido pelo owner com sessão Microsoft em 30/09/2026.

> **C00-AUD2 concluída em 30/09/2026.** Achado C00-AUD2-07 (drift de 3 migrations) segue para a reauditoria do C05.
