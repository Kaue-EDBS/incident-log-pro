-- SAFRA-C04 closeout — RBAC audit trail (AUDIT-001) + live session binding (ID-002)
-- Scope: identity/RBAC/RLS only. No scenarios, treatments, START/END/CANCEL.

create table if not exists private.safra_rbac_audit_events (
  id uuid primary key default gen_random_uuid(),
  occurred_at timestamptz not null default now(),
  actor_user_id uuid,
  actor_email text,
  actor_db_role text not null default current_user,
  action text not null,
  resource text not null,
  target_principal_id uuid,
  target_principal_email text,
  target_role text,
  result text not null,
  correlation_id uuid not null default gen_random_uuid(),
  details jsonb not null default '{}'::jsonb,
  constraint safra_rbac_audit_action_check
    check (action in (
      'ROLE_GRANTED',
      'ROLE_CHANGED',
      'ROLE_REVOKED',
      'ROLE_GRANT_DELETED',
      'PRINCIPAL_CHANGED',
      'ACCESS_DENIED'
    )),
  constraint safra_rbac_audit_result_check
    check (result in ('SUCCESS', 'DENIED', 'ERROR'))
);

create index if not exists safra_rbac_audit_events_occurred_idx
  on private.safra_rbac_audit_events (occurred_at desc);
create index if not exists safra_rbac_audit_events_correlation_idx
  on private.safra_rbac_audit_events (correlation_id);

alter table private.safra_rbac_audit_events enable row level security;

revoke all on private.safra_rbac_audit_events from public, anon, authenticated;
grant select, insert on private.safra_rbac_audit_events to service_role;

create or replace function private.safra_rbac_audit_immutable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'private.safra_rbac_audit_events is append-only';
end;
$$;

drop trigger if exists trg_safra_rbac_audit_immutable on private.safra_rbac_audit_events;
create trigger trg_safra_rbac_audit_immutable
before update or delete on private.safra_rbac_audit_events
for each row execute function private.safra_rbac_audit_immutable();

create or replace function private.safra_correlation_id()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  raw text := nullif(current_setting('safra.correlation_id', true), '');
begin
  return coalesce(raw::uuid, gen_random_uuid());
exception when others then
  return gen_random_uuid();
end;
$$;

create or replace function private.safra_log_rbac_event(
  p_action text,
  p_resource text,
  p_result text,
  p_target_principal_id uuid default null,
  p_target_principal_email text default null,
  p_target_role text default null,
  p_details jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_actor uuid := (select auth.uid());
  v_email text;
begin
  if v_actor is not null then
    select lower(u.email) into v_email from auth.users u where u.id = v_actor;
  end if;

  insert into private.safra_rbac_audit_events (
    actor_user_id, actor_email, actor_db_role, action, resource, result,
    target_principal_id, target_principal_email, target_role,
    correlation_id, details, occurred_at
  )
  values (
    v_actor, v_email, current_user, p_action, p_resource, p_result,
    p_target_principal_id, p_target_principal_email, p_target_role,
    private.safra_correlation_id(), coalesce(p_details, '{}'::jsonb), now()
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function private.safra_log_rbac_event(text, text, text, uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function private.safra_log_rbac_event(text, text, text, uuid, text, text, jsonb)
  to service_role;

create or replace function private.safra_audit_role_grant_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action text;
  v_principal uuid;
  v_role text;
  v_email text;
  v_details jsonb;
begin
  if tg_op = 'INSERT' then
    v_action := 'ROLE_GRANTED';
    v_principal := new.principal_id;
    v_role := new.role;
    v_details := jsonb_build_object('grant_id', new.id, 'source', new.source);
  elsif tg_op = 'UPDATE' then
    v_principal := new.principal_id;
    v_role := new.role;
    if old.revoked_at is null and new.revoked_at is not null then
      v_action := 'ROLE_REVOKED';
    else
      v_action := 'ROLE_CHANGED';
    end if;
    v_details := jsonb_build_object(
      'grant_id', new.id,
      'source', new.source,
      'old_role', old.role,
      'new_role', new.role,
      'old_revoked_at', old.revoked_at,
      'new_revoked_at', new.revoked_at
    );
  else
    v_action := 'ROLE_GRANT_DELETED';
    v_principal := old.principal_id;
    v_role := old.role;
    v_details := jsonb_build_object('grant_id', old.id, 'source', old.source);
  end if;

  select p.corporate_email into v_email
  from private.safra_principals p
  where p.id = v_principal;

  perform private.safra_log_rbac_event(
    v_action,
    'private.safra_role_grants',
    'SUCCESS',
    v_principal,
    v_email,
    v_role,
    v_details
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_safra_audit_role_grant_change on private.safra_role_grants;
create trigger trg_safra_audit_role_grant_change
after insert or update or delete on private.safra_role_grants
for each row execute function private.safra_audit_role_grant_change();

create or replace function public.safra_log_access_denied(
  p_resource text,
  p_reason text default null
)
returns uuid
language sql
volatile
security definer
set search_path = ''
as $$
  select private.safra_log_rbac_event(
    'ACCESS_DENIED',
    p_resource,
    'DENIED',
    null,
    null,
    null,
    jsonb_build_object('reason', left(coalesce(p_reason, ''), 500))
  );
$$;

revoke all on function public.safra_log_access_denied(text, text) from public, anon;
grant execute on function public.safra_log_access_denied(text, text) to authenticated, service_role;

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
  where private.safra_has_role('safra_platform_admin')
     or private.safra_has_role('safra_governance_admin')
  order by e.occurred_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 1000));
$$;

revoke all on function public.get_safra_rbac_audit_events(integer) from public, anon;
grant execute on function public.get_safra_rbac_audit_events(integer) to authenticated, service_role;

create or replace function private.safra_session_is_live()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.sessions s
    where s.id = nullif((select auth.jwt() ->> 'session_id'), '')::uuid
      and s.user_id = (select auth.uid())
      and (s.not_after is null or s.not_after > now())
  );
$$;

revoke all on function private.safra_session_is_live() from public, anon;
grant execute on function private.safra_session_is_live() to authenticated, service_role;

create or replace function public.safra_session_is_live()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select private.safra_session_is_live();
$$;

revoke all on function public.safra_session_is_live() from public, anon;
grant execute on function public.safra_session_is_live() to authenticated, service_role;

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
    and lower(coalesce((select auth.jwt() ->> 'email'), '')) like '%@editoradobrasil.com.br'
    and coalesce((select (auth.jwt() ->> 'exp')::bigint), 0) > extract(epoch from now())::bigint
    and (select private.safra_session_is_live());
$$;

revoke all on function public.safra_is_corporate_user() from public, anon;
grant execute on function public.safra_is_corporate_user() to authenticated, service_role;

comment on table private.safra_rbac_audit_events is
  'AUDIT-001 append-only RBAC audit trail. Actor, action, resource, server-side timestamp, result and correlation_id.';
comment on function public.safra_session_is_live() is
  'ID-002: true only when the JWT session_id still exists in auth.sessions for the current user.';
comment on function public.safra_is_corporate_user() is
  'Canonical SAFRA authorization predicate: corporate Entra identity, unexpired JWT and live server-side session.';
comment on function public.safra_log_access_denied(text, text) is
  'Records a denied access attempt with server-side actor and timestamp.';
comment on function public.get_safra_rbac_audit_events(integer) is
  'Read-only RBAC audit trail access restricted to governed platform/governance admins.';