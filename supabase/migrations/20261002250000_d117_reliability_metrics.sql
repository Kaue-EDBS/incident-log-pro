-- D-117 (02/10/2026) — MTTD, MTTR, MTBF e MTTF dos protocolos da Safra (analytics, D-88).
--
-- Falha = protocolo ENCERRADO (cancelados e os fora do analytics, D-115, não entram).
-- Protocolos do mesmo card que se sobrepõem no tempo contam como UMA falha (episódio).
--   MTTD = abertura do episódio - início do problema mais cedo informado nele (D-89)
--   MTTR = fim do episódio - abertura do episódio (o dono só sabe quando o protocolo abre)
--          fim de um protocolo = a última parte que concluiu; no encerramento automático
--          (D-113), a parte que concluiu
--   MTTF = abertura da falha - fim da falha anterior do mesmo card
--   MTBF = abertura da falha - abertura da falha anterior do mesmo card (= MTTF + MTTR)
-- Período: Safra corrente (D-69: começou em 01/10/2026; termina quando o Kaue marcar).
-- Média e mediana, em segundos. Quem vê (D-88): dono de card os seus cards; Jair, Bruno e
-- platform admins todos os cards e o consolidado.
begin;

-- Início da Safra corrente (muda por migration quando a marcação da D-59 existir).
create or replace function private.safra_current_season_start()
returns timestamptz
language sql
immutable
set search_path = ''
as $$ select timestamptz '2026-10-01 00:00:00-03' $$;

revoke all on function private.safra_current_season_start() from public, anon, authenticated;

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

-- Quem vê (D-88). p_owner_principal_id: só o Modo Camaleão (D-96) pede os cards de outro dono.
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

  return private.safra_reliability_metrics_json(v_cards) || jsonb_build_object('scope', v_scope);
end;
$$;

revoke all on function public.safra_get_reliability_metrics(uuid) from public, anon;
grant execute on function public.safra_get_reliability_metrics(uuid) to authenticated, service_role;

comment on function public.safra_get_reliability_metrics(uuid) is
  'D-117: MTTD, MTTR, MTBF and MTTF (mean and median, seconds) of the current Safra. Owners see their cards; governance and platform admins see all cards and the consolidated row (D-88).';

commit;
