# AUDITORIA C09 — Fundação operacional (02/10/2026)

**Fase:** SAFRA-C09 · **Gate:** G5.5 · **Owner:** Kaue Pastrello  
**Decisões:** D-93 (meta de recuperação), D-94 (capacidade), D-95 (observabilidade mínima)  
**Migration:** `20261002120000_c09_ops_foundation.sql`, aplicada no PRIMARY em 02/10/2026 (**44 no PRIMARY = 44 no repositório**)  
**CI:** App Smoke Test #268 e Database Disposable Test #306 verdes no commit `5023e3f`

---

## 1. Resumo

| Passo | O que se pediu | Resultado |
|---|---|---|
| 1 | Estratégia de backup e meta RTO/RPO | **D-93:** perda máxima de até 24 h (RPO) e volta em até 4 h (RTO), com o backup diário do Lovable Cloud. GI-SAFRA-012 resolvida no PRIMARY. |
| 2 | Comprovar a restauração | Ensaio cronometrado no CI a cada mudança: **31 s** do backup à conferência, dados idênticos e Painel funcionando depois. |
| 3 | Pico de usuários e capacidade | **D-94:** 400 pessoas e 1.000 protocolos, mais um pico de 400 aberturas simultâneas: **0 erros**, 95% das respostas abaixo de **215 ms** no uso contínuo e de **738 ms** no pico. |
| 4 | Observabilidade mínima | **D-95:** registro técnico `public.ops_events` (90 dias, sem segredos) e tela Administração → Saúde do sistema. Teste em produção desfeito ao final: PASS. |
| 5 | Runbook de recuperação | `docs/RUNBOOK_RECUPERACAO.md` v1.0: primeiros 15 minutos, quadro de decisão, 6 procedimentos e modelo de registro do incidente. |

---

## 2. Backup e meta (passo 1)

- **Antes:** a D-23 pedia RPO 5 min / RTO 30 min, mas o Lovable Cloud faz só backup diário (sem PITR ativo). A meta era inalcançável (GI-SAFRA-012).
- **Decisão (opção B):** meta revista para **RPO ≤ 24 h e RTO ≤ 4 h** (D-93). A restauração ponto a ponto (PITR) fica como melhoria futura, com orçamento a pedir ao Lovable.
- **O que volta sozinho:** estrutura do banco e os 11 cards (todas as migrations do GitHub). **O que depende do backup:** protocolos, eventos, vínculos de login, auditoria e registro técnico.
- **PRIMARY:** GI-SAFRA-012 = `RESOLVED`, com o texto da D-93.

## 3. Ensaio de restauração (passo 2)

Script: `.github/scripts/test-safra-restore-drill.sh`, depois do teste de capacidade (o banco está cheio).

| Etapa | Tempo |
|---|---|
| Cópia lógica (`pg_dump` dos dados do Painel e dos logins, 2,2 MB) | 0 s |
| "Desastre": banco apagado e reconstruído só pelas migrations | 31 s |
| Restauração da cópia | 0 s |
| Conferência e abertura de protocolo | 0 s |
| **Total** | **31 s** |

- Antes = depois: 1.627 protocolos, 2.885 eventos, 186 encerrados, 50 cancelados, 430 logins, 4 vínculos, 9 papéis, 4 registros de auditoria, mesma assinatura (md5) da lista de protocolos.
- Depois da restauração, uma pessoa restaurada abriu o protocolo **06-0145**, continuando a numeração do card.

**Restauração real (resposta do Lovable, 02/10/2026):** feita por nós no painel (Cloud → Database → Backups), sem chamado; 5 a 15 min para o tamanho atual (~14 MB), com 3 a 10 min sem banco. Ela **substitui** o banco inteiro, por isso o runbook §4.5 manda exportar os dados antes. Backups diários guardados por cerca de 14 dias, com dados e logins. **RTO de 4 h comprovado com folga.** PITR só no plano Enterprise ou num projeto Supabase próprio (cerca de US$ 100/mês).

## 4. Capacidade (passo 3)

Script: `.github/scripts/test-safra-load.ts`, contra a API local do CI (mesma stack Supabase), com sessões Microsoft simuladas.

| Fase | O que simula | Chamadas | Erros técnicos | Recusas de regra | 95% abaixo de |
|---|---|---|---|---|---|
| A — uso contínuo (120 s) | 400 pessoas navegando com 5–10 s entre cliques; 1.000 protocolos abertos; metade conclui sua parte | 14.473 | 0 | 0 | **215 ms** |
| B — pico | as 400 pessoas abrem protocolo no mesmo instante | 400 | 0 | 0 | **738 ms** |
| C — donos | donos consultam e concluem 150 protocolos | 153 | 0 | 0 | 96 ms |

Por comando na fase A: catálogo 101 ms, "meus protocolos" 102 ms, abrir 412 ms, concluir 361 ms.

Conferências (todas PASS): 1.000 + 400 protocolos gravados, um por pessoa no pico, numeração sem repetição, "Encerrado" sempre com as duas partes.

