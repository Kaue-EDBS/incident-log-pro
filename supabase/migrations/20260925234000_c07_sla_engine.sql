-- SAFRA-C07 — Engine de SLA determinística e privada
-- Não publica SLAs de cenário; apenas cria a engine e invariantes técnicos.
-- A ligação de SLA textual -> start_event/end_event/target estruturado exige decisão/fonte explícita.

begin;

alter table public.scenario_slas
  add constraint scenario_slas_target_value_positive
  check (target_value is null or target_value > 0);

alter table public.scenario_slas
  add constraint scenario_slas_target_unit_supported
  check (
    target_unit is null
    or upper(btrim(target_unit)) = any (array['MINUTE'::text,'HOUR'::text,'DAY'::text])
  );

alter table public.scenario_slas
  add constraint scenario_slas_distinct_events
  check (btrim(start_event) <> btrim(end_event));

create or replace function private.safra_sla_target_interval(
  p_value numeric,
  p_unit text
)
returns interval
language plpgsql
immutable
strict
set search_path = ''
as $$
begin
  if p_value <= 0 then
    raise exception using errcode='22023', message='SLA target value must be greater than zero';
  end if;

  case upper(btrim(p_unit))
    when 'MINUTE' then return p_value::double precision * interval '1 minute';
    when 'HOUR'   then return p_value::double precision * interval '1 hour';
    when 'DAY'    then return p_value::double precision * interval '1 day';
    else
      raise exception using errcode='22023',
        message=format('Unsupported SLA target unit: %s', p_unit);
  end case;
end;
$$;

revoke all on function private.safra_sla_target_interval(numeric,text) from public, anon, authenticated;
grant execute on function private.safra_sla_target_interval(numeric,text) to service_role;

create or replace function private.safra_evaluate_sla(
  p_started_at timestamptz,
  p_ended_at timestamptz,
  p_cancelled_at timestamptz,
  p_as_of timestamptz,
  p_target_value numeric,
  p_target_unit text,
  p_not_applicable boolean default false
)
returns table(
  sla_state text,
  evaluation_reason text,
  deadline_at timestamptz,
  elapsed_seconds numeric,
  remaining_seconds numeric,
  breached_at timestamptz
)
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_deadline timestamptz;
  v_effective_at timestamptz;
begin
  if coalesce(p_not_applicable,false) then
    return query select 'NOT_APPLICABLE'::text,'EXPLICIT_RULE'::text,
      null::timestamptz,null::numeric,null::numeric,null::timestamptz;
    return;
  end if;

  if p_started_at is null then
    return query select 'NOT_MEASURABLE'::text,'START_EVENT_MISSING'::text,
      null::timestamptz,null::numeric,null::numeric,null::timestamptz;
    return;
  end if;

  if p_as_of is null then
    return query select 'NOT_MEASURABLE'::text,'AS_OF_MISSING'::text,
      null::timestamptz,null::numeric,null::numeric,null::timestamptz;
    return;
  end if;

  if p_target_value is null or p_target_unit is null then
    return query select 'NOT_MEASURABLE'::text,'STRUCTURED_TARGET_MISSING'::text,
      null::timestamptz,null::numeric,null::numeric,null::timestamptz;
    return;
  end if;

  v_deadline := p_started_at + private.safra_sla_target_interval(p_target_value,p_target_unit);

  if p_ended_at is not null and p_cancelled_at is not null then
    return query select 'NOT_MEASURABLE'::text,'CONFLICTING_TERMINAL_EVENTS'::text,
      v_deadline,null::numeric,null::numeric,null::timestamptz;
    return;
  end if;

  if p_ended_at is not null and p_ended_at < p_started_at then
    return query select 'NOT_MEASURABLE'::text,'END_BEFORE_START'::text,
      v_deadline,null::numeric,null::numeric,null::timestamptz;
    return;
  end if;

  if p_cancelled_at is not null and p_cancelled_at < p_started_at then
    return query select 'NOT_MEASURABLE'::text,'CANCEL_BEFORE_START'::text,
      v_deadline,null::numeric,null::numeric,null::timestamptz;
    return;
  end if;

  if p_cancelled_at is not null then
    v_effective_at := p_cancelled_at;
    if p_cancelled_at > v_deadline then
      return query select 'BREACHED'::text,'TREATMENT_CANCELLED_AFTER_BREACH'::text,
        v_deadline,
        extract(epoch from (v_effective_at-p_started_at))::numeric,
        extract(epoch from (v_deadline-v_effective_at))::numeric,
        v_deadline;
    else
      return query select 'NOT_MEASURABLE'::text,'TREATMENT_CANCELLED_BEFORE_END_EVENT'::text,
        v_deadline,
        extract(epoch from (v_effective_at-p_started_at))::numeric,
        extract(epoch from (v_deadline-v_effective_at))::numeric,
        null::timestamptz;
    end if;
    return;
  end if;

  if p_ended_at is not null then
    v_effective_at := p_ended_at;
    if p_ended_at <= v_deadline then
      return query select 'COMPLETED_ON_TIME'::text,'END_EVENT_OBSERVED'::text,
        v_deadline,
        extract(epoch from (v_effective_at-p_started_at))::numeric,
        extract(epoch from (v_deadline-v_effective_at))::numeric,
        null::timestamptz;
    else
      return query select 'COMPLETED_LATE'::text,'END_EVENT_AFTER_DEADLINE'::text,
        v_deadline,
        extract(epoch from (v_effective_at-p_started_at))::numeric,
        extract(epoch from (v_deadline-v_effective_at))::numeric,
        v_deadline;
    end if;
    return;
  end if;

  if p_as_of < p_started_at then
    return query select 'NOT_MEASURABLE'::text,'CLOCK_BEFORE_START'::text,
      v_deadline,null::numeric,null::numeric,null::timestamptz;
    return;
  end if;

  v_effective_at := p_as_of;

  if p_as_of > v_deadline then
    return query select 'BREACHED'::text,'DEADLINE_EXCEEDED'::text,
      v_deadline,
      extract(epoch from (v_effective_at-p_started_at))::numeric,
      extract(epoch from (v_deadline-v_effective_at))::numeric,
      v_deadline;
  else
    return query select 'ON_TRACK'::text,'DEADLINE_NOT_EXCEEDED'::text,
      v_deadline,
      extract(epoch from (v_effective_at-p_started_at))::numeric,
      extract(epoch from (v_deadline-v_effective_at))::numeric,
      null::timestamptz;
  end if;
