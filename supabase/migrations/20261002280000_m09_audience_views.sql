-- SAFRA-M09 (02/10/2026) — visões por audiência (D-88), respostas do owner:
--
-- D-121 "Cards e donos": cada card com o dono, a área responsável e os protocolos da Safra;
--       só leitura, para Jair, Bruno e platform admins.
-- D-122 Analytics ganha o ranking "cards que mais falham na Safra" (montado na tela a partir
--       dos indicadores da D-117; sem mudança no banco).
-- D-123 Administração ganha o painel de cadastrados (pessoas, papéis, quem já entrou) e a
--       trilha de papéis (já existente: get_safra_rbac_audit_events); só platform admins.
-- D-124 uso das telas anônimo (D-90): conta, por dia, quantas vezes cada tela foi aberta,
--       sem guardar quem abriu; só platform admins leem.
-- Pendências de governança não viram tela (são do projeto, não da operação). Bruno vê o mesmo
-- que o Jair.
begin;

-- 1. Cards e donos (D-121) --------------------------------------------------------------
create or replace function public.safra_get_cards_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
     or not coalesce(public.safra_is_corporate_user(), false)
     or not (private.safra_has_role('safra_governance_admin')
          or private.safra_has_role('safra_executive_admin')
          or private.safra_has_role('safra_platform_admin'))
  then
    raise exception using errcode = '42501', message = 'SAFRA_READ_FORBIDDEN';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'scenario_id', sc.id,
      'code', sc.code,
      'name', sc.name,
      'version_no', sv.version_no,
      'responsible_area', ra.name,
      'owner_name', coalesce(nullif(btrim(p.display_name), ''), p.corporate_email),
      'owner_email', p.corporate_email,
      'owner_available', coalesce(private.safra_owner_is_available(p.id), false),
      'owner_has_logged_in', p.user_id is not null,
      'active_now', (select count(*) from public.treatments t where t.scenario_id = sc.id and t.status = 'ACTIVE'),
      'season_protocols', (select count(*) from public.treatments t
                           where t.scenario_id = sc.id and t.opened_at >= private.safra_current_season_start()
                             and not exists (select 1 from public.treatment_analytics_exclusions x where x.treatment_id = t.id))
    ) order by sc.code)
    from public.scenarios sc
    left join public.scenario_versions sv on sv.id = sc.current_version_id
    left join public.operational_areas ra on ra.id = sc.responsible_area_id
    left join public.scenario_owners so on so.scenario_id = sc.id and so.valid_to is null
    left join private.safra_principals p on p.id = so.owner_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.safra_get_cards_overview() from public, anon;
grant execute on function public.safra_get_cards_overview() to authenticated, service_role;

-- 2. Painel de cadastrados (D-123) -------------------------------------------------------
create or replace function public.safra_admin_get_people()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null
     or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_platform_admin')
  then
    raise exception using errcode = '42501', message = 'SAFRA_ADMIN_FORBIDDEN';
  end if;

  return jsonb_build_object('people', coalesce((
    select jsonb_agg(jsonb_build_object(
      'principal_id', p.id,
      'name', p.display_name,
      'email', p.corporate_email,
      'active', p.is_active,
      'has_logged_in', p.user_id is not null,
      'last_sign_in_at', u.last_sign_in_at,
      'roles', coalesce((
        select jsonb_agg(rg.role order by rg.role)
        from private.safra_role_grants rg
        where rg.principal_id = p.id and rg.revoked_at is null
      ), '[]'::jsonb),
      'cards', coalesce((
        select jsonb_agg(sc.code order by sc.code)
        from public.scenario_owners so join public.scenarios sc on sc.id = so.scenario_id
        where so.owner_id = p.id and so.valid_to is null
      ), '[]'::jsonb)
    ) order by p.display_name)
    from private.safra_principals p
    left join auth.users u on u.id = p.user_id
  ), '[]'::jsonb),
    -- pessoas que já entraram e não estão no cadastro (usuários comuns que abrem protocolo)
    'logins_without_registration',
    (select count(*) from auth.users u
     where not exists (select 1 from private.safra_principals p where p.user_id = u.id)));
end;
$$;

revoke all on function public.safra_admin_get_people() from public, anon;
grant execute on function public.safra_admin_get_people() to authenticated, service_role;

-- 3. Uso das telas, anônimo (D-124, D-90) --------------------------------------------------
create table public.screen_views_daily (
  day date not null,
  route text not null,
  views integer not null default 0,
  primary key (day, route),
  constraint screen_views_route_check check (route in (
    '/', '/meus-protocolos', '/protocolos-dos-meus-cards', '/todos-os-protocolos',
    '/cards-e-donos', '/analytics', '/administracao'
  )),
  constraint screen_views_positive check (views >= 0)
);

alter table public.screen_views_daily enable row level security;
revoke all on public.screen_views_daily from public, anon, authenticated;

comment on table public.screen_views_daily is
  'D-124/D-90: anonymous screen usage, one counter per day and screen; no user is stored.';

create or replace function public.safra_log_screen_view(p_route text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_route text := nullif(btrim(coalesce(p_route, '')), '');
begin
  if (select auth.uid()) is null or not coalesce(public.safra_is_corporate_user(), false) then
    return;
  end if;
  if v_route is null or v_route not in (
    '/', '/meus-protocolos', '/protocolos-dos-meus-cards', '/todos-os-protocolos',
    '/cards-e-donos', '/analytics', '/administracao'
  ) then
    return; -- tela desconhecida: ignora, sem erro para a pessoa
  end if;

  insert into public.screen_views_daily(day, route, views)
  values ((clock_timestamp() at time zone 'America/Sao_Paulo')::date, v_route, 1)
  on conflict (day, route) do update set views = public.screen_views_daily.views + 1;
end;
$$;

revoke all on function public.safra_log_screen_view(text) from public, anon;
grant execute on function public.safra_log_screen_view(text) to authenticated, service_role;

create or replace function public.safra_admin_get_screen_usage(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_from date := (clock_timestamp() at time zone 'America/Sao_Paulo')::date - greatest(1, least(coalesce(p_days, 30), 365)) + 1;
begin
  if (select auth.uid()) is null
     or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_platform_admin')
  then
    raise exception using errcode = '42501', message = 'SAFRA_ADMIN_FORBIDDEN';
  end if;

  return jsonb_build_object(
    'from', v_from,
    'routes', coalesce((
      select jsonb_agg(jsonb_build_object('route', x.route, 'views', x.views, 'today', x.today) order by x.views desc)
      from (
        select s.route, sum(s.views) as views,
               sum(s.views) filter (where s.day = (clock_timestamp() at time zone 'America/Sao_Paulo')::date) as today
        from public.screen_views_daily s
        where s.day >= v_from
        group by s.route
      ) x
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.safra_admin_get_screen_usage(integer) from public, anon;
grant execute on function public.safra_admin_get_screen_usage(integer) to authenticated, service_role;

commit;
