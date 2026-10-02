-- Auditoria geral C00–C07 (01/10/2026) — pacote aprovado pelo owner (A-01..A-19).
--
-- A-01  identidade presa ao tenant Microsoft da Editora (tid lido de auth.identities,
--       que o usuário não edita), no predicado corporativo e no vínculo login ↔ cadastro.
-- A-04  D-78: dono desativado ou sem papel scenario_owner bloqueia o card até nova definição.
-- A-05  mudanças em safra_principals entram na trilha de auditoria.
-- A-08  catálogo indica se o card é do próprio usuário (D-65).
-- A-11  safra_log_access_denied removida (sem chamadores; um registro feito antes de um
--       erro é desfeito junto com a transação).
-- A-12  índice redundante removido.
-- A-16  resumo do START traz o horário do servidor, para o contador da tela.
begin;

-- A-01 -----------------------------------------------------------------------
create or replace function private.safra_entra_tenant_id()
returns text
language sql
immutable
set search_path = ''
as $$
  select '45ba725f-d260-45c3-ac85-11f433471277'::text;
$$;

create or replace function private.safra_user_in_corporate_tenant(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null
     and exists (
       select 1
       from auth.identities i
       where i.user_id = p_user_id
         and i.provider = 'azure'
         and i.identity_data -> 'custom_claims' ->> 'tid' = private.safra_entra_tenant_id()
     );
$$;

create or replace function private.safra_session_in_corporate_tenant()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.safra_user_in_corporate_tenant((select auth.uid()));
$$;

revoke all on function private.safra_entra_tenant_id() from public, anon, authenticated;
revoke all on function private.safra_user_in_corporate_tenant(uuid) from public, anon, authenticated;
revoke all on function private.safra_session_in_corporate_tenant() from public, anon;
grant execute on function private.safra_session_in_corporate_tenant() to authenticated;

create or replace function public.safra_is_corporate_user()
returns boolean
language sql
stable
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and coalesce((select auth.jwt() ->> 'is_anonymous'), 'false') <> 'true'
    and coalesce((select auth.jwt() -> 'app_metadata' ->> 'provider'), '') = 'azure'
    and (
      lower(coalesce((select auth.jwt() ->> 'email'), '')) like '%@editoradobrasil.com.br'
      or lower(coalesce((select auth.jwt() ->> 'email'), '')) like '%@editoradobrasil1.onmicrosoft.com'
    )
    and coalesce((select (auth.jwt() ->> 'exp')::bigint), 0) > extract(epoch from now())::bigint
    and (select private.safra_session_is_live())
    and (select private.safra_session_in_corporate_tenant());
$$;

create or replace function private.bind_safra_principal_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is not null
     and coalesce(new.raw_app_meta_data ->> 'provider', '') = 'azure'
     and coalesce(new.is_anonymous, false) = false
     and private.safra_user_in_corporate_tenant(new.id)
  then
    update private.safra_principals
       set user_id = new.id,
           updated_at = now()
     where corporate_email = lower(new.email)
       and (user_id is null or user_id = new.id);
  end if;
  return new;
end;
$$;

-- No login real, a identidade Microsoft é gravada depois do usuário; o vínculo
-- também precisa acontecer quando a identidade chega.
create or replace function private.bind_safra_principal_from_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_anonymous boolean;
begin
  if new.provider = 'azure'
     and new.identity_data -> 'custom_claims' ->> 'tid' = private.safra_entra_tenant_id()
  then
    select lower(u.email), coalesce(u.is_anonymous, false)
      into v_email, v_anonymous
    from auth.users u
    where u.id = new.user_id;

    if v_email is not null and not v_anonymous then
      update private.safra_principals
         set user_id = new.user_id,
             updated_at = now()
       where corporate_email = v_email
         and (user_id is null or user_id = new.user_id);
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.bind_safra_principal_from_identity() from public, anon, authenticated;

drop trigger if exists trg_bind_safra_principal_from_identity on auth.identities;
create trigger trg_bind_safra_principal_from_identity
after insert or update of identity_data, provider on auth.identities
for each row execute function private.bind_safra_principal_from_identity();

-- A-04 / D-78 ----------------------------------------------------------------
create or replace function private.safra_owner_is_available(p_principal_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from private.safra_principals p
    join private.safra_role_grants rg
      on rg.principal_id = p.id
     and rg.role = 'scenario_owner'
     and rg.revoked_at is null
    where p.id = p_principal_id
      and p.is_active
  );
$$;

revoke all on function private.safra_owner_is_available(uuid) from public, anon, authenticated;

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

create or replace function public.safra_start_treatment(
  p_scenario_id uuid,
  p_idempotency_key uuid,
  p_impact_summary text default null,
  p_impacted_area_ids uuid[] default '{}'::uuid[]
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
    sc.responsible_area_id
    into
      v_scenario_version_id,
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

-- A-16: horário do servidor no resumo do START ------------------------------
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

-- A-05: auditoria dos cadastros ----------------------------------------------
alter table private.safra_rbac_audit_events drop constraint safra_rbac_audit_action_check;
alter table private.safra_rbac_audit_events
  add constraint safra_rbac_audit_action_check
  check (action = any (array[
    'ROLE_GRANTED'::text,
    'ROLE_CHANGED'::text,
    'ROLE_REVOKED'::text,
    'ROLE_GRANT_DELETED'::text,
    'PRINCIPAL_CREATED'::text,
    'PRINCIPAL_BOUND'::text,
    'PRINCIPAL_UNBOUND'::text,
    'PRINCIPAL_DEACTIVATED'::text,
    'PRINCIPAL_REACTIVATED'::text,
    'PRINCIPAL_CHANGED'::text,
    'PRINCIPAL_DELETED'::text,
    'ACCESS_DENIED'::text
  ]));

create or replace function private.safra_audit_principal_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action text;
  v_row private.safra_principals%rowtype;
  v_details jsonb;
begin
  if tg_op = 'INSERT' then
    v_action := 'PRINCIPAL_CREATED';
    v_row := new;
    v_details := jsonb_build_object('is_active', new.is_active, 'bound', new.user_id is not null);
  elsif tg_op = 'UPDATE' then
    v_row := new;
    if old.user_id is distinct from new.user_id then
      v_action := case when new.user_id is null then 'PRINCIPAL_UNBOUND' else 'PRINCIPAL_BOUND' end;
    elsif old.is_active is distinct from new.is_active then
      v_action := case when new.is_active then 'PRINCIPAL_REACTIVATED' else 'PRINCIPAL_DEACTIVATED' end;
    elsif old.corporate_email is distinct from new.corporate_email
       or old.display_name is distinct from new.display_name then
      v_action := 'PRINCIPAL_CHANGED';
    else
      return new;
    end if;
    v_details := jsonb_build_object(
      'old_user_id', old.user_id,
      'new_user_id', new.user_id,
      'old_is_active', old.is_active,
      'new_is_active', new.is_active,
      'old_email', old.corporate_email,
      'new_email', new.corporate_email,
      'old_display_name', old.display_name,
      'new_display_name', new.display_name
    );
  else
    v_action := 'PRINCIPAL_DELETED';
    v_row := old;
    v_details := jsonb_build_object('is_active', old.is_active, 'bound', old.user_id is not null);
  end if;

  perform private.safra_log_rbac_event(
    v_action,
    'private.safra_principals',
    'SUCCESS',
    v_row.id,
    v_row.corporate_email,
    null,
    v_details
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.safra_audit_principal_change() from public, anon, authenticated;

drop trigger if exists trg_safra_audit_principal_change on private.safra_principals;
create trigger trg_safra_audit_principal_change
after insert or update or delete on private.safra_principals
for each row execute function private.safra_audit_principal_change();

-- A-11 / A-12 ----------------------------------------------------------------
drop function if exists public.safra_log_access_denied(text, text);
drop index if exists public.treatments_scenario_version_idx;

-- Conferência ----------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from private.safra_principals p
    where p.user_id is not null
      and not private.safra_user_in_corporate_tenant(p.user_id)
  ) then
    raise exception 'AUD-GERAL: a bound principal is outside the corporate tenant';
  end if;
  if to_regprocedure('public.safra_log_access_denied(text,text)') is not null then
    raise exception 'AUD-GERAL: safra_log_access_denied still exists';
  end if;
end;
$$;

commit;