end;
$$;

revoke all on function private.safra_evaluate_sla(timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean)
  from public, anon, authenticated;
grant execute on function private.safra_evaluate_sla(timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean)
  to service_role;

create or replace function private.safra_treatment_event_time(
  p_treatment_id uuid,
  p_event_type text
)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select case upper(btrim(p_event_type))
    when 'TREATMENT_OPENED' then t.opened_at
    when 'TREATMENT_RESOLVED' then case when t.status='RESOLVED' then t.closed_at end
    when 'TREATMENT_CANCELLED' then case when t.status='CANCELLED' then t.cancelled_at end
    else (
      select min(te.occurred_at)
      from public.treatment_events te
      where te.treatment_id=t.id
        and te.event_type=upper(btrim(p_event_type))
    )
  end
  from public.treatments t
  where t.id=p_treatment_id;
$$;

revoke all on function private.safra_treatment_event_time(uuid,text) from public, anon, authenticated;
grant execute on function private.safra_treatment_event_time(uuid,text) to service_role;

create or replace function private.safra_treatment_sla_state(
  p_treatment_id uuid,
  p_as_of timestamptz default clock_timestamp()
)
returns table(
  treatment_id uuid,
  sla_id uuid,
  sla_code text,
  sla_label text,
  sla_state text,
  evaluation_reason text,
  started_at timestamptz,
  ended_at timestamptz,
  deadline_at timestamptz,
  elapsed_seconds numeric,
  remaining_seconds numeric,
  breached_at timestamptz,
  target_text text
)
language sql
volatile
set search_path = ''
as $$
  select
    t.id,sl.id,sl.code,sl.label,
    e.sla_state,e.evaluation_reason,
    times.started_at,times.ended_at,
    e.deadline_at,e.elapsed_seconds,e.remaining_seconds,e.breached_at,
    sl.target_text
  from public.treatments t
  join public.scenario_slas sl on sl.scenario_version_id=t.scenario_version_id
  cross join lateral (
    select
      private.safra_treatment_event_time(t.id,sl.start_event) as started_at,
      private.safra_treatment_event_time(t.id,sl.end_event) as ended_at
  ) times
  cross join lateral private.safra_evaluate_sla(
    times.started_at,times.ended_at,t.cancelled_at,p_as_of,
    sl.target_value,sl.target_unit,false
  ) e
  where t.id=p_treatment_id;
$$;

revoke all on function private.safra_treatment_sla_state(uuid,timestamptz) from public, anon, authenticated;
grant execute on function private.safra_treatment_sla_state(uuid,timestamptz) to service_role;

commit;
