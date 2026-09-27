-- SAFRA-C08 — START end-to-end governado
-- Catalogo de cenarios + comando START transacional/idempotente.
-- Browser continua sem acesso direto às tabelas Safra.

begin;

create or replace function private.safra_start_treatment_snapshot_json(
  p_treatment_id uuid,
  p_as_of timestamptz default clock_timestamp()
)
returns jsonb
language sql
volatile
security invoker
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
      join public.operational_areas ia on ia.id=tia.operational_area_id
      where tia.treatment_id=t.id
        and tia.valid_to is null
    ), '[]'::jsonb),
    'slas', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'sla_id', s.sla_id,
          'code', s.sla_code,
          'label', s.sla_label,
          'state', s.sla_state,
          'reason', s.evaluation_reason,
          'started_at', s.started_at,
          'ended_at', s.ended_at,
          'deadline_at', s.deadline_at,
          'elapsed_seconds', s.elapsed_seconds,
          'remaining_seconds', s.remaining_seconds,
          'breached_at', s.breached_at,
          'target_text', s.target_text
        )
        order by s.sla_code
      )
      from private.safra_treatment_sla_state(t.id,p_as_of) s
    ), '[]'::jsonb)
  )
  from public.treatments t
  join public.scenarios sc on sc.id=t.scenario_id
  join public.scenario_versions sv on sv.id=t.scenario_version_id
  join private.safra_principals owner_p on owner_p.id=t.owner_id_at_start
  join public.operational_areas oa on oa.id=t.responsible_area_id_at_start
  where t.id=p_treatment_id;
$$;

revoke all on function private.safra_start_treatment_snapshot_json(uuid,timestamptz)
from public, anon, authenticated;
grant execute on function private.safra_start_treatment_snapshot_json(uuid,timestamptz)
to service_role;

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
     or not coalesce(public.safra_is_corporate_user(),false)
  then
    raise exception using errcode='42501', message='SAFRA_START_FORBIDDEN';
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
          join public.operational_areas ia on ia.id=svia.operational_area_id
          where svia.scenario_version_id=sv.id
        ), '[]'::jsonb),
        'structured_sla_count', (
          select count(*)::integer
          from public.scenario_slas sl
          where sl.scenario_version_id=sv.id
        ),
        'active_treatment_count', (
          select count(*)::integer
          from public.treatments t
          where t.scenario_id=sc.id
            and t.status='ACTIVE'
        )
      )
      order by sc.code
    ),
    '[]'::jsonb
  )
  into v_result
  from public.scenarios sc
  join public.scenario_versions sv
    on sv.id=sc.current_version_id
   and sv.scenario_id=sc.id
   and sv.status='PUBLISHED'
  join public.scenario_owners so
    on so.scenario_id=sc.id
   and so.valid_to is null
  join private.safra_principals p
    on p.id=so.owner_id
   and p.is_active
  join public.operational_areas oa
    on oa.id=sc.responsible_area_id
  where sc.lifecycle_status='ACTIVE';

  return v_result;
end;
$$;

revoke all on function public.safra_get_start_catalog()
from public, anon;
grant execute on function public.safra_get_start_catalog()
to authenticated, service_role;

comment on function public.safra_get_start_catalog() is
  'C08 governed START catalog. Intentional SECURITY DEFINER endpoint: validates corporate live session and exposes only START context; underlying Safra tables remain denied to browser roles.';

create or replace function public.safra_start_treatment(
  p_scenario_id uuid,
  p_idempotency_key uuid,
  p_impact_summary text default null,
  p_impacted_area_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
volatile
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
  v_owner_id uuid;
  v_responsible_area_id uuid;
  v_correlation_id uuid := gen_random_uuid();
begin
  if v_actor is null
     or not coalesce(public.safra_is_corporate_user(),false)
  then
    raise exception using errcode='42501', message='SAFRA_START_FORBIDDEN';
  end if;

  if v_impact_summary is not null and length(v_impact_summary) > 2000 then
    raise exception using errcode='22023', message='SAFRA_IMPACT_SUMMARY_TOO_LONG';
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
    then
      raise exception using errcode='22023', message='SAFRA_START_IDEMPOTENCY_CONFLICT';
    end if;

    return private.safra_start_treatment_snapshot_json(v_existing.id,clock_timestamp())
      || jsonb_build_object('idempotent_replay',true);
  end if;

  select
    sv.id,
    so.owner_id,
    sc.responsible_area_id
    into
      v_scenario_version_id,
      v_owner_id,
      v_responsible_area_id
  from public.scenarios sc
  join public.scenario_versions sv
    on sv.id=sc.current_version_id
   and sv.scenario_id=sc.id
  join public.scenario_owners so
    on so.scenario_id=sc.id
   and so.valid_to is null
  join private.safra_principals owner_p
    on owner_p.id=so.owner_id
   and owner_p.is_active
  where sc.id=p_scenario_id
    and sc.lifecycle_status='ACTIVE'
    and sv.status='PUBLISHED'
    and sc.responsible_area_id is not null
  for update of sc;

  if not found then
    raise exception using errcode='P0001', message='SAFRA_SCENARIO_NOT_STARTABLE';
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

  insert into public.treatments(
    scenario_id,
    scenario_version_id,
    status,
    opened_by,
    owner_id_at_start,
    responsible_area_id_at_start,
    impact_summary,
    start_correlation_id,
    start_idempotency_key
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
    v_idempotency_key
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
      'scenario_version_id',v_scenario_version_id
    )
  );

  return private.safra_start_treatment_snapshot_json(v_treatment.id,clock_timestamp())
    || jsonb_build_object('idempotent_replay',false);
end;
$$;

revoke all on function public.safra_start_treatment(uuid,uuid,text,uuid[])
from public, anon;
grant execute on function public.safra_start_treatment(uuid,uuid,text,uuid[])
to authenticated, service_role;

comment on function public.safra_start_treatment(uuid,uuid,text,uuid[]) is
  'C08 transactional/idempotent START. Intentional SECURITY DEFINER endpoint with canonical corporate-session check; resolves version/owner/area server-side and emits TREATMENT_OPENED using server timestamps.';

commit;