Junto, o **stress** do C08.3 seguiu verde: 220 aberturas paralelas em 7 s, trava de um protocolo por pessoa e card, chave repetida, tempestade de concluir/cancelar.

**Ressalva sobre o portão local:** sem limite, o portão da API local (Kong, um só computador) derrubava conexões acima de ~100 pedidos simultâneos de uma mesma máquina (320 erros de rede/500 na primeira rodada, **0 erros de banco ou de regra**). O teste agora mantém no máximo 64 pedidos em andamento. Como 400 pessoas reais não abrem 400 conexões da mesma máquina, isso não representa o uso real, mas também **não prova a capacidade do plano do Lovable Cloud**.

**Resposta do Lovable (02/10/2026):** a instância atual é a menor (**Tiny**: ~1 GB de memória, 2 vCPUs compartilhadas, 60 conexões diretas, 200 no pool) e, segundo eles, **não aguenta** 400 aberturas no mesmo minuto; recomendam **Small ou Medium** antes de liberar o acesso, ajustável pelo painel em 2 a 5 min. Observação técnica: o app não abre uma conexão de banco por pessoa (a API usa um pool fixo e enfileira os pedidos), então o limite real é processador e memória, não o número de conexões. De qualquer forma, o computador do CI é mais forte que o Tiny, então a recomendação é prudente: **GI-SAFRA-013**. Outro risco apontado: o **login** tem limite de tentativas por IP, e a Editora sai para a internet por um IP só; quem já entrou continua logado, então o risco é só no primeiro acesso em massa (runbook §4.6).

## 5. Observabilidade mínima (passo 4)

| Peça | O que faz |
|---|---|
| `public.ops_events` | registro técnico: erros de tela, respostas lentas (≥ 2 s), logins recusados, falhas técnicas de ação. RLS ligada, 0 políticas, ninguém lê ou grava direto. |
| `safra_log_ops_event` | única porta de gravação; só sessão autenticada (anon não executa); máx. 30 eventos/min por pessoa; apaga o que tem mais de 90 dias; **troca por `{"redacted":true}` qualquer detalhe que pareça token, chave ou senha**; relógio do servidor. |
| `safra_admin_get_ops_summary` | só platform admin: eventos por tipo, lentidão, protocolos abertos/encerrados/cancelados/em andamento e os 100 últimos registros. |
| Tela | Administração → **Saúde do sistema (últimas 24 h)**. Mostra o código curto do usuário, nunca nome ou e-mail. |
| App | toda chamada ao banco passa por `measured()` (`src/lib/ops.ts`); erros de regra (`SAFRA_*`) não contam como falha técnica. |

Teste no PRIMARY (transação desfeita no fim, 0 registros gravados): sessão corporativa reconhecida; 2 eventos registrados; resumo com lentidão de 2.500 ms; detalhe com "Bearer" gravado como `{"redacted": true}`; anon recusado.

**Alertas:** dependem do chamado aberto no TI em 02/10/2026 (caixa `painel.safra@` + permissão de envio). Até lá, um admin confere a Saúde do sistema uma vez por dia na Safra (D-95).

## 6. Runbook (passo 5)

`docs/RUNBOOK_RECUPERACAO.md` v1.0: o que existe para recuperar, primeiros 15 minutos, quadro sintoma → ação, procedimentos 4.1 (login Microsoft) a 4.6 (lentidão), evidências do CI, contatos e modelo de registro do incidente.

---

## 7. Ajuste do Modo Camaleão (D-96)

A pedido do owner, o Modo Camaleão deixou de valer para todos os platform admins e ficou só para **Kaue e Vinicius** (migration `20261002140000_c09_chameleon_kaue_vinicius.sql`). O banco confere papel **e** e-mail; Amanda e João continuam admins, sem o "ver como". Teste: `c08_3_chameleon_preview.test.sql` (14 verificações, inclui Amanda recusada).

## 8. Gate G5.5

| Critério | Estado |
|---|---|
| Meta RTO/RPO compatível com a infraestrutura | OK (D-93) |
| Restauração comprovada e cronometrada | OK: CI 31 s; Lovable 5 a 15 min pelo painel |
| Capacidade no pior caso | OK no CI (0 erros); no PRIMARY depende do tamanho da instância (GI-SAFRA-013) |
| Observabilidade sem segredos | OK (PRIMARY) |
| Runbook | OK |
| Alertas | **pendente** (chamado do TI; o Lovable não avisa queda do projeto: assinar https://status.lovable.dev; **sem monitor externo de disponibilidade** pelo TI, D-97) |
| Instância, região dos dados, cabeçalhos | **a decidir**: GI-SAFRA-013, 014 e 015 (antes de liberar o acesso) |
| Smoke de login real | **pendente** (publicar e homologar, D-79) |

**Veredito:** **G5.5 APROVADO COM PENDÊNCIAS EXTERNAS.** O que dependia do código e do banco está feito e testado; ficam as decisões do owner (GI-SAFRA-013 a 015), o TI (alertas por e-mail, subdomínio) e a publicação com homologação.
