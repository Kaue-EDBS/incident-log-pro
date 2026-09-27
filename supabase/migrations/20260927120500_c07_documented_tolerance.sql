-- SAFRA-C07.6 — tolerancia temporal somente quando documentada
-- Sem tolerancia: tripla NULL e comportamento identico ao baseline.
-- Com tolerancia: valor > 0, unidade suportada e documentacao obrigatoria.

begin;

alter table public.scenario_slas
  add column tolerance_value numeric null,
  add column tolerance_unit text null,
  add column tolerance_documentation text null;

alter table public.scenario_slas
  add constraint scenario_slas_tolerance_complete
  check (
    (
      tolerance_value is null
      and tolerance_unit is null
      and tolerance_documentation is null
    )
    or
    (
      tolerance_value is not null
      and tolerance_value > 0
      and tolerance_unit is not null
      and upper(btrim(tolerance_unit)) = any (array['MINUTE'::text,'HOUR'::text,'DAY'::text])
      and tolerance_documentation is not null
      and btrim(tolerance_documentation) <> ''
    )
  );

comment on column public.scenario_slas.tolerance_value is
  'Tolerancia temporal opcional do SLA. NULL significa tolerancia zero. Quando presente deve ser > 0 e ter unidade/documentacao completas.';

comment on column public.scenario_slas.tolerance_unit is
  'Unidade da tolerancia temporal opcional. Valores persistidos suportados: MINUTE, HOUR e DAY.';

comment on column public.scenario_slas.tolerance_documentation is
  'Justificativa/documentacao obrigatoria para qualquer tolerancia temporal positiva. Tolerancia silenciosa e proibida.';

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
    when 'SECOND' then return p_value::double precision * interval '1 second';
    when 'MINUTE' then return p_value::double precision * interval '1 minute';
    when 'HOUR'   then return p_value::double precision * interval '1 hour';
    when 'DAY'    then return p_value::double precision * interval '1 day';
    else
      raise exception using errcode='22023',
        message=format('Unsupported SLA target unit: %s', p_unit);
  end case;
end;
$$;

comment on function private.safra_sla_target_interval(numeric,text) is
  'Converte alvo temporal em interval. SECOND existe apenas para composicao interna da engine; scenario_slas persiste MINUTE/HOUR/DAY.';

create or replace function private.safra_evaluate_configured_sla(
  p_end_event text,
  p_started_at timestamptz,
  p_ended_at timestamptz,
  p_cancelled_at timestamptz,
  p_as_of timestamptz,
  p_target_value numeric,
  p_target_unit text,
  p_tolerance_value numeric,
  p_tolerance_unit text,
  p_tolerance_documentation text,
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
  v_effective_target_seconds numeric;
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

  if p_tolerance_value is null
     and p_tolerance_unit is null
     and p_tolerance_documentation is null then
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
    return;
  end if;

  if p_tolerance_value is null
     or p_tolerance_unit is null
     or p_tolerance_documentation is null
     or p_tolerance_value <= 0
     or btrim(p_tolerance_documentation) = ''
     or upper(btrim(p_tolerance_unit)) <> all (array['MINUTE'::text,'HOUR'::text,'DAY'::text]) then
    return query select
      'NOT_MEASURABLE'::text,
      'TOLERANCE_CONFIGURATION_INVALID'::text,
      null::timestamptz,
      null::numeric,
      null::numeric,
      null::timestamptz;
    return;
  end if;

  if p_target_value is null or p_target_unit is null then
    return query select
      'NOT_MEASURABLE'::text,
      'STRUCTURED_TARGET_MISSING'::text,
      null::timestamptz,
      null::numeric,
      null::numeric,
      null::timestamptz;
    return;
  end if;

  v_effective_target_seconds :=
    extract(epoch from private.safra_sla_target_interval(p_target_value,p_target_unit))
    +
    extract(epoch from private.safra_sla_target_interval(p_tolerance_value,p_tolerance_unit));

  return query
  select *
  from private.safra_evaluate_sla(
    p_started_at,
    p_ended_at,
    p_cancelled_at,
    p_as_of,
    v_effective_target_seconds,
    'SECOND',
    p_not_applicable
  );
end;
$$;

comment on function private.safra_evaluate_configured_sla(
  text,timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,numeric,text,text,boolean
) is
  'C07.6 configured SLA evaluator with optional documented tolerance. Tolerance extends only the effective deadline and is invalid unless value, unit and documentation are complete.';

revoke all on function private.safra_evaluate_configured_sla(
  text,timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,numeric,text,text,boolean
) from public, anon, authenticated;

grant execute on function private.safra_evaluate_configured_sla(
  text,timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,numeric,text,text,boolean
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
    sl.tolerance_value,
    sl.tolerance_unit,
    sl.tolerance_documentation,
    false
  ) e
  where t.id=p_treatment_id;
$$;

comment on function private.safra_treatment_sla_state(uuid,timestamptz) is
  'C07 treatment SLA state. Applies documented tolerance from scenario_slas when configured; NULL tolerance means zero tolerance.';

revoke all on function private.safra_treatment_sla_state(uuid,timestamptz)
  from public, anon, authenticated;

grant execute on function private.safra_treatment_sla_state(uuid,timestamptz)
  to service_role;

commit;
