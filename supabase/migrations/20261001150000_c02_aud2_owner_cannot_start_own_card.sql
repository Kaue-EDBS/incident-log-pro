-- SAFRA-C02-AUD2 — aplica a D-65 no START e espelha a GI-SAFRA-011 (01/10/2026).
--   D-65: o dono vigente de um card não abre protocolo daquele card; pode abrir de cards de outros donos.
--   D-53: public.governance_issues espelha docs/GOVERNANCE_ISSUES.md (GI-SAFRA-011, Teams).

begin;

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
  v_active_treatment_id uuid;
  v_owner_user_id uuid;
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
    owner_p.user_id,
    sc.responsible_area_id
    into
      v_scenario_version_id,
      v_owner_id,
      v_owner_user_id,
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

  -- D-65: the current owner of a card does not open protocols of that card.
  if v_owner_user_id is not distinct from v_actor then
    raise exception using errcode='P0001', message='SAFRA_START_OWNER_OWN_CARD';
  end if;

  -- D-57: the scenario row lock above serializes STARTs of this scenario,
  -- so this check sees any ACTIVE treatment committed by the same person.
  select t.id
    into v_active_treatment_id
  from public.treatments t
  where t.scenario_id=p_scenario_id
    and t.opened_by=v_actor
    and t.status='ACTIVE'
  limit 1;

  if found then
    raise exception using
      errcode='P0001',
      message='SAFRA_START_ACTIVE_EXISTS',
      detail=v_active_treatment_id::text;
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
  'C08 transactional/idempotent START. Intentional SECURITY DEFINER endpoint with canonical corporate-session check; resolves version/owner/area server-side, rejects the current card owner (D-65), enforces one ACTIVE treatment per person and scenario (D-57) and emits TREATMENT_OPENED using server timestamps.';

insert into public.governance_issues(issue_key, title, description, status)
values (
  'GI-SAFRA-011',
  'Avisos pelo Teams',
  'OPEN — DEFERRED_TO_M05. A D-58 previa e-mail e Teams; na D-67 o owner confirmou o e-mail e ficou em dúvida sobre o Teams. Decidir se os avisos também vão pelo Teams e, se sim, por mensagem direta ou canal (num canal, todos os membros veem os dados do protocolo). Até a decisão, a M05 considera apenas e-mail.',
  'OPEN'
)
on conflict (issue_key) do nothing;

commit;
