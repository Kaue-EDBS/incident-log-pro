-- SAFRA-C04 — role mapping + corporate authorization + RLS
-- Canonical migration source: supabase/migrations
-- Captures live changes validated on 2026-09-25.

create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;
grant usage on schema private to authenticated, service_role;

create table if not exists private.safra_principals (
  id uuid primary key default gen_random_uuid(),
  corporate_email text not null unique,
  user_id uuid unique references auth.users(id) on delete set null,
  display_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint safra_principals_email_lowercase
    check (corporate_email = lower(corporate_email)),
  constraint safra_principals_corporate_email
    check (corporate_email like '%@editoradobrasil.com.br')
);

create table if not exists private.safra_role_grants (
  id uuid primary key default gen_random_uuid(),
  principal_id uuid not null references private.safra_principals(id) on delete cascade,
  role text not null,
  source text not null default 'PROJECT_DECISION',
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint safra_role_grants_role_check
    check (role in (
      'safra_platform_admin',
      'safra_governance_admin',
      'safra_executive_admin',
      'scenario_owner'
    )),
  constraint safra_role_grants_revoke_order
    check (revoked_at is null or revoked_at >= granted_at)
);

create unique index if not exists safra_role_grants_active_unique
  on private.safra_role_grants(principal_id, role)
  where revoked_at is null;

alter table private.safra_principals enable row level security;
alter table private.safra_role_grants enable row level security;

revoke all on private.safra_principals from public, anon, authenticated;
revoke all on private.safra_role_grants from public, anon, authenticated;
grant select, insert, update, delete on private.safra_principals to service_role;
grant select, insert, update, delete on private.safra_role_grants to service_role;

insert into private.safra_principals (corporate_email, display_name)
values
  ('kaue.pastrello@editoradobrasil.com.br', 'Kaue Pastrello'),
  ('amanda.bueno@editoradobrasil.com.br', 'Amanda Bueno'),
  ('vinicius.moraes@editoradobrasil.com.br', 'Vinicius Moraes'),
  ('joao.jurado@editoradobrasil.com.br', 'Joao Jurado'),
  ('jair.silva@editoradobrasil.com.br', 'Jair Silva'),
  ('bruno.palhao@editoradobrasil.com.br', 'Bruno Palhao'),
  ('daniel.garcia@editoradobrasil.com.br', 'Daniel Garcia'),
  ('jiane.rodrigues@editoradobrasil.com.br', 'Jiane Rodrigues'),
  ('renato.paulo@editoradobrasil.com.br', 'Renato de Paulo')
on conflict (corporate_email) do update
set display_name = excluded.display_name,
    updated_at = now();

with grants(email, role) as (
  values
    ('kaue.pastrello@editoradobrasil.com.br', 'safra_platform_admin'),
    ('amanda.bueno@editoradobrasil.com.br', 'safra_platform_admin'),
    ('vinicius.moraes@editoradobrasil.com.br', 'safra_platform_admin'),
    ('joao.jurado@editoradobrasil.com.br', 'safra_platform_admin'),
    ('jair.silva@editoradobrasil.com.br', 'safra_governance_admin'),
    ('bruno.palhao@editoradobrasil.com.br', 'safra_executive_admin'),
    ('daniel.garcia@editoradobrasil.com.br', 'scenario_owner'),
    ('jiane.rodrigues@editoradobrasil.com.br', 'scenario_owner'),
    ('renato.paulo@editoradobrasil.com.br', 'scenario_owner')
)
insert into private.safra_role_grants (principal_id, role)
select p.id, g.role
from grants g
join private.safra_principals p on p.corporate_email = g.email
where not exists (
  select 1
  from private.safra_role_grants rg
  where rg.principal_id = p.id
    and rg.role = g.role
    and rg.revoked_at is null
);

update private.safra_principals p
set user_id = u.id,
    updated_at = now()
from auth.users u
where lower(u.email) = p.corporate_email
  and p.user_id is distinct from u.id;

create or replace function private.bind_safra_principal_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is not null then
    update private.safra_principals
       set user_id = new.id,
           updated_at = now()
     where corporate_email = lower(new.email)
       and (user_id is null or user_id = new.id);
  end if;
  return new;
end;
$$;

revoke all on function private.bind_safra_principal_from_auth_user() from public, anon, authenticated;

