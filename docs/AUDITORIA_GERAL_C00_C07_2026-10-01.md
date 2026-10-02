# AUDITORIA GERAL C00–C07 — 01/10/2026

**Pedido do owner:** auditoria robusta, detalhista e exigente de tudo o que foi feito até o C07: funções, edge functions, hooks, infraestrutura, lógica de programação e regras de negócio.  
**Estado:** ACHADOS REGISTRADOS — aguardando decisões do owner (nenhuma correção aplicada nesta etapa)  
**D-52:** PRIMARY 39 = repositório 39

## 1. Escopo verificado

| Frente | O que foi lido/testado |
|---|---|
| Banco PRIMARY | 39 funções (`public`/`private`): SECURITY DEFINER, `search_path`, permissões de `anon`/`authenticated`/`PUBLIC`, volatilidade, gatilhos; RLS, policies, grants, privilégios de schema, Realtime, Storage, extensões, schemas extras, configuração dos papéis, vínculo login ↔ cadastro, papéis vigentes |
| Edge functions | nenhuma no repositório nem no PRIMARY (sem `supabase/functions`, sem hooks de função) |
| Front | cliente Supabase, AuthProvider, middlewares, rotas (`/`, `/auth`, `/abrir-protocolo`), hooks de consulta, schemas Zod, LiveTimer |
| Infraestrutura | workflows do CI, scripts, `vite.config.ts`, `.env` no histórico do Git, dependências, Lovable |
| Regras de negócio | D-01 a D-77 contra o código e o banco |

## 2. Confirmado correto

- RLS ligado nas 15 tabelas, 0 policies, 0 grants diretos para `anon`/`authenticated`; acesso só por RPC.
- Todas as funções com `search_path = ''`; só 6 RPCs abertas a `authenticated` e nenhuma a `anon`.
- START: idempotência (trava por chave + chave única), D-57 (trava da linha do cenário + índice único), D-65, áreas validadas contra a versão, snapshot congelado, horário do servidor.
- Estados terminais imutáveis; CANCEL exige motivo; histórico de dono e de áreas protegido; eventos só de acréscimo.
- Sessão revogada e token vencido recusados (`safra_session_is_live`, `exp`).
- Nenhuma chave secreta no histórico do Git (só chaves públicas `sb_publishable_`); o navegador recusa chave secreta.
- Sem Realtime, Storage, edge functions ou extensões de rede.

## 3. Falhas encontradas

