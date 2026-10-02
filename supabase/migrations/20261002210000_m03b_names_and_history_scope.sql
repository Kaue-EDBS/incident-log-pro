-- SAFRA-M03 (02/10/2026) — ajustes do owner depois da auditoria da M03.
--
-- D-106 a lista de protocolos não mostra as áreas impactadas (só a tela muda).
-- D-107 quem abriu aparece pelo nome em todas as listas (antes: e-mail no dono do card).
-- D-108 o histórico do protocolo passa a ser só da gestão (Jair e Bruno) e dos platform
--       admins; quem abriu e o dono do card não veem mais (revisa a D-104).
begin;

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
    'requester_name', private.safra_user_display_name(t.opened_by),
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
    'auto_cancelled', t.auto_cancelled,
    'auto_cancel_at', case
      when t.status = 'ACTIVE' and t.requester_closed_at is null and t.owner_closed_at is null
      then t.opened_at + interval '72 hours'
    end,
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
    'can_undo_my_part', t.status = 'ACTIVE' and (
      (t.opened_by = p_actor and t.requester_closed_at is not null
        and clock_timestamp() - t.requester_closed_at <= interval '5 minutes')
      or (t.owner_closed_by = p_actor and t.owner_closed_at is not null
        and clock_timestamp() - t.owner_closed_at <= interval '5 minutes')
    ),
    'undo_until', case
      when t.status <> 'ACTIVE' then null
      when t.opened_by = p_actor and t.requester_closed_at is not null
        then t.requester_closed_at + interval '5 minutes'
      when t.owner_closed_by = p_actor and t.owner_closed_at is not null
        then t.owner_closed_at + interval '5 minutes'
    end,
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

revoke all on function private.safra_treatment_view_json(uuid, uuid) from public, anon, authenticated;

create or replace function public.safra_get_treatment_timeline(p_treatment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_t public.treatments%rowtype;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_TIMELINE_FORBIDDEN';
  end if;

  select * into v_t from public.treatments where id = p_treatment_id;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_TIMELINE_FORBIDDEN';
  end if;

  -- D-108: só a gestão (Jair e Bruno) e os platform admins.
  if not (
    private.safra_has_role('safra_governance_admin')
    or private.safra_has_role('safra_executive_admin')
    or private.safra_has_role('safra_platform_admin')
  ) then
    raise exception using errcode = '42501', message = 'SAFRA_TIMELINE_FORBIDDEN';
  end if;

  return jsonb_build_object(
    'treatment', private.safra_treatment_view_json(v_t.id, v_actor),
    'scenario_version_no', (select sv.version_no from public.scenario_versions sv where sv.id = v_t.scenario_version_id),
    'opened_by_name', private.safra_user_display_name(v_t.opened_by),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'event_id', e.id,
        'occurred_at', e.occurred_at,
        'event_type', e.event_type,
        'actor_role', case
          when e.actor_user_id is null then 'SYSTEM'
          when e.actor_user_id = v_t.opened_by then 'REQUESTER'
          else 'OWNER'
        end,
        'actor_name', case
          when e.actor_user_id is null then 'Sistema'
          else private.safra_user_display_name(e.actor_user_id)
        end
      ) order by e.occurred_at, e.created_at, e.id)
      from public.treatment_events e
      where e.treatment_id = v_t.id
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.safra_get_treatment_timeline(uuid) from public, anon;
grant execute on function public.safra_get_treatment_timeline(uuid) to authenticated, service_role;

comment on function public.safra_get_treatment_timeline(uuid) is
  'M02/M03: append-only history of one protocol, readable only by governance (Jair/Bruno) and platform admins (D-108); actors by name (D-105).';

commit;
