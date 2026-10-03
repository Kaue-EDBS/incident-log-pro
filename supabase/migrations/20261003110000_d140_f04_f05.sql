-- D-140 (03/10/2026, owner): fim do roteiro do MVP.
-- F03 (pós-mortem) e F06 (relatório executivo) cancelados.
-- F04: os Indicadores ganham contagens e tempos — abertos, encerrados, cancelados, em andamento,
--      tempo mediano e p90 (da abertura até a última parte concluir), pico de protocolos ao mesmo
--      tempo e áreas mais impactadas. Mesma Safra, mesmas exclusões (D-115) e mesmas audiências.
-- F05: governança semanal para Jair, Bruno e admins — resumo da semana (segunda a domingo,
--      horário de São Paulo) e registro das ações decididas na reunião (que continua fora do
--      Painel, D-61). O registro só cresce: nada é apagado ou alterado.
begin;

-- F04 -----------------------------------------------------------------------------------
create or replace function private.safra_volume_metrics_json(p_scenario_ids uuid[])
returns jsonb
language sql
stable
set search_path = ''
as $$
  with base as (
    select t.id, t.scenario_id, t.status, t.opened_at, t.cancelled_at,
           case when t.status = 'RESOLVED' then
             case when t.auto_resolved then coalesce(t.requester_closed_at, t.owner_closed_at)
                  else greatest(t.requester_closed_at, t.owner_closed_at) end
           end as resolved_at
    from public.treatments t
    where t.scenario_id = any (p_scenario_ids)
      and t.opened_at >= private.safra_current_season_start()
      and t.opened_at < coalesce(private.safra_current_season_end(), 'infinity'::timestamptz)
      and not exists (select 1 from public.treatment_analytics_exclusions x where x.treatment_id = t.id)
  ),
  dur as (
    select b.*, extract(epoch from b.resolved_at - b.opened_at)::double precision as secs from base b
  ),
  per_card as (
    select d.scenario_id,
           count(*) as opened,
           count(*) filter (where d.status = 'RESOLVED') as resolved,
           count(*) filter (where d.status = 'CANCELLED') as cancelled,
           count(*) filter (where d.status = 'ACTIVE') as active,
           round(percentile_cont(0.5) within group (order by d.secs)) as median_secs,
           round(percentile_cont(0.9) within group (order by d.secs)) as p90_secs
    from dur d
    group by d.scenario_id
  ),
  overall as (
    select count(*) as opened,
           count(*) filter (where d.status = 'RESOLVED') as resolved,
           count(*) filter (where d.status = 'CANCELLED') as cancelled,
           count(*) filter (where d.status = 'ACTIVE') as active,
           round(percentile_cont(0.5) within group (order by d.secs)) as median_secs,
           round(percentile_cont(0.9) within group (order by d.secs)) as p90_secs
    from dur d
  ),
  edges as (
    select b.opened_at as at, 1 as delta from base b
    union all
    select coalesce(b.resolved_at, b.cancelled_at, clock_timestamp()), -1 from base b
  ),
  running as (
    select sum(e.delta) over (order by e.at, e.delta rows unbounded preceding) as open_now from edges e
  ),
  areas as (
    select oa.name, count(distinct b.id) as protocols
    from base b
    join public.treatment_impacted_areas tia on tia.treatment_id = b.id and tia.valid_to is null
    join public.operational_areas oa on oa.id = tia.operational_area_id
    group by oa.name
    order by 2 desc, 1
    limit 5
  )
  select jsonb_build_object(
    'consolidated', (select jsonb_build_object(
        'opened', o.opened, 'resolved', o.resolved, 'cancelled', o.cancelled, 'active', o.active,
        'median_secs', o.median_secs, 'p90_secs', o.p90_secs,
        'peak_simultaneous', coalesce((select max(r.open_now) from running r), 0))
      from overall o),
    'cards', coalesce((
      select jsonb_agg(jsonb_build_object(
        'scenario_id', sc.id, 'code', sc.code, 'name', sc.name,
        'opened', coalesce(pc.opened, 0), 'resolved', coalesce(pc.resolved, 0),
        'cancelled', coalesce(pc.cancelled, 0), 'active', coalesce(pc.active, 0),
        'median_secs', pc.median_secs, 'p90_secs', pc.p90_secs) order by sc.code)
      from public.scenarios sc
      left join per_card pc on pc.scenario_id = sc.id
      where sc.id = any (p_scenario_ids)), '[]'::jsonb),
    'areas', coalesce((select jsonb_agg(jsonb_build_object('name', a.name, 'protocols', a.protocols) order by a.protocols desc, a.name) from areas a), '[]'::jsonb)
  );
