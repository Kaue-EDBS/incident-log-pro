-- SAFRA-M05 — Visor da fila de avisos (somente leitura), exclusivo do Kauê.
-- PENDENTE (D-52): copiar para supabase/migrations/, commitar e aplicar no PRIMARY.
-- Não expõe segredos: só situação, destinatário, assunto, horários, tentativas e erro.
create or replace function public.safra_admin_get_notifications_queue(p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_lim integer := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if auth.uid() is null or not public.safra_is_corporate_user()
     or not public.safra_has_role('safra_platform_admin')
     or lower(coalesce(auth.jwt() ->> 'email', '')) <> 'kaue.pastrello@editoradobrasil.com.br' then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(row_to_json(t)::jsonb order by t.queued_at desc) from (
      select n.id, n.notification_type, n.recipient_name, n.recipient_email, n.subject,
             n.delivery_status, n.queued_at, n.sent_at, n.failed_at, n.attempts,
             n.next_attempt_at, left(coalesce(n.last_error, n.failure_reason), 300) as error
      from public.notifications_log n order by n.queued_at desc limit v_lim) t), '[]'::jsonb));
end; $$;
revoke all on function public.safra_admin_get_notifications_queue(integer) from public, anon;
grant execute on function public.safra_admin_get_notifications_queue(integer) to authenticated, service_role;
