-- C07-AUD2 (01/10/2026)
--
-- 1. D-75: a engine de SLA é aposentada. Nenhum card usa SLA (D-62); a tabela
--    scenario_slas está vazia e nenhum evento SLA_BREACHED existe. Saem as funções
--    da engine, a tabela, o tipo de evento e as chaves de SLA do catálogo e do
--    resumo do START. O SLA textual da Matriz v3 continua em source_reference.
-- 2. D-76/D-77: regras de tempo da escada de avisos e dos tempos de encerramento,
--    como cálculos puros que recebem os horários (as colunas de cada parte chegam
--    na F01). Nada de duração gravada: tudo é derivado dos horários do servidor.
begin;

-- 1. Aposentar a engine de SLA ----------------------------------------------
do $$
begin
  if exists (select 1 from public.scenario_slas) then
    raise exception 'C07-AUD2: scenario_slas is not empty; retirement needs a new decision';
  end if;
  if exists (select 1 from public.treatment_events where event_type = 'SLA_BREACHED') then
    raise exception 'C07-AUD2: SLA_BREACHED events exist; retirement needs a new decision';
  end if;
end;
$$;

create or replace function private.safra_start_treatment_snapshot_json(
  p_treatment_id uuid,
  p_as_of timestamptz default clock_timestamp()
)
returns jsonb
language sql
set search_path = ''
as $$
  select jsonb_build_object(
    'treatment_id', t.id,
    'status', t.status,
    'opened_at', t.opened_at,
    'opened_by_user_id', t.opened_by,
    'start_correlation_id', t.start_correlation_id,
    'start_idempotency_key', t.start_idempotency_key,
    'impact_summary', t.impact_summary,
    'scenario', jsonb_build_object(
      'id', sc.id,
      'code', sc.code,
      'name', sc.name,
      'scenario_version_id', sv.id,
      'version_no', sv.version_no,
      'criticality', sv.criticality,
      'trigger_description', sv.trigger_description,
      'protocol_text', sv.protocol_text,
      'expected_impact_summary', sv.expected_impact_summary
    ),
    'owner', jsonb_build_object(
      'principal_id', owner_p.id,
      'display_name', owner_p.display_name,
      'corporate_email', owner_p.corporate_email
    ),
    'responsible_area', jsonb_build_object(
      'id', oa.id,
      'code', oa.code,
      'name', oa.name
    ),
    'impacted_areas', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', ia.id,
          'code', ia.code,
          'name', ia.name
        )
        order by ia.name
      )
      from public.treatment_impacted_areas tia
      join public.operational_areas ia on ia.id = tia.operational_area_id
      where tia.treatment_id = t.id
        and tia.valid_to is null
    ), '[]'::jsonb)
  )
  from public.treatments t
  join public.scenarios sc on sc.id = t.scenario_id
  join public.scenario_versions sv on sv.id = t.scenario_version_id
  join private.safra_principals owner_p on owner_p.id = t.owner_id_at_start
  join public.operational_areas oa on oa.id = t.responsible_area_id_at_start
  where t.id = p_treatment_id;
$$;

create or replace function public.safra_get_start_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if (select auth.uid()) is null
     or not coalesce(public.safra_is_corporate_user(), false)
  then
    raise exception using errcode = '42501', message = 'SAFRA_START_FORBIDDEN';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'scenario_id', sc.id,
        'code', sc.code,
        'name', sc.name,
        'scenario_version_id', sv.id,
        'version_no', sv.version_no,
        'criticality', sv.criticality,
        'trigger_description', sv.trigger_description,
        'protocol_text', sv.protocol_text,
        'expected_impact_summary', sv.expected_impact_summary,
        'responsible_area', jsonb_build_object(
          'id', oa.id,
          'code', oa.code,
          'name', oa.name
        ),
        'owner', jsonb_build_object(
          'principal_id', p.id,
          'display_name', p.display_name,
          'corporate_email', p.corporate_email
        ),
        'potential_impacted_areas', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', ia.id,
              'code', ia.code,
              'name', ia.name
            )
            order by ia.name
          )
          from public.scenario_version_impacted_areas svia
          join public.operational_areas ia on ia.id = svia.operational_area_id
          where svia.scenario_version_id = sv.id
        ), '[]'::jsonb),
        'active_treatment_count', (
          select count(*)::integer
          from public.treatments t
          where t.scenario_id = sc.id
            and t.status = 'ACTIVE'
        )
      )
      order by sc.code
    ),
    '[]'::jsonb
  )
  into v_result
  from public.scenarios sc
  join public.scenario_versions sv
    on sv.id = sc.current_version_id
   and sv.scenario_id = sc.id
   and sv.status = 'PUBLISHED'
  join public.scenario_owners so
    on so.scenario_id = sc.id
   and so.valid_to is null
  join private.safra_principals p
    on p.id = so.owner_id
   and p.is_active
  join public.operational_areas oa
    on oa.id = sc.responsible_area_id
  where sc.lifecycle_status = 'ACTIVE';

  return v_result;