$$;

revoke all on function private.safra_volume_metrics_json(uuid[]) from public, anon, authenticated;

create or replace function public.safra_get_reliability_metrics(p_owner_principal_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_all boolean;
  v_cards uuid[];
  v_scope text;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_ANALYTICS_FORBIDDEN';
  end if;

  v_all := private.safra_has_role('safra_governance_admin')
        or private.safra_has_role('safra_executive_admin')
        or private.safra_has_role('safra_platform_admin');

  if p_owner_principal_id is not null then
    if not coalesce(private.safra_can_use_chameleon(), false) then
      raise exception using errcode = '42501', message = 'SAFRA_ANALYTICS_FORBIDDEN';
    end if;
    select coalesce(array_agg(so.scenario_id), '{}') into v_cards
    from public.scenario_owners so
    where so.owner_id = p_owner_principal_id and so.valid_to is null;
    v_scope := 'OWNER';
  elsif v_all then
    select coalesce(array_agg(sc.id), '{}') into v_cards from public.scenarios sc;
    v_scope := 'ALL';
  else
    select coalesce(array_agg(so.scenario_id), '{}') into v_cards
    from public.scenario_owners so
    join private.safra_principals p on p.id = so.owner_id
    where so.valid_to is null and p.user_id = v_actor and p.is_active;
    if cardinality(v_cards) = 0 then
      raise exception using errcode = '42501', message = 'SAFRA_ANALYTICS_FORBIDDEN';
    end if;
    v_scope := 'OWNER';
  end if;

  return private.safra_reliability_metrics_json(v_cards)
      || jsonb_build_object('scope', v_scope, 'volume', private.safra_volume_metrics_json(v_cards));
end;
$$;

-- F05 -----------------------------------------------------------------------------------
create table public.governance_actions (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  scenario_id uuid references public.scenarios(id) on delete restrict,
  action_type text not null,
  description text not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  constraint governance_actions_type_check check (action_type in (
    'PROCESS_CHANGE', 'MASTER_DATA_FIX', 'CAPACITY_CHANGE', 'PARTNER_ACTION',
    'SYSTEM_CHANGE', 'TRAINING', 'NO_ACTION_JUSTIFIED')),
  constraint governance_actions_description_len check (length(btrim(description)) between 10 and 1000),
  constraint governance_actions_week_is_monday check (extract(isodow from week_start) = 1)
);

create index idx_governance_actions_week on public.governance_actions(week_start);
create index idx_governance_actions_scenario on public.governance_actions(scenario_id);
create index idx_governance_actions_created_by on public.governance_actions(created_by);

comment on table public.governance_actions is
  'D-140 (F05): actions decided in the weekly governance meeting (meeting itself outside the app, D-61). Append-only.';

create or replace function private.safra_governance_actions_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'governance actions are append-only';
end;
$$;

revoke all on function private.safra_governance_actions_append_only() from public, anon, authenticated;

create trigger trg_governance_actions_append_only
before update or delete on public.governance_actions
for each row execute function private.safra_governance_actions_append_only();

alter table public.governance_actions enable row level security;
revoke all on public.governance_actions from public, anon, authenticated;
revoke truncate on public.governance_actions from service_role;

-- Segunda-feira da semana (horário de São Paulo) de uma data; sem data, a semana atual.
create or replace function private.safra_week_start(p_day date)
returns date
language sql
stable
set search_path = ''
as $$
  select d - (extract(isodow from d)::integer - 1)
  from (select coalesce(p_day, (clock_timestamp() at time zone 'America/Sao_Paulo')::date) as d) x
$$;

revoke all on function private.safra_week_start(date) from public, anon, authenticated;

create or replace function private.safra_is_governance_viewer()
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

revoke all on function private.safra_is_governance_viewer() from public, anon, authenticated;

create or replace function public.safra_get_weekly_governance(p_week_start date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_week date := private.safra_week_start(p_week_start);
  v_from timestamptz;
  v_to timestamptz;
begin
  if (select auth.uid()) is null or not coalesce(public.safra_is_corporate_user(), false)
     or not coalesce(private.safra_is_governance_viewer(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_GOVERNANCE_FORBIDDEN';
  end if;
  v_from := v_week::timestamp at time zone 'America/Sao_Paulo';
  v_to := v_from + interval '7 days';

  return (
    with base as (
      select t.id, t.protocol_number, t.scenario_id, t.status, t.opened_at, t.cancelled_at,
             t.requester_closed_at, t.owner_closed_at,
             case when t.status = 'RESOLVED' then
               case when t.auto_resolved then coalesce(t.requester_closed_at, t.owner_closed_at)
                    else greatest(t.requester_closed_at, t.owner_closed_at) end
             end as resolved_at
      from public.treatments t
      where not exists (select 1 from public.treatment_analytics_exclusions x where x.treatment_id = t.id)
    )
    select jsonb_build_object(
      'week_start', v_week,
      'week_end', v_week + 6,
      'can_register', true,
      'totals', jsonb_build_object(
        'opened', (select count(*) from base b where b.opened_at >= v_from and b.opened_at < v_to),
        'resolved', (select count(*) from base b where b.resolved_at >= v_from and b.resolved_at < v_to),
        'cancelled', (select count(*) from base b where b.cancelled_at >= v_from and b.cancelled_at < v_to),
        'opened_previous_week', (select count(*) from base b
                                 where b.opened_at >= v_from - interval '7 days' and b.opened_at < v_from),
        'active_now', (select count(*) from base b where b.status = 'ACTIVE')),
      'cards', coalesce((
        select jsonb_agg(c order by (c->>'opened')::int desc, c->>'code')
        from (
          select jsonb_build_object(
                   'scenario_id', sc.id, 'code', sc.code, 'name', sc.name,
                   'opened', count(*) filter (where b.opened_at >= v_from and b.opened_at < v_to),
                   'opened_previous_week', count(*) filter (where b.opened_at >= v_from - interval '7 days' and b.opened_at < v_from),
                   'resolved', count(*) filter (where b.resolved_at >= v_from and b.resolved_at < v_to),
                   'cancelled', count(*) filter (where b.cancelled_at >= v_from and b.cancelled_at < v_to),
                   'median_secs', round(percentile_cont(0.5) within group (
                       order by case when b.resolved_at >= v_from and b.resolved_at < v_to
                                     then extract(epoch from b.resolved_at - b.opened_at)::double precision end))) as c
          from public.scenarios sc
          left join base b on b.scenario_id = sc.id
          group by sc.id, sc.code, sc.name
        ) x
        where (x.c->>'opened')::int > 0 or (x.c->>'resolved')::int > 0 or (x.c->>'cancelled')::int > 0
               or (x.c->>'opened_previous_week')::int > 0), '[]'::jsonb),
      'longest', coalesce((
        select jsonb_agg(y.l order by y.secs desc)
        from (
          select jsonb_build_object('protocol_number', b.protocol_number, 'code', sc.code, 'name', sc.name,
                                    'duration_secs', round(extract(epoch from b.resolved_at - b.opened_at))) as l,
                 extract(epoch from b.resolved_at - b.opened_at) as secs
          from base b join public.scenarios sc on sc.id = b.scenario_id
          where b.resolved_at >= v_from and b.resolved_at < v_to
          order by b.resolved_at - b.opened_at desc
          limit 5
        ) y), '[]'::jsonb),
      'active', coalesce((
        select jsonb_agg(z.a order by z.opened_at)
        from (
          select b.opened_at,
                 jsonb_build_object('protocol_number', b.protocol_number, 'code', sc.code, 'name', sc.name,
                                    'opened_at', b.opened_at,
                                    'situation', case when b.requester_closed_at is null and b.owner_closed_at is null then 'EM_ANDAMENTO'
                                                      when b.requester_closed_at is not null then 'AGUARDANDO_DONO'
                                                      else 'AGUARDANDO_SOLICITANTE' end) as a
          from base b join public.scenarios sc on sc.id = b.scenario_id
          where b.status = 'ACTIVE'
          order by b.opened_at
          limit 50
        ) z), '[]'::jsonb),
      'actions', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', ga.id, 'action_type', ga.action_type, 'description', ga.description,
                 'code', sc.code, 'name', sc.name,
                 'created_by_name', private.safra_user_display_name(ga.created_by),
                 'created_at', ga.created_at) order by ga.created_at desc)
        from public.governance_actions ga
        left join public.scenarios sc on sc.id = ga.scenario_id
        where ga.week_start = v_week), '[]'::jsonb),
      'card_options', coalesce((
        select jsonb_agg(jsonb_build_object('scenario_id', sc.id, 'code', sc.code, 'name', sc.name) order by sc.code)
        from public.scenarios sc), '[]'::jsonb)
    )
  );
