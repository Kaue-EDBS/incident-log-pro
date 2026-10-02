-- SAFRA-M05 — Visor da fila de avisos (somente leitura), exclusivo do Kauê.
-- Mostra cada e-mail com a situação e o motivo do erro: situação, destinatário, assunto,
-- horários, tentativas e erro. Não mostra o texto do aviso nem segredos.
begin;

create or replace function public.safra_admin_get_notifications_queue(p_limit integer default 50)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_lim integer := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if (select auth.uid()) is null
     or not coalesce(public.safra_is_corporate_user(), false)
     or not coalesce(public.safra_has_role('safra_platform_admin'), false)
     or lower(coalesce((select auth.jwt() ->> 'email'), '')) <> 'kaue.pastrello@editoradobrasil.com.br' then
    raise exception using errcode = '42501', message = 'SAFRA_OPS_FORBIDDEN';
  end if;
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(row_to_json(t)::jsonb order by t.queued_at desc) from (
      select n.id, n.notification_type, n.recipient_name, n.recipient_email, n.subject,
             n.delivery_status, n.queued_at, n.sent_at, n.failed_at, n.attempts,
             n.next_attempt_at, left(coalesce(n.last_error, n.failure_reason), 300) as error
      from public.notifications_log n
      order by n.queued_at desc
      limit v_lim) t), '[]'::jsonb));
end;
$$;

revoke all on function public.safra_admin_get_notifications_queue(integer) from public, anon;
grant execute on function public.safra_admin_get_notifications_queue(integer) to authenticated, service_role;

commit;
