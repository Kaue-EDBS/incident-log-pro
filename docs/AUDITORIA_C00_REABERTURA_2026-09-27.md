# AUDITORIA C00 — REABERTURA CORRETIVA

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C00 — Baseline e contenção P0  
**Data de abertura:** 27/09/2026  
**Horário de abertura:** 11:26 BRT  
**Estado:** EM EXECUÇÃO  
**Natureza:** reauditoria técnica e rodada corretiva pós-fechamento

---

## 1. Motivo da reabertura

O SAFRA-C00 havia sido encerrado com evidências de contenção P0. Em 27/09/2026 foi iniciada uma nova auditoria sobre o estado atual do repositório para verificar se evoluções posteriores preservaram os controles originalmente aprovados e se havia resíduos técnicos, regressões ou dívida de engenharia em hooks, funções, migrations, CI e código legado.

A reabertura **não invalida o fechamento histórico do C00**. Ela registra uma nova rodada de garantia sobre o estado atual do sistema.

---

## 2. Resultado da reauditoria antes das correções

### C00 original

| Ação | Resultado da reauditoria |
|---|---|
| Preservar baseline e histórico Git | PASS |
| Remover `.env` do tracking e tratar exposição | PASS |
| Bloquear acesso `anon` | PASS |
| Habilitar RLS e remover policies abertas | PASS para contenção P0 |
| Testar acesso não autorizado | PASS histórico, com cobertura automatizada atual a reforçar |

### Evidências confirmadas

- baseline `8c38efe9a8ef73a9469083baf16fc33bc82b5b96` permanece ancestral de `main`;
- `main` está 439 commits à frente e 0 atrás da baseline auditada;
- `.env` permanece fora do tracking;
- `.gitignore` protege `.env` e `.env.*`;
- `.env.example` contém apenas placeholders;
- histórico do `.env` auditado não revelou `service_role`, `sb_secret_` ou JWT privilegiado;
- `anon` permanece sem grants nas estruturas protegidas auditadas;
- policies permissivas originais `USING (true)` foram removidas;
- `supabase/tests/database/c00_security_regression.test.sql` permanece verde no banco descartável;
- o Database Disposable Test atual reconstrói as migrations canônicas e mantém os testes de segurança verdes.

---

## 3. Pendências abertas nesta rodada

### C00-AUD-01 — Reforçar teste HTTP direto do legado

**Estado:** OPEN

O smoke HTTP atual testa as estruturas novas do schema v2 e RPCs governadas, mas não testa diretamente:

- `public.applications`;
- `public.incidents`.

**Ação aprovada para início:** adicionar essas duas estruturas ao teste direto de acesso público/anônimo e exigir resposta de negação `401/403`.

**Objetivo:** transformar a evidência histórica do C00 em regressão automática e repetível no pipeline atual.

---

### C00-AUD-02 — Restaurar menor privilégio no write-path legado

**Estado:** OPEN

O C00 restringiu operações de `authenticated` em `public.incidents` por coluna. O C04 posteriormente passou a conceder `SELECT, INSERT, UPDATE` na tabela inteira para usuários autenticados sujeitos à autorização corporativa.

Isso **não reabre o acesso anônimo P0**, mas reduz o princípio de menor privilégio originalmente estabelecido.

O legado continua funcionalmente referenciado pelas telas e hooks de:

- visão geral;
- histórico de incidentes;
- aplicações;
- indicadores;
- detalhe de incidente;
- `useApplications()`;
- `useIncidents()`;
- `useIncident()`;
- `useUpdateIncident()`.

**Direção da alteração:** manter o legado protegido enquanto ele existir, restaurando privilégios mínimos e restringindo o payload de atualização aceito pelo hook. A retirada definitiva do legado deve ocorrer posteriormente no redesenho funcional, sem remoção abrupta nesta rodada.

---

### C00-AUD-03 — Limpeza de lint e transformação do lint em gate real

**Estado:** OPEN

O pipeline atual executa:

`Lint legacy baseline`

com `continue-on-error: true`.

A execução auditada encontrou:

- **956 problemas**;
- **949 erros**;
- **7 warnings**;
- **948 erros potencialmente corrigíveis automaticamente**.

A maior parte corresponde a formatação/Prettier, não a falhas funcionais. Mesmo assim, o estado atual permite um pipeline verde com lint vermelho.

**Direção da alteração:**

1. executar limpeza mecânica/formatação sem mudança de regra de negócio;
2. revisar manualmente o pequeno conjunto residual;
3. confirmar typecheck, build e testes;
4. remover `continue-on-error`;
5. transformar lint em gate obrigatório.

---

### C00-AUD-04 — Remover ou justificar hook legado sem consumidor

**Estado:** OPEN

`useStartIncident()` permanece em `src/lib/queries.ts`, enquanto o fluxo atual de START usa:

- `useSafraStartCatalog()`;
- `useSafraStartTreatment()`;
- RPCs governadas do schema v2.

Na auditoria atual não foi identificado consumidor ativo de `useStartIncident()` nas rotas versionadas.

**Direção da alteração:** confirmar ausência de dependência e, se confirmada, remover o hook morto como parte da limpeza do legado.

---

## 4. Ordem de execução

A rodada corretiva será executada nesta sequência:

1. **C00-AUD-01** — reforçar regressão HTTP de `applications/incidents`;
2. **C00-AUD-02** — restaurar menor privilégio no legado e estreitar DTO/hook;
3. **C00-AUD-03** — limpar lint e torná-lo bloqueante;
4. **C00-AUD-04** — confirmar e remover código morto;
5. repetir testes de banco, Data API, RPC, typecheck, build e lint;
6. registrar evidências e fechar a reauditoria.

---

## 5. Gate de fechamento

Esta reauditoria só poderá ser marcada como concluída quando:

- os quatro itens C00-AUD estiverem fechados ou formalmente reclassificados;
- `anon` continuar negado;
- RLS continuar ativa;
- nenhum segredo privilegiado estiver versionado;
- baseline Git continuar preservada;
- banco descartável estiver verde;
- typecheck estiver verde;
- build estiver verde;
- lint estiver verde e bloqueante;
- documentação registrar data, hora, commits e evidências finais.

---

## 6. Decisão registrada

Em **27/09/2026 às 11:26 BRT**, foi autorizado **iniciar as alterações corretivas decorrentes da reauditoria do SAFRA-C00**.

Neste registro, as correções ainda **não são declaradas concluídas**. O estado oficial passa a ser:

> **C00 historicamente encerrado, reauditoria corretiva C00-AUD em execução.**

O SAFRA-C08 não deve apagar nem substituir esta trilha de auditoria; o fechamento desta rodada deve preservar toda a evidência histórica anterior.
