-- SAFRA-C08.1 (02/10/2026) — ciclo de vida do protocolo no banco.
--
-- D-82  número do protocolo = número do card + sequência do card (08-0001), sem zerar.
-- D-83  resumo do problema obrigatório (mínimo 10 caracteres).
-- D-89  "quando o problema começou?" (problem_started_at) para o MTTD.
-- D-87  encerramento em duas partes (D-64/D-66/D-72) e cancelamento com motivo.
--       A trava D-57 passa a valer só enquanto a parte do solicitante estiver aberta.
-- Leituras: "Meus protocolos", "Protocolos dos meus cards" e o protocolo ativo no catálogo.
begin;

-- 1. Colunas e invariantes ------------------------------------------------------
alter table public.treatments
  add column protocol_seq integer,
  add column protocol_number text,
  add column problem_started_at timestamptz,
  add column requester_closed_at timestamptz,
  add column owner_closed_at timestamptz,
  add column owner_closed_by uuid references auth.users(id) on delete restrict;

do $$
begin
  if exists (select 1 from public.treatments) then
    raise exception 'C08.1: treatments is not empty; backfill would be required';
  end if;
end;
$$;

alter table public.treatments
  alter column protocol_seq set not null,
  alter column protocol_number set not null,
  alter column problem_started_at set not null,
  add constraint treatments_protocol_seq_positive check (protocol_seq > 0),
  add constraint treatments_protocol_number_key unique (protocol_number),
  add constraint treatments_scenario_protocol_seq_key unique (scenario_id, protocol_seq),
  add constraint treatments_problem_started_before_open check (problem_started_at <= opened_at),
  add constraint treatments_requester_part_after_open check (requester_closed_at is null or requester_closed_at >= opened_at),
  add constraint treatments_owner_part_after_open check (owner_closed_at is null or owner_closed_at >= opened_at),
  add constraint treatments_owner_part_author check ((owner_closed_at is null) = (owner_closed_by is null)),
  add constraint treatments_resolved_iff_both_parts check (
    (status = 'RESOLVED') = (requester_closed_at is not null and owner_closed_at is not null)
  );

create index idx_treatments_owner_closed_by on public.treatments(owner_closed_by);

-- D-57 revisada (D-66): a trava vale enquanto a parte do solicitante estiver aberta.
drop index public.treatments_one_active_per_person_scenario;
create unique index treatments_one_active_per_person_scenario
  on public.treatments(scenario_id, opened_by)
  where status = 'ACTIVE' and requester_closed_at is null;

alter table public.treatment_events drop constraint treatment_events_type_check;
alter table public.treatment_events
  add constraint treatment_events_type_check
  check (event_type = any (array[
    'TREATMENT_OPENED'::text,
    'NOTE_ADDED'::text,
    'IMPACT_AREA_ADDED'::text,
    'IMPACT_AREA_REMOVED'::text,
    'REQUESTER_PART_CLOSED'::text,
    'OWNER_PART_CLOSED'::text,
    'TREATMENT_RESOLVED'::text,
    'TREATMENT_CANCELLED'::text,
    'ADMIN_CORRECTION_RECORDED'::text
  ]));

-- 2. Relógio do servidor e imutabilidade -----------------------------------------
create or replace function private.safra_treatment_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then
    new.opened_at := v_now;
    new.created_at := v_now;
    new.updated_at := v_now;
    new.closed_at := null;
    new.cancelled_at := null;
    new.requester_closed_at := null;
    new.owner_closed_at := null;
    new.owner_closed_by := null;
    if new.problem_started_at is null or new.problem_started_at > v_now then
      new.problem_started_at := v_now;
    end if;
    return new;
  end if;

  new.updated_at := v_now;

  -- Partes do encerramento: horário sempre do servidor e nunca reescrito.
  if old.requester_closed_at is not null then
    new.requester_closed_at := old.requester_closed_at;
  elsif new.requester_closed_at is not null then
    new.requester_closed_at := v_now;
  end if;

  if old.owner_closed_at is not null then
    new.owner_closed_at := old.owner_closed_at;
    new.owner_closed_by := old.owner_closed_by;
  elsif new.owner_closed_at is not null then
    new.owner_closed_at := v_now;
  end if;

  if old.status = 'ACTIVE' and new.status = 'RESOLVED' then
    new.closed_at := v_now;
    new.cancelled_at := null;
  elsif old.status = 'ACTIVE' and new.status = 'CANCELLED' then
    new.cancelled_at := v_now;
    new.closed_at := null;
  elsif old.status = 'RESOLVED' then
    new.closed_by := old.closed_by;
    new.closed_at := old.closed_at;
  elsif old.status = 'CANCELLED' then
    new.cancelled_by := old.cancelled_by;
    new.cancelled_at := old.cancelled_at;
    new.cancellation_reason := old.cancellation_reason;
  end if;

  return new;
