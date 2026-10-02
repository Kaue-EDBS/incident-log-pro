-- 02/10/2026 — marcação da Safra (D-59, D-69, D-70, D-118, D-119).
--
-- D-59  a Safra começa e termina por marcação manual do Kaue (só ele vê e usa os botões).
-- D-69  a Safra corrente começou em 01/10/2026 00:00 (São Paulo): é o primeiro registro.
-- D-70  encerrar exige digitar "ENCERRAR SAFRA" e pode ser desfeito em 7 dias, sem apagar dados.
-- D-118 com a Safra encerrada, ninguém abre protocolo novo até a próxima começar; os protocolos
--       já abertos continuam (concluir, desfazer, cancelar, fechamento automático e avisos).
-- D-119 a próxima Safra começa quando o Kaue apertar "Iniciar Safra".
-- O encerramento é o marco da retenção de dados (ADR-016).
begin;

-- 1. Registro das Safras ----------------------------------------------------------------
create table public.safra_seasons (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null,
  started_by uuid references auth.users(id) on delete restrict,
  ended_at timestamptz,
  ended_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  constraint safra_seasons_end_after_start check (ended_at is null or ended_at > started_at),
  constraint safra_seasons_end_author check (ended_at is not null or ended_by is null)
);

-- No máximo uma Safra aberta.
create unique index safra_seasons_one_open on public.safra_seasons ((true)) where ended_at is null;
create index idx_safra_seasons_started_by on public.safra_seasons(started_by);
create index idx_safra_seasons_ended_by on public.safra_seasons(ended_by);

create table public.safra_season_events (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.safra_seasons(id) on delete restrict,
  event_type text not null,
  actor_user_id uuid references auth.users(id) on delete restrict,
  occurred_at timestamptz not null default clock_timestamp(),
  note text,
  constraint safra_season_events_type_check check (event_type in ('STARTED', 'ENDED', 'END_UNDONE'))
);

create index idx_safra_season_events_season on public.safra_season_events(season_id);
create index idx_safra_season_events_actor on public.safra_season_events(actor_user_id);

create or replace function private.safra_season_events_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'safra season history is append-only';
end;
$$;

revoke all on function private.safra_season_events_append_only() from public, anon, authenticated;

create trigger trg_safra_season_events_append_only
before update or delete on public.safra_season_events
for each row execute function private.safra_season_events_append_only();

alter table public.safra_seasons enable row level security;
alter table public.safra_season_events enable row level security;
revoke all on public.safra_seasons from public, anon, authenticated;
revoke all on public.safra_season_events from public, anon, authenticated;

-- D-69: a Safra corrente começou em 01/10/2026 00:00 (São Paulo).
do $$
declare
  v_owner uuid;
  v_season uuid;
begin
  select u.id into v_owner from auth.users u where lower(u.email) = 'kaue.pastrello@editoradobrasil.com.br';
  insert into public.safra_seasons(started_at, started_by)
  values (timestamptz '2026-10-01 00:00:00-03', v_owner)
  returning id into v_season;
  insert into public.safra_season_events(season_id, event_type, actor_user_id, note)
  values (v_season, 'STARTED', v_owner, 'D-69: início registrado por decisão do owner (01/10/2026 00:00, São Paulo).');
end;
$$;

-- 2. Janela da Safra corrente (usada pelos indicadores) ---------------------------------
-- Corrente = a aberta; se nenhuma estiver aberta, a última encerrada.
create or replace function private.safra_current_season_start()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select s.started_at from public.safra_seasons s order by s.started_at desc limit 1
$$;

create or replace function private.safra_current_season_end()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select s.ended_at from public.safra_seasons s order by s.started_at desc limit 1
$$;

revoke all on function private.safra_current_season_start() from public, anon, authenticated;
revoke all on function private.safra_current_season_end() from public, anon, authenticated;