end;
$$;

drop function if exists private.safra_treatment_sla_state(uuid, timestamptz);
drop function if exists private.safra_treatment_event_time(uuid, text);
drop function if exists private.safra_evaluate_configured_sla(text, timestamptz, timestamptz, timestamptz, timestamptz, numeric, text, numeric, text, text, boolean);
drop function if exists private.safra_evaluate_configured_sla(text, timestamptz, timestamptz, timestamptz, timestamptz, numeric, text, boolean);
drop function if exists private.safra_evaluate_sla(timestamptz, timestamptz, timestamptz, timestamptz, numeric, text, boolean);
drop function if exists private.safra_sla_target_interval(numeric, text);

drop table public.scenario_slas;

alter table public.treatment_events drop constraint treatment_events_type_check;
alter table public.treatment_events
  add constraint treatment_events_type_check
  check (event_type = any (array[
    'TREATMENT_OPENED'::text,
    'NOTE_ADDED'::text,
    'IMPACT_AREA_ADDED'::text,
    'IMPACT_AREA_REMOVED'::text,
    'TREATMENT_RESOLVED'::text,
    'TREATMENT_CANCELLED'::text,
    'ADMIN_CORRECTION_RECORDED'::text
  ]));

-- 2. Regras de tempo (D-76, D-77) -------------------------------------------

-- Escada de avisos (D-76): aos 2h, aos 4h e depois de hora em hora (5h, 6h, ...)
-- desde a abertura, enquanto o solicitante não fechar a parte dele e o protocolo
-- não for cancelado. O solicitante sempre recebe "foi resolvido?"; o dono recebe o
-- pedido de cobrança só enquanto não fechou a parte dele.
-- Bordas: o aviso vale no instante exato (due_at <= as_of); fechar ou cancelar no
-- instante exato do aviso impede esse aviso. Tempo corrido, em horas absolutas.
create or replace function private.safra_reminder_steps(
  p_opened_at timestamptz,
  p_requester_closed_at timestamptz,
  p_owner_closed_at timestamptz,
  p_cancelled_at timestamptz,
  p_as_of timestamptz
)
returns table(step_no integer, hours_after_open integer, due_at timestamptz, notify_requester boolean, notify_owner boolean)
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_limit timestamptz;
  v_max_hours integer;
begin
  if p_opened_at is null or p_as_of is null then
    raise exception using errcode = '22023', message = 'SAFRA_TIME_REQUIRED';
  end if;
  if p_as_of < p_opened_at
     or p_requester_closed_at < p_opened_at
     or p_owner_closed_at < p_opened_at
     or p_cancelled_at < p_opened_at then
    raise exception using errcode = '22023', message = 'SAFRA_TIME_NEGATIVE';
  end if;

  v_limit := least(p_as_of, p_requester_closed_at, p_cancelled_at);
  v_max_hours := floor(extract(epoch from (v_limit - p_opened_at)) / 3600)::integer;
  if v_max_hours < 2 then
    return;
  end if;

  return query
  select
    (row_number() over (order by h))::integer,
    h,
    p_opened_at + make_interval(hours => h),
    true,
    (p_owner_closed_at is null or p_owner_closed_at > p_opened_at + make_interval(hours => h))
  from generate_series(2, v_max_hours) as h
  where h <> 3
    and p_opened_at + make_interval(hours => h) <= p_as_of
    and (p_requester_closed_at is null or p_requester_closed_at > p_opened_at + make_interval(hours => h))
    and (p_cancelled_at is null or p_cancelled_at > p_opened_at + make_interval(hours => h))
  order by h;
end;
$$;

