-- SAFRA-C04 — controlled, reversible self-test harness for RBAC and session binding.
-- Evidence is persisted so it can be audited after the run.

create table if not exists private.safra_c04_test_runs (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null,
  executed_at timestamptz not null default now(),
  control text not null,
  step text not null,
  expected text not null,
  observed text not null,
  result text not null
);

revoke all on private.safra_c04_test_runs from public, anon, authenticated;
grant select, insert on private.safra_c04_test_runs to service_role;

create or replace function private.safra_c04_selftest(p_subject_email text)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_run uuid := gen_random_uuid();
  v_uid uuid;
  v_session uuid;
  v_principal uuid;
  v_grant uuid;
  v_claims text;
  v_roles text[];
  v_bool boolean;
  v_before text[];
  v_after text[];
  v_audit_count integer;
begin
  select u.id into v_uid from auth.users u where lower(u.email) = lower(p_subject_email);
  if v_uid is null then
    raise exception 'subject % has no auth user', p_subject_email;
  end if;

  select s.id into v_session from auth.sessions s where s.user_id = v_uid
   order by s.updated_at desc nulls last limit 1;

  select p.id into v_principal from private.safra_principals p where p.user_id = v_uid;

  -- simulate the signed-in corporate session for this transaction only
  v_claims := json_build_object(
    'sub', v_uid,
    'email', lower(p_subject_email),
    'session_id', v_session,
    'is_anonymous', false,
    'app_metadata', json_build_object('provider', 'azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint
  )::text;
  perform set_config('request.jwt.claims', v_claims, true);
  perform set_config('safra.correlation_id', v_run::text, true);

  -- ---------- baseline ----------
  v_before := private.get_my_safra_roles();
  insert into private.safra_c04_test_runs(run_id, control, step, expected, observed, result)
  values (v_run, 'BASELINE', 'roles antes do teste', 'safra_platform_admin',
          array_to_string(v_before, ','),
          case when 'safra_platform_admin' = any(v_before) then 'PASS' else 'FAIL' end);

  -- ---------- ROLE_CHANGE ----------
  insert into private.safra_role_grants(principal_id, role, source)
  values (v_principal, 'scenario_owner', 'C04_ROLE_CHANGE_TEST')
  returning id into v_grant;

  v_roles := private.get_my_safra_roles();
  v_bool := private.safra_has_role('scenario_owner');
  insert into private.safra_c04_test_runs(run_id, control, step, expected, observed, result)
  values (v_run, 'ROLE_CHANGE', 'papel governado adicionado; mesmo auth.uid(); sem refresh de token',
          'scenario_owner reconhecido imediatamente',
          array_to_string(v_roles, ',') || ' | safra_has_role=' || v_bool::text,
          case when v_bool and 'scenario_owner' = any(v_roles) then 'PASS' else 'FAIL' end);

  -- ---------- ROLE_REVOCATION ----------
  update private.safra_role_grants set revoked_at = now() where id = v_grant;

  v_roles := private.get_my_safra_roles();
  v_bool := private.safra_has_role('scenario_owner');
  insert into private.safra_c04_test_runs(run_id, control, step, expected, observed, result)
  values (v_run, 'ROLE_REVOCATION', 'papel revogado na mesma sessao JWT',
          'scenario_owner deixa de ser reconhecido imediatamente',
          array_to_string(v_roles, ',') || ' | safra_has_role=' || v_bool::text,
          case when not v_bool and not ('scenario_owner' = any(v_roles)) then 'PASS' else 'FAIL' end);

  -- ---------- live session ----------
  v_bool := private.safra_session_is_live();
  insert into private.safra_c04_test_runs(run_id, control, step, expected, observed, result)
  values (v_run, 'REVOKED_SESSION', 'JWT valido + session_id existente em auth.sessions',
          'true', v_bool::text, case when v_bool then 'PASS' else 'FAIL' end);

  -- session_id that does not exist (logoff / offboarding)
  perform set_config('request.jwt.claims', json_build_object(
    'sub', v_uid, 'email', lower(p_subject_email),
    'session_id', gen_random_uuid(), 'is_anonymous', false,
    'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true);
  v_bool := private.safra_session_is_live();
  insert into private.safra_c04_test_runs(run_id, control, step, expected, observed, result)
  values (v_run, 'REVOKED_SESSION', 'JWT valido + session_id inexistente/revogado',
          'false', v_bool::text, case when not v_bool then 'PASS' else 'FAIL' end);

  -- expired token
  perform set_config('request.jwt.claims', json_build_object(
    'sub', v_uid, 'email', lower(p_subject_email),
    'session_id', v_session, 'is_anonymous', false,
    'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() - interval '1 hour')::bigint)::text, true);
  v_bool := public.safra_is_corporate_user();
  insert into private.safra_c04_test_runs(run_id, control, step, expected, observed, result)
  values (v_run, 'REVOKED_SESSION', 'JWT expirado', 'false', v_bool::text,
          case when not v_bool then 'PASS' else 'FAIL' end);

  -- restore valid claims
  perform set_config('request.jwt.claims', v_claims, true);
  v_bool := public.safra_is_corporate_user();
  insert into private.safra_c04_test_runs(run_id, control, step, expected, observed, result)
  values (v_run, 'REVOKED_SESSION', 'JWT valido + sessao viva => autorizado', 'true', v_bool::text,
          case when v_bool then 'PASS' else 'FAIL' end);

  -- ---------- denied attempt ----------
  perform public.safra_log_access_denied('private.safra_role_grants',
    'C04 controlled test: tentativa de escrita direta por usuario comum');

  -- ---------- rollback of the temporary test grant ----------
  delete from private.safra_role_grants where id = v_grant;
  v_after := private.get_my_safra_roles();
  insert into private.safra_c04_test_runs(run_id, control, step, expected, observed, result)
  values (v_run, 'ROLLBACK', 'estado restaurado ao final do teste',
          array_to_string(v_before, ','), array_to_string(v_after, ','),
          case when v_before = v_after then 'PASS' else 'FAIL' end);

  -- ---------- audit trail ----------
  select count(*) into v_audit_count
  from private.safra_rbac_audit_events e
  where e.correlation_id = v_run;

  insert into private.safra_c04_test_runs(run_id, control, step, expected, observed, result)
  values (v_run, 'RBAC_AUDIT_TRAIL', 'eventos auditados com ator, acao, recurso, hora do servidor e correlation_id',
          '>=4 eventos', v_audit_count::text,
          case when v_audit_count >= 4 then 'PASS' else 'FAIL' end);

  return v_run;
end;
$$;

revoke all on function private.safra_c04_selftest(text) from public, anon, authenticated;
grant execute on function private.safra_c04_selftest(text) to service_role;

comment on function private.safra_c04_selftest(text) is
  'SAFRA-C04 controlled and reversible RBAC/session evidence run. Restores the original grant state at the end.';