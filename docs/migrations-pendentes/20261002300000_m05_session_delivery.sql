-- SAFRA-M05 (provisório, D-121): o Painel aberto por um usuário corporativo pode esvaziar a fila
-- de avisos usando a própria sessão, enquanto a TI não entrega o registro de aplicativo.
-- As funções originais (só service_role) ficam intactas.
-- DESTINO: supabase/migrations/20261002300000_m05_session_delivery.sql (commit no GitHub, D-52).

create or replace function public.safra_notifications_claim_for_session(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or public.safra_is_corporate_user() is not true then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  return public.safra_notifications_claim(greatest(1, least(coalesce(p_limit, 20), 20)));
end;
$$;

create or replace function public.safra_notifications_report_for_session(p_id uuid, p_ok boolean, p_error text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or public.safra_is_corporate_user() is not true then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  -- Só aceita avisos travados agora (pegos por uma rodada em andamento).
  if not exists (
    select 1 from public.notifications_log
    where id = p_id and delivery_status = 'QUEUED' and locked_until > clock_timestamp()
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
