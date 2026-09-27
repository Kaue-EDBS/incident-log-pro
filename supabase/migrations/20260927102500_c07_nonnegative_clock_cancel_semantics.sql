-- SAFRA-C07 — relógio não-negativo e semântica de CANCEL
-- Regra aprovada: remaining_seconds nunca fica negativo.
-- CANCEL nunca representa SLA cumprido.

begin;

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
        greatest(0::numeric, extract(epoch from (v_deadline-v_effective_at))::numeric),
        v_deadline;
    else
      return query select 'NOT_MEASURABLE'::text,'TREATMENT_CANCELLED_BEFORE_END_EVENT'::text,
        v_deadline,
        extract(epoch from (v_effective_at-p_started_at))::numeric,
        greatest(0::numeric, extract(epoch from (v_deadline-v_effective_at))::numeric),
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
        greatest(0::numeric, extract(epoch from (v_deadline-v_effective_at))::numeric),
        null::timestamptz;
    else
      return query select 'COMPLETED_LATE'::text,'END_EVENT_AFTER_DEADLINE'::text,
        v_deadline,
        extract(epoch from (v_effective_at-p_started_at))::numeric,
        0::numeric,
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
      0::numeric,
      v_deadline;
  else
    return query select 'ON_TRACK'::text,'DEADLINE_NOT_EXCEEDED'::text,
      v_deadline,
      extract(epoch from (v_effective_at-p_started_at))::numeric,
      greatest(0::numeric, extract(epoch from (v_deadline-v_effective_at))::numeric),
      null::timestamptz;
  end if;
end;
$$;

comment on function private.safra_evaluate_sla(
  timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean
) is
  'C07 deterministic SLA evaluator. elapsed_seconds and remaining_seconds never represent negative clock values; CANCEL never returns COMPLETED_* states.';

revoke all on function private.safra_evaluate_sla(
  timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean
) from public, anon, authenticated;

grant execute on function private.safra_evaluate_sla(
  timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean
) to service_role;

commit;
