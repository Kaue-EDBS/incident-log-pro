-- D-120 (02/10/2026) — M08 "Torre de Controle" cancelada; no lugar, uma faixa com os números
-- do momento no topo de "Todos os protocolos" (só Jair, Bruno e admins, D-104/M03). Sem modo TV.
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
    -- D-120: números do momento, sempre de todos os cards (os filtros não mudam a faixa).
    'summary', (
      select jsonb_build_object(
        'active', count(*),
        'nobody_closed', count(*) filter (where t.requester_closed_at is null and t.owner_closed_at is null),
        'waiting_owner', count(*) filter (where t.requester_closed_at is not null and t.owner_closed_at is null),
        'waiting_requester', count(*) filter (where t.owner_closed_at is not null and t.requester_closed_at is null),
        'closing_within_24h', count(*) filter (where t.opened_at + interval '72 hours' <= clock_timestamp() + interval '24 hours'),
        'oldest_opened_at', min(t.opened_at),
        'oldest_protocol_number', (select o.protocol_number from public.treatments o
                                   where o.status = 'ACTIVE' order by o.opened_at limit 1),
        'opened_today', (select count(*) from public.treatments d
                         where (d.opened_at at time zone 'America/Sao_Paulo')::date = (clock_timestamp() at time zone 'America/Sao_Paulo')::date),
        'closed_today', (select count(*) from public.treatments d
                         where d.status = 'RESOLVED'
                           and (d.closed_at at time zone 'America/Sao_Paulo')::date = (clock_timestamp() at time zone 'America/Sao_Paulo')::date)
      )
      from public.treatments t
      where t.status = 'ACTIVE'
    ),
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

commit;
