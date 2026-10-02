-- SAFRA-C01-AUD2 — pacote final da rodada de governança (01/10/2026).
--   D-55: os 11 cenários passam a CRITICAL numa nova scenario_version (v2); a v1 vira RETIRED.
--   D-62: nenhum cronômetro de SLA é criado (public.scenario_slas permanece vazio).
--   D-57: no máximo uma tratativa ACTIVE por pessoa e por cenário.
--   D-55/57/61/62/63: GI-SAFRA-001/004/008/009/010 marcados RESOLVED quando o owner existe no Auth.

begin;

-- ---------------------------------------------------------------------------
-- 1. Versão 2 CRITICAL dos 11 cenários (conteúdo idêntico à v1, exceto criticidade).
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
  v_new_version uuid;
begin
  for r in
    select sc.id as scenario_id, sv.*
    from public.scenarios sc
    join public.scenario_versions sv on sv.id = sc.current_version_id
    where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
      and sv.status = 'PUBLISHED'
      and sv.criticality is distinct from 'CRITICAL'
    order by sc.code
  loop
    insert into public.scenario_versions(
      scenario_id, version_no, status,
      trigger_description, detection_description, protocol_text,
      expected_impact_summary, criticality, source_reference
    )
    values(
      r.scenario_id, r.version_no + 1, 'DRAFT',
      r.trigger_description, r.detection_description, r.protocol_text,
      r.expected_impact_summary, 'CRITICAL', r.source_reference
    )
    returning id into v_new_version;

    insert into public.scenario_version_impacted_areas(scenario_version_id, operational_area_id)
    select v_new_version, svia.operational_area_id
    from public.scenario_version_impacted_areas svia
    where svia.scenario_version_id = r.id;

    insert into public.scenario_version_systems(scenario_version_id, system_id, context)
    select v_new_version, svs.system_id, svs.context
    from public.scenario_version_systems svs
    where svs.scenario_version_id = r.id;

    update public.scenario_versions set status = 'RETIRED' where id = r.id;
    update public.scenario_versions set status = 'PUBLISHED' where id = v_new_version;
    update public.scenarios set current_version_id = v_new_version where id = r.scenario_id;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Trava D-57: uma tratativa ACTIVE por pessoa e por cenário.
-- ---------------------------------------------------------------------------
create unique index treatments_one_active_per_person_scenario
  on public.treatments(scenario_id, opened_by)
  where status = 'ACTIVE';

comment on index public.treatments_one_active_per_person_scenario is
  'D-57: a person may hold at most one ACTIVE treatment per scenario; different people may open the same scenario.';

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
  'C08 transactional/idempotent START. Intentional SECURITY DEFINER endpoint with canonical corporate-session check; resolves version/owner/area server-side, enforces one ACTIVE treatment per person and scenario (D-57) and emits TREATMENT_OPENED using server timestamps.';

-- ---------------------------------------------------------------------------
-- 3. Resolução dos GI decididos e aplicados.
--    resolved_by exige um usuário Auth real: o owner da decisão. Em bancos sem esse
--    usuário (ex.: banco descartável do CI) a resolução não é aplicada; a lógica é
--    testada pela função abaixo dentro de transação com usuário sintético.
-- ---------------------------------------------------------------------------
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
    ('GI-SAFRA-009', 'D-62 (01/10/2026): nenhum card terá cronômetro de SLA; no lugar, escada de avisos 2h/3h/4h, 24h por dia, a implementar na M05/F01.'),
    ('GI-SAFRA-010', 'D-63 (01/10/2026): os 11 cenários publicados seguem liberados para qualquer usuário corporativo autenticado; sem restrição por card.')
  ) as r(issue_key, resolution_text)
  where gi.issue_key = r.issue_key
    and gi.status = 'OPEN';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function private.safra_c01_aud2_resolve_governance_issues(uuid) from public, anon, authenticated;

do $$
declare
  v_owner uuid;
begin
  select u.id into v_owner
  from auth.users u
  where lower(u.email) = 'kaue.pastrello@editoradobrasil.com.br';

  if v_owner is not null then
    perform private.safra_c01_aud2_resolve_governance_issues(v_owner);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Conferência.
-- ---------------------------------------------------------------------------
do $$
begin
  if (select count(*) from public.scenarios sc
      join public.scenario_versions sv on sv.id = sc.current_version_id
      where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
        and sv.status = 'PUBLISHED' and sv.criticality = 'CRITICAL') <> 11 then
    raise exception 'C01-AUD2: expected 11 CRITICAL published versions';
  end if;

  if exists (select 1 from public.scenario_slas) then
    raise exception 'C01-AUD2: D-62 forbids structured SLA rows';
  end if;
end;
$$;

commit;
