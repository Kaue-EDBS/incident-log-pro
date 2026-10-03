-- D-141 (03/10/2026): correções da prova completa (auditorias de segurança, dados, operação).
-- S1 nome de exibição só do cadastro (principal) ou da Microsoft (auth.identities, que a pessoa não
--    edita); antes vinha também de user_metadata, que a pessoa pode trocar pela API e se passar
--    por outra em e-mails e telas. Sem quebras de linha e no máximo 120 caracteres.
-- S2 registro técnico: conta não corporativa só registra LOGIN_DENIED, sem detalhe.
-- S3 TRUNCATE retirado do service_role nas tabelas criadas depois do C05 (inclui os históricos que
--    só aceitam acréscimo; gatilho de linha não dispara em TRUNCATE).
-- S4 função de envio exige uma senha interna gerada no próprio banco (Vault), enviada só pelo
--    agendador; quem chamar sem ela recebe 401. Sem senha cadastrada (CI/local), segue aberta.
-- D1 ação da governança enviada duas vezes (duplo clique, rede) vira uma só.
-- O1 Saúde do sistema ganha alarmes: envio de e-mail parado, agendamentos ausentes e protocolo
--    passando de 72 h (o cancelamento automático parou).
-- O2 private.safra_ensure_cron_jobs(): recria os 3 agendamentos (uso após restauração, runbook §4.5).
begin;

-- S1 ------------------------------------------------------------------------------------------
create or replace function private.safra_user_display_name(p_user_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select left(btrim(regexp_replace(coalesce(
    (select nullif(btrim(p.display_name), '') from private.safra_principals p where p.user_id = u.id),
    (select nullif(btrim(coalesce(i.identity_data->>'full_name', i.identity_data->>'name')), '')
       from auth.identities i
      where i.user_id = u.id and i.provider = 'azure'
      order by i.created_at
      limit 1),
    lower(u.email)
  ), '[[:cntrl:]]+', ' ', 'g')), 120)
  from auth.users u
  where u.id = p_user_id;
$$;

-- S2 ------------------------------------------------------------------------------------------
create or replace function public.safra_log_ops_event(
  p_kind text,
  p_route text default null,
  p_code text default null,
  p_duration_ms integer default null,
  p_detail jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_detail jsonb := coalesce(p_detail, '{}'::jsonb);
  v_corporate boolean;
begin
  -- anon não tem permissão de executar; sessão sem usuário não registra.
  if v_actor is null then
    return;
  end if;

  if p_kind is null or p_kind <> all (array['CLIENT_ERROR','SLOW_RESPONSE','LOGIN_DENIED','ACTION_FAILED']) then
    raise exception using errcode = '22023', message = 'SAFRA_OPS_EVENT_INVALID_KIND';
  end if;

  -- Conta fora da Editora só registra a própria recusa de acesso, sem detalhe (D-141).
  v_corporate := coalesce(public.safra_is_corporate_user(), false);
  if not v_corporate then
    if p_kind <> 'LOGIN_DENIED' then
      return;
    end if;
    v_detail := '{}'::jsonb;
  end if;

  -- Retenção de 90 dias (D-95), limpa aos poucos a cada registro.
  delete from public.ops_events
  where id in (
    select id from public.ops_events
    where occurred_at < clock_timestamp() - interval '90 days'
    limit 500
  );

  -- Limite de volume: até 30 eventos por pessoa por minuto; o excesso é descartado.
  if (select count(*) from public.ops_events e
      where e.actor_user_id = v_actor and e.occurred_at > clock_timestamp() - interval '1 minute') >= 30 then
    return;
  end if;

  -- Nunca guardar segredos: tokens JWT, chaves do Supabase ou senhas.
  if v_detail::text ~* '(eyJ[A-Za-z0-9_-]{10,}|sb_secret_|sb_publishable_|service_role|password|senha|bearer)' then
    v_detail := jsonb_build_object('redacted', true);
  end if;
  if length(v_detail::text) > 2000 then
    v_detail := jsonb_build_object('truncated', true);
  end if;

  insert into public.ops_events(kind, actor_user_id, route, code, duration_ms, detail)
  values (
    p_kind,
    v_actor,
    left(nullif(btrim(coalesce(p_route, '')), ''), 200),
    case when v_corporate then left(nullif(btrim(coalesce(p_code, '')), ''), 100) else 'NOT_CORPORATE' end,
    case when p_duration_ms between 0 and 600000 then p_duration_ms end,
    v_detail
  );
end;
$$;

-- S3 ------------------------------------------------------------------------------------------
revoke truncate on public.ops_events from service_role;
revoke truncate on public.treatment_analytics_exclusions from service_role;
revoke truncate on public.safra_seasons from service_role;
revoke truncate on public.safra_season_events from service_role;
revoke truncate on public.screen_views_daily from service_role;
revoke truncate on public.scenario_proposal_events from service_role;

-- S4 ------------------------------------------------------------------------------------------
-- A senha nasce no banco (ninguém a vê nem a digita) e só existe onde o login do owner existe.
do $$
begin
  if exists (select 1 from auth.users where lower(email) = 'kaue.pastrello@editoradobrasil.com.br')
     and not exists (select 1 from vault.secrets where name = 'safra_sender_token') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'safra_sender_token',
                                'D-141: senha interna do agendador para a função safra-send-notifications');
  end if;
end;
$$;

-- A função de envio (service_role) confere a senha recebida; sem senha cadastrada, aceita.
create or replace function public.safra_sender_token_valid(p_token text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when not exists (select 1 from vault.decrypted_secrets where name = 'safra_sender_token') then true
           else coalesce(p_token, '') = (select decrypted_secret from vault.decrypted_secrets
                                         where name = 'safra_sender_token' limit 1)
         end
$$;

revoke all on function public.safra_sender_token_valid(text) from public, anon, authenticated;
grant execute on function public.safra_sender_token_valid(text) to service_role;

-- O2 ------------------------------------------------------------------------------------------
-- Recria os 3 agendamentos (idempotente). O de e-mail só onde o login do owner existe (produção);
-- usado também depois de restaurar um backup (runbook §4.5).
create or replace function private.safra_ensure_cron_jobs()
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_jobs text[];
begin
  perform cron.unschedule(j.jobname) from cron.job j
   where j.jobname in ('safra-auto-cancel-72h', 'safra-cron-log-cleanup', 'safra-send-notifications');

  perform cron.schedule('safra-auto-cancel-72h', '*/10 * * * *', 'select private.safra_auto_cancel_stale()');
  perform cron.schedule('safra-cron-log-cleanup', '17 3 * * *',
    $job$delete from cron.job_run_details where end_time < now() - interval '7 days'$job$);

  if exists (select 1 from auth.users where lower(email) = 'kaue.pastrello@editoradobrasil.com.br') then
    perform cron.schedule('safra-send-notifications', '*/2 * * * *', $job$
      select net.http_post(
        url := 'https://trqkwqkjjjeppuddwenu.supabase.co/functions/v1/safra-send-notifications',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-safra-sender-token', coalesce((select decrypted_secret from vault.decrypted_secrets
                                            where name = 'safra_sender_token' limit 1), '')),
        body := '{}'::jsonb,
        timeout_milliseconds := 60000
      )
    $job$);
  end if;

  select coalesce(array_agg(j.jobname order by j.jobname), '{}') into v_jobs from cron.job j
   where j.jobname like 'safra-%';
  return v_jobs;
