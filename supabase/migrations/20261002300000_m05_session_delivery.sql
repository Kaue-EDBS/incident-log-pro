-- SAFRA-M05 (provisório, D-132): enquanto o TI não entrega o registro de aplicativo, o Painel
-- aberto esvazia a fila de avisos com a sessão de quem está logado, sem ninguém ler aviso alheio:
--   * gestão e admins (Jair, Bruno, platform admins), que já veem todos os protocolos e avisos
--     (D-108), entregam a fila inteira, inclusive lembretes e avisos automáticos;
--   * as demais pessoas entregam só os avisos que a própria ação acabou de gerar.
-- Só quem pegou o aviso pode informar o resultado. As funções originais (só service_role) não mudam.
begin;

-- Quem gerou o aviso (null = o próprio sistema: varredura, lembretes, cancelamento de 72 h) e
-- quem o pegou para entregar agora.
alter table public.notifications_log
  add column triggered_by uuid default auth.uid(),
  add column claimed_by uuid;

create index if not exists idx_notifications_log_triggered_by
  on public.notifications_log(triggered_by) where delivery_status = 'QUEUED';

create or replace function private.safra_is_delivery_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.safra_has_role('safra_governance_admin')
      or private.safra_has_role('safra_executive_admin')
      or private.safra_has_role('safra_platform_admin')
$$;

revoke all on function private.safra_is_delivery_staff() from public, anon, authenticated;

create or replace function public.safra_notifications_claim_for_session(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_staff boolean;
  v_result jsonb;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_DELIVERY_FORBIDDEN';
  end if;
  v_staff := coalesce(private.safra_is_delivery_staff(), false);

  if v_staff then
    -- Mesmas regras de validade do carteiro oficial: não mandar atrasado.
    update public.notifications_log n
       set delivery_status = 'FAILED', failure_reason = 'EXPIRED_PROTOCOL_NOT_ACTIVE'
     where n.delivery_status = 'QUEUED'
       and n.notification_type like 'REMINDER_%'
       and exists (select 1 from public.treatments t where t.id = n.treatment_id and t.status <> 'ACTIVE');
    update public.notifications_log n
       set delivery_status = 'FAILED', failure_reason = 'EXPIRED_TOO_OLD'
     where n.delivery_status = 'QUEUED'
       and n.queued_at < clock_timestamp() - interval '24 hours';
  end if;

  with picked as (
    select n.id
    from public.notifications_log n
    where n.delivery_status = 'QUEUED'
      and n.next_attempt_at <= clock_timestamp()
      and n.queued_at >= clock_timestamp() - interval '24 hours'
      and (n.locked_until is null or n.locked_until < clock_timestamp())
      and (v_staff or n.triggered_by = v_actor)
    order by n.next_attempt_at, n.queued_at
    limit greatest(1, least(coalesce(p_limit, 20), 20))
    for update skip locked
  ),
  claimed as (
    update public.notifications_log n
       set attempts = n.attempts + 1,
           locked_until = clock_timestamp() + interval '5 minutes',
           claimed_by = v_actor
      from picked
     where n.id = picked.id
    returning n.id, n.recipient_email, n.subject, n.body, n.attempts
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'to', c.recipient_email, 'subject', c.subject, 'body', c.body, 'attempt', c.attempts)), '[]'::jsonb)
    into v_result
  from claimed c;

  return v_result;
end;
$$;

create or replace function public.safra_notifications_report_for_session(p_id uuid, p_ok boolean, p_error text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_DELIVERY_FORBIDDEN';
  end if;
  -- Só quem pegou o aviso, e só enquanto a rodada dele está em andamento.
  if not exists (
    select 1 from public.notifications_log
    where id = p_id and delivery_status = 'QUEUED'
      and claimed_by = v_actor and locked_until > clock_timestamp()
  ) then
    return;
  end if;
  perform public.safra_notifications_report(p_id, p_ok, left(p_error, 500));
end;
$$;

revoke all on function public.safra_notifications_claim_for_session(integer) from public, anon;
revoke all on function public.safra_notifications_report_for_session(uuid, boolean, text) from public, anon;
grant execute on function public.safra_notifications_claim_for_session(integer) to authenticated, service_role;
grant execute on function public.safra_notifications_report_for_session(uuid, boolean, text) to authenticated, service_role;

commit;
