-- SAFRA-C02-AUD — threat-model authorization hardening
-- Migration filename scaffolded by Supabase CLI on 2026-09-27.
-- Scope: close RBAC RPC session bypass and remove unnecessary legacy trigger-function EXECUTE.

begin;

create or replace function private.safra_has_role(requested_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select public.safra_is_corporate_user())
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
  select case
    when not (select public.safra_is_corporate_user()) then '{}'::text[]
    else coalesce(
      (
        select array_agg(rg.role order by rg.role)
        from private.safra_principals p
        join private.safra_role_grants rg on rg.principal_id = p.id
        where p.user_id = (select auth.uid())
          and p.is_active
          and rg.revoked_at is null
      ),
      '{}'::text[]
    )
  end;
$$;

create or replace function public.get_safra_rbac_audit_events(p_limit integer default 100)
returns table (
  occurred_at timestamptz,
  actor_email text,
  action text,
  resource text,
  target_principal_email text,
  target_role text,
  result text,
  correlation_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select e.occurred_at, e.actor_email, e.action, e.resource,
         e.target_principal_email, e.target_role, e.result, e.correlation_id
  from private.safra_rbac_audit_events e
  where (select public.safra_is_corporate_user())
    and (
      private.safra_has_role('safra_platform_admin')
      or private.safra_has_role('safra_governance_admin')
    )
  order by e.occurred_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 1000));
$$;

revoke all on function private.safra_has_role(text) from public, anon;
revoke all on function private.get_my_safra_roles() from public, anon;
grant execute on function private.safra_has_role(text) to authenticated, service_role;
grant execute on function private.get_my_safra_roles() to authenticated, service_role;

revoke all on function public.get_safra_rbac_audit_events(integer) from public, anon;
grant execute on function public.get_safra_rbac_audit_events(integer) to authenticated, service_role;

-- Legacy trigger helpers do not need to be directly callable from browser roles.
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.validate_incident_timestamps() from public, anon, authenticated;

comment on function private.safra_has_role(text) is
  'Governed role lookup. Returns true only for a live canonical corporate session bound to an active principal with an active role grant.';

comment on function private.get_my_safra_roles() is
  'Returns governed SAFRA roles only while the canonical corporate live-session predicate is true; otherwise returns an empty array.';

comment on function public.get_safra_rbac_audit_events(integer) is
  'Read-only RBAC audit endpoint restricted to live canonical corporate sessions with platform/governance admin role.';

commit;