end;
$$;

revoke all on function private.safra_ensure_cron_jobs() from public, anon, authenticated;

select private.safra_ensure_cron_jobs();

-- D1 ------------------------------------------------------------------------------------------
create unique index if not exists uq_governance_actions_no_duplicate
  on public.governance_actions(week_start,
                               coalesce(scenario_id, '00000000-0000-0000-0000-000000000000'::uuid),
                               action_type, md5(description));

create or replace function public.safra_register_governance_action(
  p_week_start date,
  p_scenario_id uuid,
  p_action_type text,
  p_description text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
  v_week date := private.safra_week_start(p_week_start);
  v_id uuid;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false)
     or not coalesce(private.safra_is_governance_viewer(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_GOVERNANCE_FORBIDDEN';
  end if;
  if p_action_type is null or p_action_type not in ('PROCESS_CHANGE', 'MASTER_DATA_FIX', 'CAPACITY_CHANGE',
       'PARTNER_ACTION', 'SYSTEM_CHANGE', 'TRAINING', 'NO_ACTION_JUSTIFIED') then
    raise exception using errcode = '22023', message = 'SAFRA_GOVERNANCE_INVALID_TYPE';
  end if;
  if v_description is null or length(v_description) < 10 or length(v_description) > 1000 then
    raise exception using errcode = '22023', message = 'SAFRA_GOVERNANCE_DESCRIPTION_REQUIRED';
  end if;
  if p_scenario_id is not null and not exists (select 1 from public.scenarios sc where sc.id = p_scenario_id) then
    raise exception using errcode = '22023', message = 'SAFRA_GOVERNANCE_INVALID_CARD';
  end if;

  insert into public.governance_actions(week_start, scenario_id, action_type, description, created_by)
  values (v_week, p_scenario_id, p_action_type, v_description, v_actor)
  on conflict do nothing
  returning id into v_id;

  if v_id is null then
    -- mesma ação, mesma semana e mesmo card: devolve a que já existe (duplo clique, rede)
    select ga.id into v_id from public.governance_actions ga
     where ga.week_start = v_week
       and coalesce(ga.scenario_id, '00000000-0000-0000-0000-000000000000'::uuid)
           = coalesce(p_scenario_id, '00000000-0000-0000-0000-000000000000'::uuid)
       and ga.action_type = p_action_type and md5(ga.description) = md5(v_description);
  end if;
  return v_id;
end;
$$;

-- O1 ------------------------------------------------------------------------------------------
create or replace function public.safra_admin_get_ops_summary(p_hours integer default 24)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_actor uuid := (select auth.uid());
  v_since timestamptz := clock_timestamp() - make_interval(hours => greatest(1, least(coalesce(p_hours, 24), 2160)));
  v_oldest_queued timestamptz;
  v_last_sent timestamptz;
  v_jobs text[];
  v_last_http integer;
  v_overdue integer;
  v_alerts jsonb := '[]'::jsonb;
begin
  if v_actor is null
     or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_platform_admin')
  then
    raise exception using errcode = '42501', message = 'SAFRA_OPS_FORBIDDEN';
  end if;

  select min(queued_at) into v_oldest_queued from public.notifications_log where delivery_status = 'QUEUED';
  select max(sent_at) into v_last_sent from public.notifications_log;
  select coalesce(array_agg(jobname order by jobname), '{}') into v_jobs from cron.job where jobname like 'safra-%';
  select r.status_code into v_last_http from net._http_response r order by r.created desc limit 1;
  select count(*) into v_overdue from public.treatments
   where status = 'ACTIVE' and opened_at < clock_timestamp() - interval '72 hours 20 minutes';

  -- Alarmes (D-141): quem olha a Saúde do sistema vê na hora o que parou.
  if v_oldest_queued is not null and v_oldest_queued < clock_timestamp() - interval '10 minutes' then
    v_alerts := v_alerts || jsonb_build_object('code', 'EMAIL_STALLED',
      'text', 'Há e-mail na fila há mais de 10 minutos: o envio automático pode ter parado.');
  end if;
  if not ('safra-auto-cancel-72h' = any (v_jobs)) then
    v_alerts := v_alerts || jsonb_build_object('code', 'JOB_MISSING_72H',
      'text', 'O agendamento do encerramento/cancelamento automático de 72 h não existe.');
  end if;
  -- Só onde o envio existe de verdade (produção: senha interna cadastrada).
  if exists (select 1 from vault.secrets where name = 'safra_sender_token')
     and not ('safra-send-notifications' = any (v_jobs)) then
    v_alerts := v_alerts || jsonb_build_object('code', 'JOB_MISSING_EMAIL',
      'text', 'O agendamento do envio de e-mails não existe.');
  end if;
  if v_last_http is not null and v_last_http <> 200 then
    v_alerts := v_alerts || jsonb_build_object('code', 'EMAIL_FUNCTION_ERROR',
      'text', 'A última chamada à função de envio respondeu ' || v_last_http || '.');
  end if;
  if v_overdue > 0 then
    v_alerts := v_alerts || jsonb_build_object('code', 'PROTOCOL_OVERDUE',
      'text', v_overdue || ' protocolo(s) passaram de 72 h sem encerrar: o automático pode ter parado.');
  end if;

  return jsonb_build_object(
    'since', v_since,
    'server_time', clock_timestamp(),
    'alerts', v_alerts,
    'events_by_kind', coalesce((
      select jsonb_object_agg(kind, n) from (
        select kind, count(*) n from public.ops_events where occurred_at >= v_since group by kind
      ) x
    ), '{}'::jsonb),
    'slow_p95_ms', (
      select percentile_disc(0.95) within group (order by duration_ms)
      from public.ops_events where occurred_at >= v_since and kind = 'SLOW_RESPONSE'
    ),
    'protocols', jsonb_build_object(
      'opened', (select count(*) from public.treatments where opened_at >= v_since),
      'resolved', (select count(*) from public.treatments where closed_at >= v_since),
      'cancelled', (select count(*) from public.treatments where cancelled_at >= v_since),
      'auto_cancelled', (select count(*) from public.treatments where cancelled_at >= v_since and auto_cancelled),
      'auto_resolved', (select count(*) from public.treatments where closed_at >= v_since and auto_resolved),
      'active_now', (select count(*) from public.treatments where status = 'ACTIVE'),
      'oldest_active_opened_at', (select min(opened_at) from public.treatments where status = 'ACTIVE')
    ),
    'notifications', jsonb_build_object(
      'queued', (select count(*) from public.notifications_log where delivery_status = 'QUEUED'),
      'sent', (select count(*) from public.notifications_log where sent_at >= v_since),
      'failed', (select count(*) from public.notifications_log where failed_at >= v_since and failure_reason not like 'EXPIRED%'),
      'expired', (select count(*) from public.notifications_log where failed_at >= v_since and failure_reason like 'EXPIRED%'),
      'oldest_queued_at', v_oldest_queued,
      'last_sent_at', v_last_sent,
      'last_function_status', v_last_http
    ),
    'jobs', to_jsonb(v_jobs),
    'recent', coalesce((
      select jsonb_agg(jsonb_build_object(
        'occurred_at', e.occurred_at, 'kind', e.kind, 'route', e.route, 'code', e.code,
        'duration_ms', e.duration_ms, 'actor_user_id', e.actor_user_id, 'detail', e.detail
      ) order by e.occurred_at desc)
      from (select * from public.ops_events where occurred_at >= v_since order by occurred_at desc limit 100) e
    ), '[]'::jsonb)
  );
end;
$fn$;

commit;
