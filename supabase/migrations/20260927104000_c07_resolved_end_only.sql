-- SAFRA-C07 — END fecha SLA somente com end_event=TREATMENT_RESOLVED
-- Defesa em profundidade: contrato no schema + wrapper da engine configurada.

begin;

alter table public.scenario_slas
  add constraint scenario_slas_end_event_resolved_only
  check (upper(btrim(end_event)) = 'TREATMENT_RESOLVED');

create or replace function private.safra_evaluate_configured_sla(
  p_end_event text,
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
begin
  if upper(btrim(coalesce(p_end_event,''))) <> 'TREATMENT_RESOLVED' then
    return query select
      'NOT_MEASURABLE'::text,
      'END_EVENT_NOT_TREATMENT_RESOLVED'::text,
      null::timestamptz,
      null::numeric,
      null::numeric,
      null::timestamptz;
    return;
  end if;

  return query
  select *
  from private.safra_evaluate_sla(
    p_started_at,
    p_ended_at,
    p_cancelled_at,
    p_as_of,
    p_target_value,
    p_target_unit,
    p_not_applicable
  );
end;
$$;

comment on function private.safra_evaluate_configured_sla(
  text,timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean
) is
  'C07 configured SLA gate. COMPLETED_* is reachable only when end_event normalizes to TREATMENT_RESOLVED.';

revoke all on function private.safra_evaluate_configured_sla(
  text,timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean
) from public, anon, authenticated;

grant execute on function private.safra_evaluate_configured_sla(
  text,timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean
) to service_role;

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
    t.id,
    sl.id,
    sl.code,
    sl.label,
    e.sla_state,
    e.evaluation_reason,
    times.started_at,
    times.ended_at,
    e.deadline_at,
    e.elapsed_seconds,
    e.remaining_seconds,
    e.breached_at,
    sl.target_text
  from public.treatments t
  join public.scenario_slas sl
    on sl.scenario_version_id=t.scenario_version_id
  cross join lateral (
    select
      private.safra_treatment_event_time(t.id,sl.start_event) as started_at,
      private.safra_treatment_event_time(t.id,sl.end_event) as ended_at
  ) times
  cross join lateral private.safra_evaluate_configured_sla(
    sl.end_event,
    times.started_at,
    times.ended_at,
    t.cancelled_at,
    p_as_of,
    sl.target_value,
    sl.target_unit,
    false
  ) e
  where t.id=p_treatment_id;
$$;

comment on function private.safra_treatment_sla_state(uuid,timestamptz) is
  'C07 treatment SLA state. Uses configured-SLA gate so only TREATMENT_RESOLVED can close an SLA as COMPLETED_*.';

revoke all on function private.safra_treatment_sla_state(uuid,timestamptz)
  from public, anon, authenticated;

grant execute on function private.safra_treatment_sla_state(uuid,timestamptz)
  to service_role;

commit;
