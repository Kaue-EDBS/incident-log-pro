# AUDITORIA C08 — REABERTURA (C08.1 + C08.2)

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C08 — UX do COMEÇO (com F01/F02 antecipadas, D-87)  
**Data:** 01–02/10/2026  
**Estado:** CONCLUÍDA no banco e no código; **falta o owner publicar no Lovable e homologar com login real**  
**Migration:** `20261002000000_c08_1_protocol_lifecycle.sql` (CI verde: App Smoke #258, Database Disposable #296; aplicada no PRIMARY em 5 transações, 42 = 42)  
**Decisões:** D-81 a D-90

---

## 1. Os 6 passos do C08, adaptados às decisões

| # | Passo | Resultado |
|---|---|---|
| 1 | Visão Geral e catálogo só com cards publicados e disponíveis | **FEITO** — Início com "Seus protocolos em andamento" e o catálogo; cards bloqueados (D-78) não aparecem; busca por palavra |
| 2 | Detalhe do cenário antes do START | **FEITO no próprio card (D-81)** — dono, área, quando usar, os passos do protocolo; criticidade e versão escondidas (D-85) |
| 3 | Abrir protocolo com contexto e áreas | **FEITO** — "O que está acontecendo?" obrigatório (D-83), "Quando o problema começou?" (D-89), outras áreas opcionais |
| 4 | START seguro | **FEITO** — validação no banco, número `NN-SSSS` (D-82), versão congelada, `TREATMENT_OPENED`. "Início dos SLAs" **não se aplica** (D-62/D-75); a escada de avisos é da M05 |
| 5 | 12º card | **ADIADO pela D-88** — vem depois das visões por audiência |
| 6 | Guardrails e acessibilidade | **FEITO no código** — ver seção 3; falta a verificação com usuário real |

**Antecipado da F01/F02 (D-87):** Concluído em duas partes (solicitante e dono), Cancelar com motivo, "Meus protocolos" e "Protocolos dos meus cards".

---

## 2. Banco (C08.1)

- `treatments`: `protocol_seq`/`protocol_number` (únicos), `problem_started_at`, `requester_closed_at`, `owner_closed_at`/`owner_closed_by`.
- Invariantes: RESOLVED **se e somente se** as duas partes estão fechadas; partes depois da abertura; início do problema antes da abertura; horários das partes sempre do servidor e nunca reescritos; número, início e resumo imutáveis.
- Trava D-57 revista (D-66): vale enquanto a parte do solicitante estiver aberta.
- Comandos: `safra_start_treatment` (5 parâmetros; o antigo de 4 foi removido), `safra_close_my_part`, `safra_cancel_treatment` — todos SECURITY DEFINER, fechados para `anon`, com trava da linha (concorrência).
- Leituras: `safra_get_my_treatments`, `safra_get_owner_treatments`; o catálogo traz `my_open_treatment`.
- Eventos novos: `REQUESTER_PART_CLOSED`, `OWNER_PART_CLOSED`.

### Testes

| Onde | Cobertura |
|---|---|
| `c08_1_protocol_lifecycle.test.sql` (35) | resumo obrigatório e curto; início no futuro; número por card (09-0001, 09-0002, 03-0001); repetição idempotente; trava; catálogo; listas sem vazar dados de outros; terceiro não conclui nem cancela; solicitante fecha primeiro → Aguardando dono → trava liberada; dono fecha → Encerrado com histórico completo; dono fecha primeiro → Aguardando quem abriu, solicitante continua travado; cancelar exige motivo; dono e solicitante cancelam; encerrado não cancela; banco recusa RESOLVED sem as duas partes; início e resumo imutáveis; relógio do servidor; navegador sem escrita direta; `anon` sem acesso |
| `test-safra-close-cancel-rpc-concurrency.sh` | corrida real: o dono encerra e o solicitante cancela ao mesmo tempo → só um vence, o outro recebe "não está ativo", histórico coerente |
| Testes antigos | passaram a mandar resumo; c02/c04 agora exigem que encerrar/cancelar existam **e** sejam protegidos |
| **Smoke no PRIMARY** (transação desfeita) | outra empresa barrada; 11 cards; resumo curto recusado; 09-0001; trava; Aguardando dono; trava liberada → 09-0002; 03-0001; "meus" = 3; terceiro barrado em concluir e cancelar; dono vê 2 do card dele e só o SAFRA-09 como seu; dono encerra → Encerrado; motivo curto recusado; dono cancela; encerrado não cancela; histórico de 4 eventos. **Nada ficou gravado** (0 protocolos, 0 usuários de teste) |

---

## 3. Telas (C08.2)

| Tela | O que tem |
|---|---|
| **Início** (`/`) | "Seus protocolos em andamento"; "Qual é o problema?" com busca; cards com área, dono e a situação do seu protocolo; card do próprio dono marcado |
| **Card aberto** | os outros somem (D-81); X ou Esc fecham e o foco volta ao card; dono, área, quando usar, passos do protocolo; formulário (resumo, início, áreas) → confirmação → número do protocolo; se já houver protocolo seu: situação + **Concluído** + **Cancelar protocolo** |
| **Meus protocolos** | situação com ícone e texto, resumo, início do problema, abertura, contador desde a abertura (D-86) a partir da hora do servidor, ações |
| **Protocolos dos meus cards** | só no menu de quem é dono; mostra quem abriu; ações do dono |
| `/abrir-protocolo` | redireciona para o Início (links antigos continuam funcionando) |

**Acessibilidade aplicada:** confirmação explícita em abrir, concluir e cancelar; situação nunca só por cor; alvos de toque ≥ 44 px; tudo pelo teclado (Esc só fora de campos de texto, para não apagar o que a pessoa digitou); foco gerenciado ao abrir/fechar o card; "Pular para o conteúdo"; `aria-current` no menu; rótulos em todos os campos; mensagens de erro do banco em português simples; botão escondido nunca é controle de segurança (todas as regras estão no banco).

---

## 4. Auditoria própria

| ID | Nível | Achado | Tratamento |
|---|---|---|---|
| C08-01 | ALTA | Sem aviso ao dono (M05), um protocolo aberto só é visto se o dono entrar no Painel | Mantida a condição da D-79: M05 antes de liberar o acesso |
| C08-02 | MÉDIA | A versão publicada no Lovable é de antes do C07 e não carrega o catálogo | O owner publica antes de liberar (D-79) |
| C08-03 | MÉDIA | Não houve teste com sessão Microsoft real (o CI usa usuários sintéticos) | Homologação após a publicação: Daniel e uma pessoa da operação abrem, concluem e cancelam um protocolo de teste |
| C08-04 | BAIXA | O motivo do cancelamento usa o mesmo mínimo de 10 caracteres da D-83 | Registrado na D-83 |
| C08-05 | BAIXA | Verificação automática de acessibilidade (axe) não está no CI | Proposta para o C09/F08 |
| C08-06 | BAIXA | Protocolos de teste da homologação vão consumir números (ex.: 09-0001) | Avisar antes; ou cancelá-los com motivo "teste de homologação" |

## 5. Gate

**PASS no banco e no código.** Falta para fechar de vez: publicação pelo owner e homologação com login real (C08-02/C08-03).