end;
$$;

create or replace function private.safra_guard_treatment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_current_version uuid;
  v_lifecycle text;
  v_responsible_area uuid;
  v_active_owner uuid;
begin
  if tg_op = 'DELETE' then
    raise exception 'treatment history cannot be physically deleted';
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'ACTIVE' then
      raise exception 'new treatment must start ACTIVE';
    end if;

    select s.current_version_id, s.lifecycle_status, s.responsible_area_id
      into v_current_version, v_lifecycle, v_responsible_area
    from public.scenarios s
    where s.id = new.scenario_id;

    if v_lifecycle <> 'ACTIVE' then
      raise exception 'START requires ACTIVE scenario';
    end if;

    if v_current_version is distinct from new.scenario_version_id then
      raise exception 'treatment must freeze current PUBLISHED scenario_version_id';
    end if;

    select so.owner_id into v_active_owner
    from public.scenario_owners so
    where so.scenario_id = new.scenario_id
      and so.valid_to is null;

    if v_active_owner is distinct from new.owner_id_at_start then
      raise exception 'owner_id_at_start must snapshot active scenario owner';
    end if;

    if v_responsible_area is distinct from new.responsible_area_id_at_start then
      raise exception 'responsible_area_id_at_start must snapshot current responsible area';
    end if;

    return new;
  end if;

  if new.scenario_id is distinct from old.scenario_id
     or new.scenario_version_id is distinct from old.scenario_version_id
     or new.opened_by is distinct from old.opened_by
     or new.opened_at is distinct from old.opened_at
     or new.owner_id_at_start is distinct from old.owner_id_at_start
     or new.responsible_area_id_at_start is distinct from old.responsible_area_id_at_start
     or new.start_correlation_id is distinct from old.start_correlation_id
     or new.start_idempotency_key is distinct from old.start_idempotency_key
     or new.protocol_seq is distinct from old.protocol_seq
     or new.protocol_number is distinct from old.protocol_number
     or new.problem_started_at is distinct from old.problem_started_at
     or new.impact_summary is distinct from old.impact_summary
  then
    raise exception 'treatment START snapshot fields are immutable';
  end if;

  if new.status is distinct from old.status then
    if new.status = 'RESOLVED' and old.status <> 'ACTIVE' then
      raise exception 'END is allowed only from ACTIVE treatment';
    end if;

    if new.status = 'CANCELLED' and old.status <> 'ACTIVE' then
      raise exception 'CANCEL is allowed only from ACTIVE treatment';
    end if;

    if old.status <> 'ACTIVE' then
      raise exception 'closed treatment status is immutable';
    end if;

    if new.status not in ('RESOLVED','CANCELLED') then
      raise exception 'invalid treatment state transition';
    end if;
  end if;

  if old.status = 'ACTIVE'
     and new.status = 'CANCELLED'
     and btrim(coalesce(new.cancellation_reason, '')) = ''
  then
    raise exception 'CANCEL requires cancellation_reason';
  end if;

  return new;
end;
$$;

