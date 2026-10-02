-- SAFRA-C09 (02/10/2026) — fundação operacional.
--
-- D-93  meta de recuperação revista: perda máxima de dados de até 24 h (RPO) e volta em
--       até 4 h (RTO), compatível com o backup diário do Lovable Cloud. Resolve GI-SAFRA-012.
-- D-95  registro técnico (observabilidade mínima): erros de tela, respostas lentas, login
--       recusado e falhas de ação; 90 dias; só admins leem; identifica só o código do usuário;
--       nunca guarda chaves, tokens ou senhas.
begin;

-- 1. Registro técnico --------------------------------------------------------------
create table public.ops_events (
  id uuid primary key default gen_random_uuid(),
  occurred_at timestamptz not null default now(),
  kind text not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  route text,
  code text,
  duration_ms integer,
  detail jsonb not null default '{}'::jsonb,
  constraint ops_events_kind_check check (kind = any (array[
    'CLIENT_ERROR'::text, 'SLOW_RESPONSE'::text, 'LOGIN_DENIED'::text, 'ACTION_FAILED'::text
  ])),
  constraint ops_events_route_len check (route is null or length(route) <= 200),
  constraint ops_events_code_len check (code is null or length(code) <= 100),
  constraint ops_events_duration_range check (duration_ms is null or duration_ms between 0 and 600000),
  constraint ops_events_detail_size check (length(detail::text) <= 2000)
);

alter table public.ops_events enable row level security;
revoke all on public.ops_events from public, anon, authenticated;
create index idx_ops_events_occurred_at on public.ops_events(occurred_at);
create index idx_ops_events_actor on public.ops_events(actor_user_id);

create or replace function private.safra_ops_event_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.occurred_at := clock_timestamp();
  return new;
end;
$$;

create trigger trg_00_ops_events_server_clock
before insert on public.ops_events
for each row execute function private.safra_ops_event_server_clock();

create or replace function public.safra_log_ops_event(
  p_kind text,
  p_route text default null,
  p_code text default null,
  p_duration_ms integer default null,
  p_detail jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_detail jsonb := coalesce(p_detail, '{}'::jsonb);
begin
  -- Qualquer sessão autenticada registra (inclusive a recusada como não corporativa);
  -- anon não tem permissão de executar.
  if v_actor is null then
    return;
  end if;

  if p_kind is null or p_kind <> all (array['CLIENT_ERROR','SLOW_RESPONSE','LOGIN_DENIED','ACTION_FAILED']) then
    raise exception using errcode = '22023', message = 'SAFRA_OPS_EVENT_INVALID_KIND';
  end if;

  -- Retenção de 90 dias (D-95), limpa aos poucos a cada registro.
  delete from public.ops_events
  where id in (
    select id from public.ops_events
    where occurred_at < clock_timestamp() - interval '90 days'
    limit 500
  );

  -- Limite de volume: até 30 eventos por pessoa por minuto; o excesso é descartado.
  if (select count(*) from public.ops_events e
      where e.actor_user_id = v_actor and e.occurred_at > clock_timestamp() - interval '1 minute') >= 30 then
    return;
  end if;

  -- Nunca guardar segredos: tokens JWT, chaves do Supabase ou senhas.
  if v_detail::text ~* '(eyJ[A-Za-z0-9_-]{10,}|sb_secret_|sb_publishable_|service_role|password|senha|bearer)' then
    v_detail := jsonb_build_object('redacted', true);
  end if;
  if length(v_detail::text) > 2000 then
    v_detail := jsonb_build_object('truncated', true);
  end if;

  insert into public.ops_events(kind, actor_user_id, route, code, duration_ms, detail)
  values (
    p_kind,
    v_actor,
    left(nullif(btrim(coalesce(p_route, '')), ''), 200),
    left(nullif(btrim(coalesce(p_code, '')), ''), 100),
    case when p_duration_ms between 0 and 600000 then p_duration_ms end,
    v_detail
  );

end;
$$;

revoke all on function public.safra_log_ops_event(text, text, text, integer, jsonb) from public, anon;
grant execute on function public.safra_log_ops_event(text, text, text, integer, jsonb) to authenticated, service_role;

-- 2. Saúde do sistema para admins -----------------------------------------------------
create or replace function public.safra_admin_get_ops_summary(p_hours integer default 24)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_since timestamptz := clock_timestamp() - make_interval(hours => greatest(1, least(coalesce(p_hours, 24), 2160)));
begin
  if v_actor is null
     or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_platform_admin')
  then
    raise exception using errcode = '42501', message = 'SAFRA_OPS_FORBIDDEN';
  end if;

  return jsonb_build_object(
    'since', v_since,
    'server_time', clock_timestamp(),
    'events_by_kind', coalesce((
      select jsonb_object_agg(kind, n) from (
        select kind, count(*) n from public.ops_events where occurred_at >= v_since group by kind
      ) x
    ), '{}'::jsonb),
    'slow_p95_ms', (
      select percentile_disc(0.95) within group (order by duration_ms)
      from public.ops_events where occurred_at >= v_since and kind = 'SLOW_RESPONSE'
    ),
    'protocols', jsonb_build_object(
      'opened', (select count(*) from public.treatments where opened_at >= v_since),
      'resolved', (select count(*) from public.treatments where closed_at >= v_since),
      'cancelled', (select count(*) from public.treatments where cancelled_at >= v_since),
      'active_now', (select count(*) from public.treatments where status = 'ACTIVE'),
      'oldest_active_opened_at', (select min(opened_at) from public.treatments where status = 'ACTIVE')
    ),
    'recent', coalesce((
      select jsonb_agg(jsonb_build_object(
        'occurred_at', e.occurred_at, 'kind', e.kind, 'route', e.route, 'code', e.code,
        'duration_ms', e.duration_ms, 'actor_user_id', e.actor_user_id, 'detail', e.detail
      ) order by e.occurred_at desc)
      from (select * from public.ops_events where occurred_at >= v_since order by occurred_at desc limit 100) e
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.safra_admin_get_ops_summary(integer) from public, anon;
grant execute on function public.safra_admin_get_ops_summary(integer) to authenticated, service_role;

-- 3. GI-SAFRA-012 resolvida pela D-93 (só onde o login do owner existe, como na C01-AUD2) --
do $$
declare
  v_owner uuid;
begin
  select u.id into v_owner from auth.users u where lower(u.email) = 'kaue.pastrello@editoradobrasil.com.br';
  if v_owner is not null then
    update public.governance_issues
       set status = 'RESOLVED',
           resolved_by = v_owner,
           resolution_text = 'D-93 (02/10/2026): meta de recuperação revista para perda máxima de dados de até 24 h (RPO) e volta em até 4 h (RTO), compatível com o backup diário do Lovable Cloud. Restauração ponto a ponto (PITR) fica como melhoria futura.'
     where issue_key = 'GI-SAFRA-012'
       and status = 'OPEN';
  end if;
end;
$$;

commit;