-- Tempos de encerramento (D-77): solicitante, dono e consolidado (até a última
-- parte fechada). Cancelado não conta como resolvido: sem tempos. Parte ainda
-- aberta: tempo daquela parte e consolidado ficam vazios (em aberto), nunca zero.
create or replace function private.safra_close_times(
  p_opened_at timestamptz,
  p_requester_closed_at timestamptz,
  p_owner_closed_at timestamptz,
  p_cancelled_at timestamptz
)
returns table(measurement_status text, requester_time interval, owner_time interval, consolidated_time interval)
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_opened_at is null then
    raise exception using errcode = '22023', message = 'SAFRA_TIME_REQUIRED';
  end if;
  if p_requester_closed_at < p_opened_at
     or p_owner_closed_at < p_opened_at
     or p_cancelled_at < p_opened_at then
    raise exception using errcode = '22023', message = 'SAFRA_TIME_NEGATIVE';
  end if;

  if p_cancelled_at is not null then
    return query select 'CANCELLED'::text, null::interval, null::interval, null::interval;
    return;
  end if;

  return query select
    case when p_requester_closed_at is not null and p_owner_closed_at is not null
         then 'CLOSED' else 'IN_PROGRESS' end,
    p_requester_closed_at - p_opened_at,
    p_owner_closed_at - p_opened_at,
    case when p_requester_closed_at is not null and p_owner_closed_at is not null
         then greatest(p_requester_closed_at, p_owner_closed_at) - p_opened_at end;
end;
$$;

-- Dia do analytics no fuso oficial (C07, Regra 2).
create or replace function private.safra_local_day(p_at timestamptz)
returns date
language sql
immutable
set search_path = ''
as $$
  select (p_at at time zone 'America/Sao_Paulo')::date;
$$;

revoke all on function private.safra_reminder_steps(timestamptz, timestamptz, timestamptz, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function private.safra_close_times(timestamptz, timestamptz, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function private.safra_local_day(timestamptz) from public, anon, authenticated;

-- 3. Texto da GI-SAFRA-009 com a escada da D-76 -----------------------------
create or replace function private.safra_c01_aud2_resolve_governance_issues(p_actor uuid)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_count integer;
begin
  if p_actor is null then
    raise exception 'C01-AUD2: resolving actor is required';
  end if;

  update public.governance_issues gi
  set status = 'RESOLVED',
      resolved_by = p_actor,
      resolution_text = r.resolution_text
  from (values
    ('GI-SAFRA-001', 'D-55 (30/09/2026): os 11 cenários são CRITICAL; aviso de abertura ao dono do card, diretoria fora por ora. Aplicado na scenario_version v2 (migration 20261001120000).'),
    ('GI-SAFRA-004', 'D-57 (30/09/2026): no máximo uma tratativa ACTIVE por pessoa e por cenário. Aplicado por índice único e verificação no START (migration 20261001120000).'),
    ('GI-SAFRA-008', 'D-61 (30/09/2026): dia, horário e ritual da governança semanal ficam fora do Painel; a F05 mantém tela de resumo e registro de ações.'),
    ('GI-SAFRA-009', 'D-62 (01/10/2026): nenhum card terá cronômetro de SLA; engine aposentada (D-75). Escada de avisos (D-67, revista pela D-76): aos 2h, aos 4h e depois de hora em hora, enquanto o solicitante não fechar a parte dele; o dono deixa de receber quando fecha a parte dele; 24h por dia; implementação na M05/F01.'),
    ('GI-SAFRA-010', 'D-63 (01/10/2026): os 11 cenários publicados seguem liberados para qualquer usuário corporativo autenticado; sem restrição por card.')
  ) as r(issue_key, resolution_text)
  where gi.issue_key = r.issue_key
    and gi.status = 'OPEN';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function private.safra_c01_aud2_resolve_governance_issues(uuid) from public, anon, authenticated;

update public.governance_issues
set resolution_text = 'D-62 (01/10/2026): nenhum card terá cronômetro de SLA; engine aposentada (D-75). Escada de avisos (D-67, revista pela D-76): aos 2h, aos 4h e depois de hora em hora, enquanto o solicitante não fechar a parte dele; o dono deixa de receber quando fecha a parte dele; 24h por dia; implementação na M05/F01.'
where issue_key = 'GI-SAFRA-009'
  and status = 'RESOLVED';

-- Conferência ----------------------------------------------------------------
do $$
begin
  if to_regclass('public.scenario_slas') is not null then
    raise exception 'C07-AUD2: scenario_slas still exists';
  end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname in ('public', 'private')
               and p.proname in ('safra_evaluate_sla', 'safra_evaluate_configured_sla', 'safra_treatment_sla_state',
                                 'safra_sla_target_interval', 'safra_treatment_event_time')) then
    raise exception 'C07-AUD2: SLA engine functions still exist';
  end if;
  if (select count(*) from private.safra_reminder_steps(
        '2026-10-01 08:00+00', null, null, null, '2026-10-01 14:00+00')) <> 4 then
    raise exception 'C07-AUD2: reminder ladder self-check failed (expected 2h, 4h, 5h, 6h)';
  end if;
end;
$$;

commit;