| ID | Sev. | Área | Falha | Impacto | Correção proposta | Precisa de decisão? |
|---|---|---|---|---|---|---|
| A-01 | ALTA | Identidade | O predicado corporativo e o gatilho que liga login a cadastro confiam só no **domínio do e-mail**; não conferem o **tenant Microsoft** da Editora (`tid` 45ba725f…). 7 dos 9 cadastros ainda não têm login (3 platform admins, Bruno, Daniel, Jiane, Renato) | Se o login Microsoft do Lovable aceitar contas de outras empresas e o e-mail vier sem verificação, alguém de fora poderia entrar com um e-mail `@editoradobrasil.com.br` falso e herdar o papel de um cadastro ainda sem login | Exigir o `tid` da Editora, lido de `auth.identities` (que o usuário não consegue editar), no predicado e no gatilho; teste no CI | Não (fato técnico) |
| A-02 | ALTA | Negócio | O START está publicado sem END/CANCEL (F01/F02) e sem aviso ao dono (M05) | Quem abrir um protocolo hoje fica **travado naquele card sem saída** (D-57), e o dono não é avisado | (a) desligar o START em produção até F01/M05, com uma chave no banco; ou (b) manter e orientar a não usar | **Sim** |
| A-03 | ALTA | Privacidade | O repositório público expõe 19 e-mails corporativos, nomes, quem é admin, o threat model e os riscos residuais | Facilita phishing direcionado aos administradores; dados pessoais na internet | Voltar a privado; CI com minutos pagos, runner próprio ou na renovação | **Sim** |
| A-04 | MÉDIA | Negócio/dados | Dono desativado ou com papel revogado não é tratado. Desativar o Daniel derruba 6 cards em silêncio ("cenário não disponível"); revogar o papel deixa um dono sem papel, porque a proteção só roda quando muda o dono | Cards somem do START sem aviso; dono inválido continua respondendo | Nova GI com a regra de substituição + bloqueio de revogar/desativar dono vigente sem troca | **Sim** (regra) |
| A-05 | MÉDIA | Auditoria | Mudanças em `safra_principals` (vínculo de login, desativação, e-mail) não entram na trilha de auditoria; só mudanças de papel entram | Não dá para provar quem ligou ou desativou um cadastro | Gatilho de auditoria em `safra_principals` | Não |
| A-06 | MÉDIA | Decisões | O índice do DECISOES mostra como APPROVED decisões já superadas: D-09, D-11, D-22, D-31, D-44, D-51 | Leitor (ou assistente do Lovable) pode aplicar regra antiga | Marcar SUPERSEDED com a decisão que substituiu | Não |
| A-07 | MÉDIA | Produto | O solicitante não tem onde ver o protocolo que abriu; ao tentar abrir de novo recebe "já tem um protocolo", sem link | Pessoa travada sem enxergar o motivo | Tela "meus protocolos" (M02/F01) | Não (registrar) |
| A-08 | MÉDIA | Produto | O catálogo mostra ao dono os próprios cards como abríveis; a regra D-65 só aparece depois de confirmar | Tentativa frustrada | Indicar "você é o dono" e desabilitar o card (C08) | Não |
| A-09 | BAIXA | Identidade | "Disable sign-up" desligado: qualquer conta Microsoft que tentar entrar vira registro em `auth.users`, mesmo barrada depois | Dados de pessoas de fora acumulam | Com A-01, rever a limpeza | Não |
| A-10 | BAIXA | Banco | Schema `drizzle` com `__drizzle_migrations` no PRIMARY, criado fora de `supabase/migrations` | Objeto fora da regra D-52 | Registrar como exceção da plataforma ou remover se vazio | Não |
| A-11 | BAIXA | Banco | `public.safra_log_access_denied` não pode ser chamada por ninguém e não tem uso | Acesso negado nunca é registrado; código morto | Remover ou passar a usar | Não |
| A-12 | BAIXA | Banco | Índice redundante `treatments_scenario_version_idx` (coberto por `idx_treatments_version_scenario`) | Escrita mais lenta, sem ganho | Remover | Não |
| A-13 | BAIXA | Front | Restos do MTTR: `/auth` diz "painel de confiabilidade das aplicações"; comentário do LiveTimer cita `detected_at` | Texto errado | Corrigir | Não |
| A-14 | BAIXA | Front | Falha de rede na checagem de acesso mostra "só contas corporativas" | Mensagem enganosa | Mensagem própria para erro técnico | Não |
| A-15 | BAIXA | Front | 404, erro e `lang="en"` em inglês; jargão na tela (Owner, Treatment ID, backend, PUBLISHED, correlation ID) | Tela pouco clara | C08 | Não |
| A-16 | BAIXA | Front | O contador "tempo em andamento" usa o relógio do computador | Relógio errado mostra tempo errado (só exibição) | Calcular a diferença com a hora do servidor (C08) | Não |
| A-17 | BAIXA | Infra | 42 de 46 componentes de UI e cerca de 12 dependências sem uso (recharts, drizzle-orm, postgres…) | Superfície de ataque e ruído no `audit` | Remover o que não é usado | Não |
| A-18 | BAIXA | CI | Workflows sem `permissions:` mínimas; actions fixadas por tag, não por hash | Risco de cadeia de suprimentos | `permissions: contents: read` e fixar por hash | Não |
| A-19 | BAIXA | CI | O banco do CI não tem o login do Kaue, então as 5 GIs resolvidas ficam OPEN nele; os testes aceitam os dois estados | O estado real do PRIMARY só é testado por usuário sintético | Aceitar (documentado) | Não |

**Totais:** 0 crítica, 3 altas, 5 médias, 11 baixas.
