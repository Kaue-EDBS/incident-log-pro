# AUDITORIA — E-mails (M05, D-131 a D-133) e M10 depois das mudanças de 02/10/2026

**Pedido do owner:** auditoria completa do código, das funções, do disparo de e-mail, do smoke e dos ganchos, sem os temas futuros do roadmap (M11, aplicativo do TI, Teams).
**Como:** quatro revisões independentes (banco, envio, tela, testes/CI/docs), cada achado conferido de novo no código, e conferência ao vivo no PRIMARY.
**Correções:** D-134, migration `20261002330000_m05_m10_audit_fixes.sql`.

## 1. Conferência ao vivo no PRIMARY (02/10/2026, 18:00)

| Item | Resultado |
|---|---|
| Migrations PRIMARY × repositório | 61 = 61, mesmas versões (antes desta correção) |
| Funções SECURITY DEFINER sem `search_path` | nenhuma |
| Funções do Painel executáveis por `anon` | nenhuma |
| Tabelas de `public` sem RLS / com acesso direto do navegador | nenhuma / nenhuma |
| Envio agendado (6 h) | 46 rodadas, 0 falhas, todas HTTP 200 |
| Cancelamento automático 72 h (6 h) | 36 rodadas, 0 falhas |
| Fila | 13 e-mails, 13 enviados, 0 com falha |
| Envio pelo navegador | falhando sempre ("reading 'rest'") no site publicado: versão publicada anterior à correção `c982f19` |

## 2. Achados e tratamento

| # | Gravidade | Achado | Tratamento |
|---|---|---|---|
| A1 | alta | Aviso pego 5 vezes sem resultado (rodada interrompida) fazia o próximo claim passar de 5 tentativas, quebrar a regra do banco e **parar a fila inteira por até 24 h** | corrigido: vira FAILED `SEND_FAILED: NO_REPORT`; só pega avisos com menos de 5 tentativas; teste |
| A4 | alta | Proposta com textos longos (até 3.000 + 3.000) gerava aviso acima de 6.000 caracteres: **a proposta não era salva** e a recusa podia falhar | corrigido: trechos de até 1.500 cada no e-mail (o texto inteiro fica no Painel); teste |
| A7 | alta | O banco descartável do CI e o local chamavam a **função de produção** a cada 2 minutos | corrigido: o agendamento só é criado onde o login do owner existe (PRIMARY); teste |
| F1 | alta | Voltar para a aba ou renovar o login **desmontava o Painel** (texto digitado sumia, contagem de telas inflada) | corrigido: a conferência de acesso só refaz quando muda a pessoa |
| A3 | média | Pelo navegador, qualquer pessoa podia marcar como enviado um aviso da própria ação sem enviar; cada aba de cada pessoa chamava o servidor a cada 2 minutos | corrigido (D-134): só gestão/admins pelo navegador ("Forçar envio agora"); o servidor envia o resto |
| A2 | média | Resultado atrasado de uma rodada vencida valia sobre outra rodada; o claim do servidor não limpava `claimed_by` | corrigido: resultado só vale com a trava da rodada; claim do servidor limpa `claimed_by`; validade não mexe em aviso sendo enviado |
| E2 | média | Se o registro do resultado falhasse depois de a Microsoft aceitar, o e-mail voltava como falha e saía de novo | corrigido: aceito nunca volta como falha; tenta registrar 2 vezes; teste |
| E3 | média | Nenhuma chamada tinha tempo máximo; uma lenta segurava a rodada | corrigido: 15 s por chamada, rodada para em 100 s (trava é de 5 min); teste |
| E4 | média | A configuração "função pública" não estava no repositório; um redeploy padrão desligaria os e-mails | corrigido: `supabase/config.toml` com `verify_jwt = false` |
| F2 | média | No Modo Camaleão, a Administração mostrava os painéis de admin e os botões Encerrar/Iniciar Safra e Forçar envio | corrigido: só com a visão admin; sem botões de ação no Camaleão; e2e ajustado |
| F3 | média-baixa | Painel de e-mails ficava "Carregando..." para sempre se os totais falhassem; "Atualizar" sem retorno | corrigido: mensagem de erro e "Atualizando..." |
| A5 | baixa | Proposta recusada antes de encaminhar aparecia para os donos de card | corrigido; teste |
| A6 | baixa | Card 100 viraria SAFRA-10 e a publicação falharia | corrigido |
| E7 | baixa | A função pública dizia quais segredos faltavam | corrigido: só "disabled" |
| E8/E9 | baixa | `fetch` sem vínculo; texto de erro do provedor gravado (pode ter dados pessoais) | corrigido: só status e código do erro |
| F6 | baixa | Na tela de propostas, "Comentário" e "Como foi decidido" usavam o mesmo campo | corrigido |
| F9/D | baixa | Textos e documentos desatualizados (STATUS, PROFILE, ROADMAP, GI, RUNBOOK, e2e) | corrigidos |

## 3. Não corrigido (decisão do owner ou baixo risco aceito)

| # | Ponto | Situação |
|---|---|---|
| Q1 | O Jair pode registrar o dono antes de todos os donos consultados responderem (e até escolher quem não aceitou) | **pergunta ao owner**: vale só depois de todos responderem? E se alguém não responder? |
| Q2 | Histórico da proposta (quem fez o quê, comentários) aparece para quem propôs e para os donos consultados | **pergunta ao owner**: a D-108 (histórico só para gestão/admins) vale também para propostas? |
| Q3 | Sem limite de propostas por pessoa | **pergunta ao owner**: limitar (ex.: 3 abertas por pessoa)? |
| R1 | A aprovação não confere se o conteúdo mudou entre a leitura do Jair e o clique | baixo risco; quem propõe pode corrigir até a aprovação (D-127) |
| R2 | A função de envio é pública | aceito (D-133): só devolve contagens; travas evitam e-mail repetido |
| R3 | Pelo navegador, o envio usa sempre a conexão Outlook | tema da GI-SAFRA-017 (aplicativo do TI) |
| R4 | e2e não cobre o fluxo inteiro da M10 nem o painel de e-mails; testes de banco não conferem `authenticated` em todas as funções novas | próximos testes |
| R5 | Nomes e e-mails corporativos da equipe no repositório público | risco já conhecido; não são segredos |

## 4. Depois de aplicar

- PRIMARY com 62 migrations (= repositório).
- O site precisa ser **publicado** para valer: conferência de acesso, Modo Camaleão na Administração, painel de e-mails e o botão "Forçar envio agora".
