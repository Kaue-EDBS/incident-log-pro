-- SAFRA-M03 (02/10/2026) — "Todos os protocolos": a gestão (Jair e Bruno) e os platform admins
-- chegam a qualquer protocolo e ao histórico dele (D-104). Só leitura: as ações continuam
-- só para quem abriu e para o dono do card.
begin;

create or replace function public.safra_get_all_treatments(
  p_status text default null,
  p_scenario_id uuid default null,
  p_limit integer default 300
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_limit integer := greatest(1, least(coalesce(p_limit, 300), 500));
begin
  if v_actor is null
     or not coalesce(public.safra_is_corporate_user(), false)
     or not (private.safra_has_role('safra_governance_admin')
          or private.safra_has_role('safra_executive_admin')
          or private.safra_has_role('safra_platform_admin'))
  then
    raise exception using errcode = '42501', message = 'SAFRA_READ_FORBIDDEN';
  end if;

  if p_status is not null and p_status not in ('ACTIVE', 'RESOLVED', 'CANCELLED') then
    raise exception using errcode = '22023', message = 'SAFRA_INVALID_FILTER';
  end if;

  return jsonb_build_object(
    'total', (
      select count(*) from public.treatments t
      where (p_status is null or t.status = p_status)
        and (p_scenario_id is null or t.scenario_id = p_scenario_id)
    ),
    'items', coalesce((
      select jsonb_agg(
               private.safra_treatment_view_json(x.id, v_actor)
               || jsonb_build_object('requester_name', private.safra_user_display_name(x.opened_by))
               order by (x.status = 'ACTIVE') desc, x.opened_at desc)
      from (
        select t.id, t.status, t.opened_at, t.opened_by
        from public.treatments t
        where (p_status is null or t.status = p_status)
          and (p_scenario_id is null or t.scenario_id = p_scenario_id)
        order by (t.status = 'ACTIVE') desc, t.opened_at desc
        limit v_limit
      ) x
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.safra_get_all_treatments(text, uuid, integer) from public, anon;
grant execute on function public.safra_get_all_treatments(text, uuid, integer) to authenticated, service_role;

comment on function public.safra_get_all_treatments(text, uuid, integer) is
  'M03: read-only list of every protocol for governance (Jair/Bruno) and platform admins (D-104), newest active first, max 500 per call.';

commit;
