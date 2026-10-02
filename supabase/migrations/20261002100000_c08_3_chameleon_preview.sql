-- SAFRA-C08.3 (02/10/2026) — Modo Camaleão (D-92).
-- Um platform admin pode VER a tela "Protocolos dos meus cards" como um dono de card a vê.
-- É só leitura: a visão é montada com o próprio admin como ator, então Concluído e
-- Cancelar continuam desligados para ele (só quem abriu ou o dono podem agir).
begin;

create or replace function public.safra_admin_get_owner_treatments(p_owner_principal_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null
     or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_platform_admin')
  then
    raise exception using errcode = '42501', message = 'SAFRA_PREVIEW_FORBIDDEN';
  end if;

  return coalesce((
    select jsonb_agg(private.safra_treatment_view_json(t.id, v_actor)
                     order by (t.status = 'ACTIVE') desc, t.opened_at desc)
    from (
      select t.id, t.status, t.opened_at
      from public.treatments t
      join public.scenario_owners so
        on so.scenario_id = t.scenario_id
       and so.valid_to is null
      where so.owner_id = p_owner_principal_id
      order by (t.status = 'ACTIVE') desc, t.opened_at desc
      limit 200
    ) t
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.safra_admin_get_owner_treatments(uuid) from public, anon;
grant execute on function public.safra_admin_get_owner_treatments(uuid) to authenticated, service_role;

commit;