drop trigger if exists trg_bind_safra_principal_from_auth_user on auth.users;
create trigger trg_bind_safra_principal_from_auth_user
after insert or update of email on auth.users
for each row
execute function private.bind_safra_principal_from_auth_user();

create or replace function private.safra_has_role(requested_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and coalesce(
      exists (
        select 1
        from private.safra_principals p
        join private.safra_role_grants rg on rg.principal_id = p.id
        where p.user_id = (select auth.uid())
          and p.is_active
          and rg.revoked_at is null
          and rg.role = requested_role
      ),
      false
    );
$$;

create or replace function private.get_my_safra_roles()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(rg.role order by rg.role), '{}'::text[])
  from private.safra_principals p
  join private.safra_role_grants rg on rg.principal_id = p.id
  where p.user_id = (select auth.uid())
    and p.is_active
    and rg.revoked_at is null;
$$;

revoke all on function private.safra_has_role(text) from public, anon;
revoke all on function private.get_my_safra_roles() from public, anon;
grant execute on function private.safra_has_role(text) to authenticated, service_role;
grant execute on function private.get_my_safra_roles() to authenticated, service_role;

create or replace function public.safra_has_role(requested_role text)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select private.safra_has_role(requested_role);
$$;

create or replace function public.get_my_safra_roles()
returns text[]
language sql
stable
security invoker
set search_path = ''
as $$
  select private.get_my_safra_roles();
$$;

revoke all on function public.safra_has_role(text) from public, anon;
revoke all on function public.get_my_safra_roles() from public, anon;
grant execute on function public.safra_has_role(text) to authenticated, service_role;
grant execute on function public.get_my_safra_roles() to authenticated, service_role;

create or replace function public.safra_is_corporate_user()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and coalesce((select auth.jwt() ->> 'is_anonymous'), 'false') <> 'true'
    and coalesce((select auth.jwt() -> 'app_metadata' ->> 'provider'), '') = 'azure'
    and lower(coalesce((select auth.jwt() ->> 'email'), '')) like '%@editoradobrasil.com.br';
$$;

revoke all on function public.safra_is_corporate_user() from public, anon;
grant execute on function public.safra_is_corporate_user() to authenticated, service_role;

revoke all on public.applications from anon;
revoke all on public.incidents from anon;

revoke all on public.applications from authenticated;
grant select on public.applications to authenticated;

revoke all on public.incidents from authenticated;
grant select, insert, update on public.incidents to authenticated;

drop policy if exists safra_c00_applications_select on public.applications;
drop policy if exists safra_c00_incidents_select on public.incidents;
drop policy if exists safra_c00_incidents_insert on public.incidents;
drop policy if exists safra_c00_incidents_update on public.incidents;

drop policy if exists safra_c04_applications_select on public.applications;
drop policy if exists safra_c04_incidents_select on public.incidents;
drop policy if exists safra_c04_incidents_insert on public.incidents;
drop policy if exists safra_c04_incidents_update on public.incidents;

create policy safra_c04_applications_select
on public.applications
for select
to authenticated
using ((select public.safra_is_corporate_user()));

create policy safra_c04_incidents_select
on public.incidents
for select
to authenticated
using ((select public.safra_is_corporate_user()));

create policy safra_c04_incidents_insert
on public.incidents
for insert
to authenticated
with check ((select public.safra_is_corporate_user()));

create policy safra_c04_incidents_update
on public.incidents
for update
to authenticated
using ((select public.safra_is_corporate_user()))
with check ((select public.safra_is_corporate_user()));

update auth.users
set raw_app_meta_data = raw_app_meta_data - 'safra_access'
where raw_app_meta_data ? 'safra_access';

comment on table private.safra_principals is
  'Governed SAFRA principals pre-provisioned by corporate email and bound to auth.uid() after sign-in.';
comment on table private.safra_role_grants is
  'Application responsibility roles only. A scenario_owner role never grants ownership of a specific scenario.';
comment on function public.safra_has_role(text) is
  'Security-invoker wrapper for governed SAFRA role lookup. Does not confer scenario ownership.';
comment on function public.get_my_safra_roles() is
  'Returns governed SAFRA application roles for current auth.uid(). Does not return scenario ownership.';
comment on function public.safra_is_corporate_user() is
  'Canonical base authorization predicate for SAFRA corporate users.';