create or replace function private.safra_reliability_metrics_json(p_scenario_ids uuid[])
returns jsonb
language sql
stable
set search_path = ''
as $$
  with base as (
    select t.scenario_id,
           t.opened_at,
           t.problem_started_at,
           case when t.auto_resolved then coalesce(t.requester_closed_at, t.owner_closed_at)
                else greatest(t.requester_closed_at, t.owner_closed_at) end as resolved_at
    from public.treatments t
    where t.status = 'RESOLVED'
      and t.scenario_id = any (p_scenario_ids)
      and t.opened_at >= private.safra_current_season_start()
      and t.opened_at < coalesce(private.safra_current_season_end(), 'infinity'::timestamptz)
      and not exists (select 1 from public.treatment_analytics_exclusions x where x.treatment_id = t.id)
  ),
  ordered as (
    select b.*,
           max(b.resolved_at) over (partition by b.scenario_id order by b.opened_at, b.resolved_at
                                    rows between unbounded preceding and 1 preceding) as prev_max_end
    from base b
  ),
  numbered as (
    select o.*,
           sum(case when o.prev_max_end is null or o.opened_at > o.prev_max_end then 1 else 0 end)
             over (partition by o.scenario_id order by o.opened_at, o.resolved_at rows unbounded preceding) as episode
    from ordered o
  ),
  episodes as (
    select n.scenario_id, n.episode,
           min(n.opened_at) as start_at,
           max(n.resolved_at) as end_at,
           min(n.problem_started_at) as problem_at,
           count(*) as protocols
    from numbered n
    group by n.scenario_id, n.episode
  ),
  measured as (
    select e.scenario_id,
           e.protocols,
           extract(epoch from e.start_at - e.problem_at)::double precision as mttd,
           extract(epoch from e.end_at - e.start_at)::double precision as mttr,
           extract(epoch from e.start_at - lag(e.start_at) over w)::double precision as mtbf,
           extract(epoch from e.start_at - lag(e.end_at) over w)::double precision as mttf
    from episodes e
    window w as (partition by e.scenario_id order by e.start_at)
  ),
  per_card as (
    select m.scenario_id,
           count(*) as failures,
           sum(m.protocols) as protocols,
           round(avg(m.mttd)) as mttd_mean, round(percentile_cont(0.5) within group (order by m.mttd)) as mttd_median,
           round(avg(m.mttr)) as mttr_mean, round(percentile_cont(0.5) within group (order by m.mttr)) as mttr_median,
           round(avg(m.mtbf)) as mtbf_mean, round(percentile_cont(0.5) within group (order by m.mtbf)) as mtbf_median,
           round(avg(m.mttf)) as mttf_mean, round(percentile_cont(0.5) within group (order by m.mttf)) as mttf_median
    from measured m
    group by m.scenario_id
  ),
  overall as (
    select count(*) as failures,
           coalesce(sum(m.protocols), 0) as protocols,
           round(avg(m.mttd)) as mttd_mean, round(percentile_cont(0.5) within group (order by m.mttd)) as mttd_median,
           round(avg(m.mttr)) as mttr_mean, round(percentile_cont(0.5) within group (order by m.mttr)) as mttr_median,
           round(avg(m.mtbf)) as mtbf_mean, round(percentile_cont(0.5) within group (order by m.mtbf)) as mtbf_median,
           round(avg(m.mttf)) as mttf_mean, round(percentile_cont(0.5) within group (order by m.mttf)) as mttf_median
    from measured m
  )
  select jsonb_build_object(
    'season_start', private.safra_current_season_start(),
    'season_end', private.safra_current_season_end(),
    'as_of', clock_timestamp(),
    'excluded', (select count(*) from public.treatment_analytics_exclusions x
                 join public.treatments t on t.id = x.treatment_id
                 where t.scenario_id = any (p_scenario_ids)),
    'consolidated', (
      select jsonb_build_object(
        'failures', o.failures, 'protocols', o.protocols,
        'mttd', jsonb_build_object('mean', o.mttd_mean, 'median', o.mttd_median),
        'mttr', jsonb_build_object('mean', o.mttr_mean, 'median', o.mttr_median),
        'mtbf', jsonb_build_object('mean', o.mtbf_mean, 'median', o.mtbf_median),
        'mttf', jsonb_build_object('mean', o.mttf_mean, 'median', o.mttf_median))
      from overall o),
    'cards', coalesce((
      select jsonb_agg(jsonb_build_object(
        'scenario_id', sc.id, 'code', sc.code, 'name', sc.name,
        'failures', coalesce(pc.failures, 0), 'protocols', coalesce(pc.protocols, 0),
        'mttd', jsonb_build_object('mean', pc.mttd_mean, 'median', pc.mttd_median),
        'mttr', jsonb_build_object('mean', pc.mttr_mean, 'median', pc.mttr_median),
        'mtbf', jsonb_build_object('mean', pc.mtbf_mean, 'median', pc.mtbf_median),
        'mttf', jsonb_build_object('mean', pc.mttf_mean, 'median', pc.mttf_median)
      ) order by sc.code)
      from public.scenarios sc
      left join per_card pc on pc.scenario_id = sc.id
      where sc.id = any (p_scenario_ids)
    ), '[]'::jsonb)
  );
$$;