end;
$$;

create or replace function public.safra_register_governance_action(
  p_week_start date,
  p_scenario_id uuid,
  p_action_type text,
  p_description text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
  v_id uuid;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false)
     or not coalesce(private.safra_is_governance_viewer(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_GOVERNANCE_FORBIDDEN';
  end if;
  if p_action_type is null or p_action_type not in ('PROCESS_CHANGE', 'MASTER_DATA_FIX', 'CAPACITY_CHANGE',
       'PARTNER_ACTION', 'SYSTEM_CHANGE', 'TRAINING', 'NO_ACTION_JUSTIFIED') then
    raise exception using errcode = '22023', message = 'SAFRA_GOVERNANCE_INVALID_TYPE';
  end if;
  if v_description is null or length(v_description) < 10 or length(v_description) > 1000 then
    raise exception using errcode = '22023', message = 'SAFRA_GOVERNANCE_DESCRIPTION_REQUIRED';
  end if;
  if p_scenario_id is not null and not exists (select 1 from public.scenarios sc where sc.id = p_scenario_id) then
    raise exception using errcode = '22023', message = 'SAFRA_GOVERNANCE_INVALID_CARD';
  end if;

  insert into public.governance_actions(week_start, scenario_id, action_type, description, created_by)
  values (private.safra_week_start(p_week_start), p_scenario_id, p_action_type, v_description, v_actor)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.safra_get_weekly_governance(date) from public, anon;
revoke all on function public.safra_register_governance_action(date, uuid, text, text) from public, anon;
grant execute on function public.safra_get_weekly_governance(date) to authenticated, service_role;
grant execute on function public.safra_register_governance_action(date, uuid, text, text) to authenticated, service_role;

-- Uso das telas (D-124) conta a tela nova ---------------------------------------------------
alter table public.screen_views_daily drop constraint screen_views_route_check;
alter table public.screen_views_daily add constraint screen_views_route_check check (route in (
  '/', '/meus-protocolos', '/protocolos-dos-meus-cards', '/todos-os-protocolos',
  '/cards-e-donos', '/analytics', '/administracao', '/propostas', '/governanca-semanal'
));

create or replace function public.safra_log_screen_view(p_route text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_route text := nullif(btrim(coalesce(p_route, '')), '');
begin
  if (select auth.uid()) is null or not coalesce(public.safra_is_corporate_user(), false) then
    return;
  end if;
  if v_route is null or v_route not in (
    '/', '/meus-protocolos', '/protocolos-dos-meus-cards', '/todos-os-protocolos',
    '/cards-e-donos', '/analytics', '/administracao', '/propostas', '/governanca-semanal'
  ) then
    return; -- tela desconhecida: ignora, sem erro para a pessoa
  end if;

  insert into public.screen_views_daily(day, route, views)
  values ((clock_timestamp() at time zone 'America/Sao_Paulo')::date, v_route, 1)
  on conflict (day, route) do update set views = public.screen_views_daily.views + 1;
end;
$$;

revoke all on function public.safra_log_screen_view(text) from public, anon;
grant execute on function public.safra_log_screen_view(text) to authenticated, service_role;

commit;
