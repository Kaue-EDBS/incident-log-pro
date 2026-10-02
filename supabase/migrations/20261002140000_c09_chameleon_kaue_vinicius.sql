-- SAFRA-C09 (02/10/2026) — D-96: Modo Camaleão só para Kaue e Vinicius (revisa a D-92).
-- Antes: qualquer safra_platform_admin (Kaue, Amanda, João, Vinicius).
-- Agora: platform admin E login corporativo vinculado a um destes e-mails. Os demais
-- admins continuam admins (Administração, Saúde do sistema), mas sem o "ver como".
begin;

create or replace function private.safra_can_use_chameleon()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
     and coalesce(public.safra_is_corporate_user(), false)
     and private.safra_has_role('safra_platform_admin')
     and exists (
       select 1
       from private.safra_principals p
       where p.user_id = (select auth.uid())
         and p.is_active
         and lower(p.corporate_email) = any (array[
           'kaue.pastrello@editoradobrasil.com.br',
           'vinicius.moraes@editoradobrasil.com.br'
         ])
     );
$$;

revoke all on function private.safra_can_use_chameleon() from public, anon, authenticated;

-- A tela pergunta ao banco se mostra o seletor.
create or replace function public.safra_can_use_chameleon()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.safra_can_use_chameleon(), false);
$$;

revoke all on function public.safra_can_use_chameleon() from public, anon;
grant execute on function public.safra_can_use_chameleon() to authenticated, service_role;

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
  if v_actor is null or not coalesce(private.safra_can_use_chameleon(), false) then
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