revoke all on function private.safra_reliability_metrics_json(uuid[]) from public, anon, authenticated;

-- 3. Só o Kaue marca a Safra (D-59) -----------------------------------------------------
create or replace function private.safra_is_season_manager()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
     and coalesce(public.safra_is_corporate_user(), false)
     and private.safra_has_role('safra_platform_admin')
     and exists (
       select 1 from private.safra_principals p
       where p.user_id = (select auth.uid())
         and p.is_active
         and lower(p.corporate_email) = 'kaue.pastrello@editoradobrasil.com.br'
     );
$$;

revoke all on function private.safra_is_season_manager() from public, anon, authenticated;

create or replace function public.safra_get_season()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_s public.safra_seasons%rowtype;
  v_manager boolean;
begin
  if (select auth.uid()) is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_SEASON_FORBIDDEN';
  end if;
  v_manager := coalesce(private.safra_is_season_manager(), false);
  select * into v_s from public.safra_seasons order by started_at desc limit 1;

  return jsonb_build_object(
    'open', v_s.id is not null and v_s.ended_at is null,
    'started_at', v_s.started_at,
    'ended_at', v_s.ended_at,
    'can_manage', v_manager,
    'undo_until', case when v_manager and v_s.ended_at is not null and v_s.ended_at > clock_timestamp() - interval '7 days'
                       then v_s.ended_at + interval '7 days' end,
    'server_time', clock_timestamp()
  );
end;
$$;

