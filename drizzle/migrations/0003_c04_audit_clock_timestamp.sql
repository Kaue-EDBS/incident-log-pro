-- Use statement-independent clock time so audit events inside one transaction keep their real order.
alter table private.safra_rbac_audit_events alter column occurred_at set default clock_timestamp();

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
    private.safra_correlation_id(), coalesce(p_details, '{}'::jsonb), clock_timestamp()
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function private.safra_log_rbac_event(text, text, text, uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function private.safra_log_rbac_event(text, text, text, uuid, text, text, jsonb)
  to service_role;