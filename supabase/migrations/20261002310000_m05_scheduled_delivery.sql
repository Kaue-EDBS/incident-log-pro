-- SAFRA-M05 (D-133): e-mails automáticos, sem depender de alguém com o Painel aberto.
-- A cada 2 minutos o agendador do banco chama a função de envio do servidor
-- (`safra-send-notifications`), que esvazia a fila com a chave de sistema e envia pelo aplicativo
-- do TI ou, até lá, pela conexão Microsoft Outlook do Lovable. A função só devolve contagens.
-- O envio pelo Painel aberto (D-132) continua como reforço; a fila trava cada aviso antes de
-- enviar, então ninguém recebe o mesmo aviso duas vezes.
begin;

create extension if not exists pg_net;

select cron.schedule('safra-send-notifications', '*/2 * * * *', $$
  select net.http_post(
    url := 'https://trqkwqkjjjeppuddwenu.supabase.co/functions/v1/safra-send-notifications',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  )
$$);

commit;