create or replace function public.safra_end_season(p_confirm text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_s public.safra_seasons%rowtype;
begin
  if not coalesce(private.safra_is_season_manager(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_SEASON_FORBIDDEN';
  end if;
  if coalesce(btrim(p_confirm), '') <> 'ENCERRAR SAFRA' then
    raise exception using errcode = '22023', message = 'SAFRA_SEASON_CONFIRM_REQUIRED';
  end if;

  select * into v_s from public.safra_seasons where ended_at is null for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'SAFRA_SEASON_NOT_OPEN';
  end if;

  update public.safra_seasons set ended_at = clock_timestamp(), ended_by = v_actor where id = v_s.id;
  insert into public.safra_season_events(season_id, event_type, actor_user_id, note)
  values (v_s.id, 'ENDED', v_actor, 'D-70: encerrada com a confirmação "ENCERRAR SAFRA".');
  return public.safra_get_season();
end;
$$;

create or replace function public.safra_undo_end_season()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_s public.safra_seasons%rowtype;
begin
  if not coalesce(private.safra_is_season_manager(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_SEASON_FORBIDDEN';
  end if;

  select * into v_s from public.safra_seasons order by started_at desc limit 1 for update;
  if v_s.id is null or v_s.ended_at is null then
    raise exception using errcode = 'P0001', message = 'SAFRA_SEASON_NOT_ENDED';
  end if;
  if v_s.ended_at <= clock_timestamp() - interval '7 days' then
    raise exception using errcode = 'P0001', message = 'SAFRA_SEASON_UNDO_EXPIRED';
  end if;

  update public.safra_seasons set ended_at = null, ended_by = null where id = v_s.id;
  insert into public.safra_season_events(season_id, event_type, actor_user_id, note)
  values (v_s.id, 'END_UNDONE', v_actor, 'D-70: encerramento desfeito dentro de 7 dias.');
  return public.safra_get_season();
end;
$$;

create or replace function public.safra_start_season()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_season uuid;
begin
  if not coalesce(private.safra_is_season_manager(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_SEASON_FORBIDDEN';
  end if;
  if exists (select 1 from public.safra_seasons where ended_at is null) then
    raise exception using errcode = 'P0001', message = 'SAFRA_SEASON_ALREADY_OPEN';
  end if;

  insert into public.safra_seasons(started_at, started_by) values (clock_timestamp(), v_actor) returning id into v_season;
  insert into public.safra_season_events(season_id, event_type, actor_user_id, note)
  values (v_season, 'STARTED', v_actor, 'D-119: nova Safra iniciada pelo owner.');
  return public.safra_get_season();
end;
$$;

revoke all on function public.safra_get_season() from public, anon;
revoke all on function public.safra_end_season(text) from public, anon;
revoke all on function public.safra_undo_end_season() from public, anon;
revoke all on function public.safra_start_season() from public, anon;
grant execute on function public.safra_get_season() to authenticated, service_role;
grant execute on function public.safra_end_season(text) to authenticated, service_role;
grant execute on function public.safra_undo_end_season() to authenticated, service_role;
grant execute on function public.safra_start_season() to authenticated, service_role;

-- 4. Abertura de protocolo respeita a Safra (D-118) --------------------------------------
create or replace function public.safra_start_treatment(
  p_scenario_id uuid,
  p_idempotency_key uuid,
  p_impact_summary text default null,
  p_impacted_area_ids uuid[] default '{}'::uuid[],
  p_problem_started_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_idempotency_key text := p_idempotency_key::text;
  v_impact_summary text := nullif(btrim(coalesce(p_impact_summary,'')),'');
  v_requested_areas uuid[];
  v_existing_areas uuid[];
  v_existing public.treatments%rowtype;
  v_treatment public.treatments%rowtype;
  v_scenario_version_id uuid;
  v_scenario_code text;
  v_owner_id uuid;
  v_responsible_area_id uuid;
  v_active_treatment_id uuid;
  v_owner_user_id uuid;
  v_next_seq integer;
  v_card text;
  v_now timestamptz := clock_timestamp();
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null
     or not coalesce(public.safra_is_corporate_user(),false)
  then
    raise exception using errcode='42501', message='SAFRA_START_FORBIDDEN';
  end if;

  -- D-118: com a Safra encerrada, ninguém abre protocolo novo até a próxima começar.
  if not exists (select 1 from public.safra_seasons s where s.ended_at is null) then
    raise exception using errcode = 'P0001', message = 'SAFRA_SEASON_CLOSED';
  end if;

  if v_impact_summary is not null and length(v_impact_summary) > 2000 then
    raise exception using errcode='22023', message='SAFRA_IMPACT_SUMMARY_TOO_LONG';
  end if;

  -- D-89: o início informado não pode estar no futuro (5 min de tolerância
  -- para relógio do computador adiantado; dentro dela vale o horário do servidor).
  if p_problem_started_at is not null and p_problem_started_at > v_now + interval '5 minutes' then
    raise exception using errcode='22023', message='SAFRA_PROBLEM_START_IN_FUTURE';
  end if;

  if exists(
    select 1
    from unnest(coalesce(p_impacted_area_ids,'{}'::uuid[])) area_id
    where area_id is null
  ) then
    raise exception using errcode='22023', message='SAFRA_INVALID_IMPACTED_AREA';
  end if;

  select coalesce(array_agg(area_id order by area_id),'{}'::uuid[])
    into v_requested_areas
  from (
    select distinct area_id
    from unnest(coalesce(p_impacted_area_ids,'{}'::uuid[])) area_id
  ) q;

  perform pg_advisory_xact_lock(hashtextextended(v_idempotency_key,0));

  select *
    into v_existing
  from public.treatments t
  where t.start_idempotency_key=v_idempotency_key;

  if found then
    select coalesce(array_agg(tia.operational_area_id order by tia.operational_area_id),'{}'::uuid[])
      into v_existing_areas
    from public.treatment_impacted_areas tia
    where tia.treatment_id=v_existing.id
      and tia.valid_to is null;

    if v_existing.opened_by is distinct from v_actor
       or v_existing.scenario_id is distinct from p_scenario_id
       or v_existing.impact_summary is distinct from v_impact_summary
       or v_existing_areas is distinct from v_requested_areas
       or (p_problem_started_at is not null
           and p_problem_started_at <= v_existing.opened_at
           and v_existing.problem_started_at is distinct from p_problem_started_at)
    then
      raise exception using errcode='22023', message='SAFRA_START_IDEMPOTENCY_CONFLICT';
    end if;

    return private.safra_start_treatment_snapshot_json(v_existing.id,clock_timestamp())
      || jsonb_build_object('idempotent_replay',true);
  end if;

  select
    sv.id,
    sc.code,
    sc.responsible_area_id
    into
      v_scenario_version_id,
      v_scenario_code,
      v_responsible_area_id
  from public.scenarios sc
  join public.scenario_versions sv
    on sv.id=sc.current_version_id
   and sv.scenario_id=sc.id
  where sc.id=p_scenario_id
    and sc.lifecycle_status='ACTIVE'
    and sv.status='PUBLISHED'
    and sc.responsible_area_id is not null
  for update of sc;

  if not found then
    raise exception using errcode='P0001', message='SAFRA_SCENARIO_NOT_STARTABLE';
  end if;

  -- D-78: card bloqueado enquanto o dono vigente estiver desativado ou sem papel.
  select so.owner_id, owner_p.user_id
    into v_owner_id, v_owner_user_id
  from public.scenario_owners so
  join private.safra_principals owner_p on owner_p.id=so.owner_id
  where so.scenario_id=p_scenario_id
    and so.valid_to is null
    and private.safra_owner_is_available(so.owner_id);

  if not found then
    raise exception using errcode='P0001', message='SAFRA_SCENARIO_OWNER_UNAVAILABLE';
  end if;

  if exists(
    select 1
    from unnest(v_requested_areas) requested(area_id)
    where not exists(
      select 1
      from public.scenario_version_impacted_areas svia
      where svia.scenario_version_id=v_scenario_version_id
        and svia.operational_area_id=requested.area_id
    )
  ) then
    raise exception using errcode='22023', message='SAFRA_INVALID_IMPACTED_AREA';
  end if;

  -- D-65: the current owner of a card does not open protocols of that card.
  if v_owner_user_id is not distinct from v_actor then
    raise exception using errcode='P0001', message='SAFRA_START_OWNER_OWN_CARD';
  end if;

  -- D-57/D-66: one protocol per person and card while the requester part is open.
  -- The scenario row lock above serializes STARTs of this scenario.
  select t.id
    into v_active_treatment_id
  from public.treatments t
  where t.scenario_id=p_scenario_id
    and t.opened_by=v_actor
    and t.status='ACTIVE'
    and t.requester_closed_at is null
  limit 1;

  if found then
    raise exception using
      errcode='P0001',
      message='SAFRA_START_ACTIVE_EXISTS',
      detail=v_active_treatment_id::text;
  end if;

  -- D-83: the requester explains the problem to guide the card owner.
  if v_impact_summary is null or length(v_impact_summary) < 10 then
    raise exception using errcode='22023', message='SAFRA_IMPACT_SUMMARY_REQUIRED';
  end if;

  -- D-82: card number + per-card sequence; the scenario row lock serializes it.
  select coalesce(max(t.protocol_seq), 0) + 1
    into v_next_seq
  from public.treatments t
  where t.scenario_id = p_scenario_id;

  v_card := coalesce(substring(v_scenario_code from '^SAFRA-([0-9]+)$'), v_scenario_code);

  insert into public.treatments(
    scenario_id,
    scenario_version_id,
    status,
    opened_by,
    owner_id_at_start,
    responsible_area_id_at_start,
    impact_summary,
    start_correlation_id,
    start_idempotency_key,
    protocol_seq,
    protocol_number,
    problem_started_at
  )
  values(
    p_scenario_id,
    v_scenario_version_id,
    'ACTIVE',
    v_actor,
    v_owner_id,
    v_responsible_area_id,
    v_impact_summary,
    v_correlation_id,
    v_idempotency_key,
    v_next_seq,
    v_card || '-' || lpad(v_next_seq::text, 4, '0'),
    least(coalesce(p_problem_started_at, v_now), v_now)
  )
  returning * into v_treatment;

  insert into public.treatment_impacted_areas(
    treatment_id,
    operational_area_id,
    added_by
  )
  select
    v_treatment.id,
    area_id,
    v_actor
  from unnest(v_requested_areas) area_id;

  insert into public.treatment_events(
    treatment_id,
    event_type,
    actor_user_id,
    correlation_id,
    idempotency_key,
    payload
  )
  values(
    v_treatment.id,
    'TREATMENT_OPENED',
    v_actor,
    v_correlation_id,
    v_idempotency_key,
    jsonb_build_object(
      'source','SAFRA_C08_START',
      'scenario_version_id',v_scenario_version_id,
      'protocol_number',v_treatment.protocol_number
    )
  );

  return private.safra_start_treatment_snapshot_json(v_treatment.id,clock_timestamp())
    || jsonb_build_object('idempotent_replay',false);
end;
$$;

revoke all on function public.safra_start_treatment(uuid, uuid, text, uuid[], timestamptz) from public, anon;
grant execute on function public.safra_start_treatment(uuid, uuid, text, uuid[], timestamptz) to authenticated, service_role;

-- 5. GI-SAFRA-006 resolvida (só onde o login do owner existe) ----------------------------
do $$
declare
  v_owner uuid;
begin
  select u.id into v_owner from auth.users u where lower(u.email) = 'kaue.pastrello@editoradobrasil.com.br';
  if v_owner is not null then
    update public.governance_issues
       set status = 'RESOLVED', resolved_by = v_owner,
           resolution_text = 'D-59/D-118/D-119 (02/10/2026): marcação da Safra construída; só o Kaue inicia e encerra, encerrar exige "ENCERRAR SAFRA" e pode ser desfeito em 7 dias (D-70); com a Safra encerrada ninguém abre protocolo novo.'
     where issue_key = 'GI-SAFRA-006' and status = 'OPEN';
  end if;
end;
$$;

commit;
