# Envio automático de e-mails pelo Painel aberto (Opção 2)

## Objetivo
Quando alguém abre, conclui ou cancela um protocolo no link publicado, os e-mails saem na hora. Os lembretes saem a cada 2 minutos enquanto houver um Painel aberto com login corporativo. O remetente continua sendo painel.safra@ (pela conexão Outlook do Kaue, como solução provisória).

## Etapas (cada uma com sua conferência)

1. **Confirmar a causa antes de mexer**
   - Ler os registros do servidor publicado e chamar a rotina de envio com uma sessão real.
   - Confirmar qual destes casos acontece: chave de sistema ausente, verificação corporativa recusada ou erro no formato da mensagem.
   - Conferência: o erro exato fica registrado. Se a causa for outra, ajusto o plano antes de seguir.

2. **Conferência D-52 no início**
   - Comparar a lista de migrations aplicadas no banco com os arquivos do repositório. Hoje já se sabe que 20261001234000 está pendente.
   - Conferência: relatório da diferença, sem aplicar nada que não seja desta tarefa.

3. **Nova migration (arquivo em supabase/migrations)**
   - Criar duas funções novas para usuários logados: `safra_notifications_claim_for_session` e `safra_notifications_report_for_session`.
   - Antes de qualquer ação, as duas exigem `safra_is_corporate_user() = true`.
   - Elas reaproveitam a lógica das funções atuais, que ficam intactas e continuam só para o sistema.
   - Permissão de uso apenas para usuários logados (`authenticated`), nunca para visitantes (`anon`). `search_path` fixo.
   - O retorno da fila contém só id, destinatário, assunto, texto e tentativa, como hoje.
   - Teste de banco novo (pgTAP): visitante é bloqueado, usuário logado sem conta corporativa é bloqueado e usuário corporativo consegue pegar a fila. Também testa que duas chamadas ao mesmo tempo não pegam o mesmo aviso.
   - Conferência: aplicar o mesmo conteúdo, byte a byte, no banco PRIMARY, rodar o teste e verificar as permissões.

4. **Ajuste na rotina de envio**
   - A rotina passa a usar a sessão do próprio usuário (`context.supabase`) em vez da chave de sistema.
   - `saveToSentItems` vai para a raiz da mensagem.
   - As falhas passam a ser registradas (`logOpsEvent`) em vez de ignoradas em silêncio.
   - Conferência: verificação de tipos limpa, compilação OK e teste no ambiente de testes com sessão real. Abro um envio de teste para o Kaue e confirmo SENT no banco e HTTP 202.

5. **Documentação**
   - Registrar a decisão provisória em docs/DECISOES.md e atualizar docs/STATUS.md.
   - Abrir uma pendência (GI) em docs/GOVERNANCE_ISSUES.md: "trocar pelo registro de aplicativo da TI".

6. **Entrega**
   - Você publica e abre um protocolo de teste. Eu acompanho a fila e confirmo que o envio foi automático.

## Limites que continuam valendo
- Com nenhum Painel aberto, os lembretes esperam (até 24h na fila).
- O envio depende da conexão Outlook do Kaue seguir ativa.
- Qualquer usuário corporativo logado pode acionar o esvaziamento da fila. Ele não vê o conteúdo dos avisos na tela: só o servidor recebe e despacha.

## Detalhes técnicos
- As funções novas são `SECURITY DEFINER` e não aceitam parâmetros livres além do limite, que fica entre 1 e 20.
- A função de relatório só aceita ids que estejam travados no momento (`locked_until > now()`), para impedir marcar avisos de outros como enviados.
- Nenhuma alteração em tabelas, nas regras D-111 nem nas funções atuais.