-- 3. Visão de um protocolo (D-72) ------------------------------------------------
create or replace function private.safra_treatment_situation(
  p_status text,
  p_requester_closed_at timestamptz,
  p_owner_closed_at timestamptz
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_status = 'CANCELLED' then 'CANCELADO'
    when p_status = 'RESOLVED' then 'ENCERRADO'
    when p_requester_closed_at is not null and p_owner_closed_at is null then 'AGUARDANDO_DONO'
    when p_owner_closed_at is not null and p_requester_closed_at is null then 'AGUARDANDO_SOLICITANTE'
    else 'EM_ANDAMENTO'
  end;
$$;

-- Dono vigente do card (para permissões de encerramento e cancelamento, D-64).
create or replace function private.safra_current_owner_user_id(p_scenario_id uuid)
returns uuid
language sql
stable
set search_path = ''
as $$
  select p.user_id
  from public.scenario_owners so
  join private.safra_principals p on p.id = so.owner_id
  where so.scenario_id = p_scenario_id
    and so.valid_to is null
    and private.safra_owner_is_available(so.owner_id);
$$;

create or replace function private.safra_treatment_view_json(p_treatment_id uuid, p_actor uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'treatment_id', t.id,
    'protocol_number', t.protocol_number,
    'status', t.status,
    'situation', private.safra_treatment_situation(t.status, t.requester_closed_at, t.owner_closed_at),
    'scenario', jsonb_build_object('id', sc.id, 'code', sc.code, 'name', sc.name),
    'owner', jsonb_build_object(
      'principal_id', owner_p.id,
      'display_name', owner_p.display_name,
      'corporate_email', owner_p.corporate_email
    ),
    'requester_email', lower(u.email),
    'impact_summary', t.impact_summary,
    'impacted_areas', coalesce((
      select jsonb_agg(jsonb_build_object('id', ia.id, 'code', ia.code, 'name', ia.name) order by ia.name)
      from public.treatment_impacted_areas tia
      join public.operational_areas ia on ia.id = tia.operational_area_id
      where tia.treatment_id = t.id and tia.valid_to is null
    ), '[]'::jsonb),
    'problem_started_at', t.problem_started_at,
    'opened_at', t.opened_at,
    'requester_closed_at', t.requester_closed_at,
    'owner_closed_at', t.owner_closed_at,
    'closed_at', t.closed_at,
    'cancelled_at', t.cancelled_at,
    'cancellation_reason', t.cancellation_reason,
    'server_time', clock_timestamp(),
    'my_role', case
      when t.opened_by = p_actor then 'REQUESTER'
      when private.safra_current_owner_user_id(t.scenario_id) is not distinct from p_actor then 'OWNER'
      else null
    end,
    'can_close_my_part', t.status = 'ACTIVE' and (
      (t.opened_by = p_actor and t.requester_closed_at is null)
      or (t.opened_by <> p_actor
          and private.safra_current_owner_user_id(t.scenario_id) is not distinct from p_actor
          and t.owner_closed_at is null)
    ),
    'can_cancel', t.status = 'ACTIVE' and (
      t.opened_by = p_actor
      or private.safra_current_owner_user_id(t.scenario_id) is not distinct from p_actor
    )
  )
  from public.treatments t
  join public.scenarios sc on sc.id = t.scenario_id
  join private.safra_principals owner_p on owner_p.id = t.owner_id_at_start
  join auth.users u on u.id = t.opened_by
  where t.id = p_treatment_id;
$$;

revoke all on function private.safra_treatment_situation(text, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function private.safra_current_owner_user_id(uuid) from public, anon, authenticated;
revoke all on function private.safra_treatment_view_json(uuid, uuid) from public, anon, authenticated;

-- 4. Resumo do START ------------------------------------------------------------
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
    'protocol_number', t.protocol_number,
    'status', t.status,
    'opened_at', t.opened_at,
    'problem_started_at', t.problem_started_at,
    'server_time', p_as_of,
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

-- 5. START (agora com número, resumo obrigatório e início do problema) ---------
drop function public.safra_start_treatment(uuid, uuid, text, uuid[]);

create function public.safra_start_treatment(
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

comment on function public.safra_start_treatment(uuid, uuid, text, uuid[], timestamptz) is
  'C08 transactional/idempotent START. SECURITY DEFINER endpoint with canonical corporate-session check; resolves version/owner/area server-side, rejects the current card owner (D-65) and unavailable owners (D-78), one open requester part per person and card (D-57/D-66), required problem summary (D-83), protocol number card-sequence (D-82), problem start for MTTD (D-89).';

-- 6. Encerrar a minha parte (D-64/D-66) ------------------------------------------
create or replace function public.safra_close_my_part(p_treatment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_t public.treatments%rowtype;
  v_owner_user uuid;
  v_role text;
  v_correlation_id uuid := gen_random_uuid();
  v_resolved boolean;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_CLOSE_FORBIDDEN';
  end if;

  select * into v_t from public.treatments where id = p_treatment_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_CLOSE_FORBIDDEN';
  end if;

  v_owner_user := private.safra_current_owner_user_id(v_t.scenario_id);

  if v_t.opened_by = v_actor then
    v_role := 'REQUESTER';
  elsif v_owner_user is not distinct from v_actor and v_owner_user is not null then
    v_role := 'OWNER';
  else
    raise exception using errcode = '42501', message = 'SAFRA_CLOSE_FORBIDDEN';
  end if;

  if v_t.status <> 'ACTIVE' then
    raise exception using errcode = 'P0001', message = 'SAFRA_TREATMENT_NOT_ACTIVE';
  end if;

  if (v_role = 'REQUESTER' and v_t.requester_closed_at is not null)
     or (v_role = 'OWNER' and v_t.owner_closed_at is not null) then
    return private.safra_treatment_view_json(v_t.id, v_actor) || jsonb_build_object('already_closed', true);
  end if;

  v_resolved := case when v_role = 'REQUESTER' then v_t.owner_closed_at is not null
                     else v_t.requester_closed_at is not null end;

  update public.treatments
     set requester_closed_at = case when v_role = 'REQUESTER' then clock_timestamp() else requester_closed_at end,
         owner_closed_at = case when v_role = 'OWNER' then clock_timestamp() else owner_closed_at end,
         owner_closed_by = case when v_role = 'OWNER' then v_actor else owner_closed_by end,
         status = case when v_resolved then 'RESOLVED' else status end,
         closed_by = case when v_resolved then v_actor else closed_by end,
         closed_at = case when v_resolved then clock_timestamp() else closed_at end
   where id = v_t.id;

  insert into public.treatment_events(treatment_id, event_type, actor_user_id, correlation_id, payload)
  values (v_t.id,
          case when v_role = 'REQUESTER' then 'REQUESTER_PART_CLOSED' else 'OWNER_PART_CLOSED' end,
          v_actor, v_correlation_id,
          jsonb_build_object('source', 'SAFRA_C08_CLOSE_PART', 'role', v_role));

  if v_resolved then
    insert into public.treatment_events(treatment_id, event_type, actor_user_id, correlation_id, payload)
    values (v_t.id, 'TREATMENT_RESOLVED', v_actor, v_correlation_id,
            jsonb_build_object('source', 'SAFRA_C08_CLOSE_PART', 'last_part', v_role));
  end if;

  return private.safra_treatment_view_json(v_t.id, v_actor) || jsonb_build_object('already_closed', false);
end;
$$;

revoke all on function public.safra_close_my_part(uuid) from public, anon;
grant execute on function public.safra_close_my_part(uuid) to authenticated, service_role;

-- 7. Cancelar (D-66) -------------------------------------------------------------
create or replace function public.safra_cancel_treatment(p_treatment_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_t public.treatments%rowtype;
  v_owner_user uuid;
  v_role text;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_CANCEL_FORBIDDEN';
  end if;

  select * into v_t from public.treatments where id = p_treatment_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_CANCEL_FORBIDDEN';
  end if;

  v_owner_user := private.safra_current_owner_user_id(v_t.scenario_id);

  if v_t.opened_by = v_actor then
    v_role := 'REQUESTER';
  elsif v_owner_user is not distinct from v_actor and v_owner_user is not null then
    v_role := 'OWNER';
  else
    raise exception using errcode = '42501', message = 'SAFRA_CANCEL_FORBIDDEN';
  end if;

  if v_t.status <> 'ACTIVE' then
    raise exception using errcode = 'P0001', message = 'SAFRA_TREATMENT_NOT_ACTIVE';
  end if;

  if v_reason is null or length(v_reason) < 10 then
    raise exception using errcode = '22023', message = 'SAFRA_CANCEL_REASON_REQUIRED';
  end if;

  if length(v_reason) > 1000 then
    raise exception using errcode = '22023', message = 'SAFRA_CANCEL_REASON_TOO_LONG';
  end if;

  update public.treatments
     set status = 'CANCELLED',
         cancelled_by = v_actor,
         cancelled_at = clock_timestamp(),
         cancellation_reason = v_reason
   where id = v_t.id;

  insert into public.treatment_events(treatment_id, event_type, actor_user_id, correlation_id, payload)
  values (v_t.id, 'TREATMENT_CANCELLED', v_actor, gen_random_uuid(),
          jsonb_build_object('source', 'SAFRA_C08_CANCEL', 'role', v_role));

  return private.safra_treatment_view_json(v_t.id, v_actor);
end;
$$;

revoke all on function public.safra_cancel_treatment(uuid, text) from public, anon;
grant execute on function public.safra_cancel_treatment(uuid, text) to authenticated, service_role;

-- 8. Leituras ---------------------------------------------------------------------
create or replace function public.safra_get_my_treatments()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_READ_FORBIDDEN';
  end if;

  return coalesce((
    select jsonb_agg(private.safra_treatment_view_json(t.id, v_actor)
                     order by (t.status = 'ACTIVE') desc, t.opened_at desc)
    from (
      select t.id, t.status, t.opened_at
      from public.treatments t
      where t.opened_by = v_actor
      order by (t.status = 'ACTIVE') desc, t.opened_at desc
      limit 200
    ) t
  ), '[]'::jsonb);
end;
$$;

create or replace function public.safra_get_owner_treatments()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_READ_FORBIDDEN';
  end if;

  return coalesce((
    select jsonb_agg(private.safra_treatment_view_json(t.id, v_actor)
                     order by (t.status = 'ACTIVE') desc, t.opened_at desc)
    from (
      select t.id, t.status, t.opened_at
      from public.treatments t
      where private.safra_current_owner_user_id(t.scenario_id) = v_actor
      order by (t.status = 'ACTIVE') desc, t.opened_at desc
      limit 200
    ) t
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.safra_get_my_treatments() from public, anon;
revoke all on function public.safra_get_owner_treatments() from public, anon;
grant execute on function public.safra_get_my_treatments() to authenticated, service_role;
grant execute on function public.safra_get_owner_treatments() to authenticated, service_role;

-- 9. Catálogo: o protocolo do próprio usuário naquele card ---------------------
create or replace function public.safra_get_start_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null
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
        'is_my_card', (p.user_id is not distinct from v_actor),
        'my_open_treatment', (
          select private.safra_treatment_view_json(t.id, v_actor)
          from public.treatments t
          where t.scenario_id = sc.id
            and t.opened_by = v_actor
            and t.status = 'ACTIVE'
            and t.requester_closed_at is null
          limit 1
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
  join public.operational_areas oa
    on oa.id = sc.responsible_area_id
  where sc.lifecycle_status = 'ACTIVE'
    and private.safra_owner_is_available(so.owner_id);

  return v_result;
end;
$$;

-- Conferência -------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.safra_start_treatment(uuid,uuid,text,uuid[])') is not null then
    raise exception 'C08.1: old 4-argument START still exists';
  end if;
  if has_function_privilege('anon', 'public.safra_close_my_part(uuid)', 'EXECUTE')
     or has_function_privilege('anon', 'public.safra_cancel_treatment(uuid,text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.safra_get_my_treatments()', 'EXECUTE')
     or has_function_privilege('anon', 'public.safra_get_owner_treatments()', 'EXECUTE') then
    raise exception 'C08.1: anon can execute a protocol command';
  end if;
end;
$$;

commit;
