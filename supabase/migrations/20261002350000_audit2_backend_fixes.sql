-- Auditoria 2 (02/10/2026, D-137): correções de backend.
-- B1 uma proposta em andamento por pessoa também com dois envios ao mesmo tempo (índice único).
-- B2 rodada sem tempo devolve o aviso sem gastar tentativa; envio confirmado sempre vale.
-- B3 aprovar e publicar conferem se o dono escolhido continua disponível (mensagem clara).
-- B6 lembrete para quem já concluiu a sua parte não sai.
-- B10 índices para a fila de e-mails (totais e lista por data).
begin;

create unique index if not exists uq_scenario_proposals_one_open_per_person
  on public.scenario_proposals(proposed_by)
  where status not in ('PUBLISHED', 'REJECTED');

create index if not exists idx_notifications_log_queued_at on public.notifications_log(queued_at desc);
create index if not exists idx_notifications_log_sent_at on public.notifications_log(sent_at) where sent_at is not null;
create index if not exists idx_notifications_log_failed_at on public.notifications_log(failed_at) where failed_at is not null;

create or replace function public.safra_notifications_claim(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  -- Não mandar atrasado: lembrete de protocolo já fechado e aviso parado há 24 h expiram.
  -- Aviso pego 5 vezes sem resultado (rodada interrompida): falha, para não travar a fila.
  update public.notifications_log n
     set delivery_status = 'FAILED',
         failure_reason = 'SEND_FAILED: NO_REPORT',
         locked_until = null
   where n.delivery_status = 'QUEUED'
     and n.attempts >= 5
     and (n.locked_until is null or n.locked_until < clock_timestamp());

  update public.notifications_log n
     set delivery_status = 'FAILED',
         failure_reason = 'EXPIRED_PROTOCOL_NOT_ACTIVE'
   where n.delivery_status = 'QUEUED'
     and (n.locked_until is null or n.locked_until < clock_timestamp())
     and n.notification_type like 'REMINDER_%'
     and exists (select 1 from public.treatments t where t.id = n.treatment_id and t.status <> 'ACTIVE');

  update public.notifications_log n
     set delivery_status = 'FAILED',
         failure_reason = 'EXPIRED_TOO_OLD'
   where n.delivery_status = 'QUEUED'
     and (n.locked_until is null or n.locked_until < clock_timestamp())
     and n.queued_at < clock_timestamp() - interval '24 hours';

  -- Lembrete para quem já concluiu a sua parte não sai.
  update public.notifications_log n
     set delivery_status = 'FAILED', failure_reason = 'EXPIRED_PART_ALREADY_CLOSED', locked_until = null
   where n.delivery_status = 'QUEUED'
     and (n.locked_until is null or n.locked_until < clock_timestamp())
     and n.notification_type like 'REMINDER_%'
     and exists (select 1 from public.treatments t
                 where t.id = n.treatment_id
                   and ((n.recipient_role = 'REQUESTER' and t.requester_closed_at is not null)
                     or (n.recipient_role = 'OWNER' and t.owner_closed_at is not null)));

  with picked as (
    select n.id
    from public.notifications_log n
    where n.delivery_status = 'QUEUED'
      and n.next_attempt_at <= clock_timestamp()
      and (n.locked_until is null or n.locked_until < clock_timestamp())
      and n.attempts < 5
    order by n.next_attempt_at, n.queued_at
    limit greatest(1, least(coalesce(p_limit, 20), 100))
    for update skip locked
  ),
  claimed as (
    update public.notifications_log n
       set attempts = n.attempts + 1,
           locked_until = clock_timestamp() + interval '5 minutes',
           claimed_by = null
      from picked
     where n.id = picked.id
    returning n.id, n.recipient_email, n.subject, n.body, n.attempts
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'to', c.recipient_email, 'subject', c.subject, 'body', c.body, 'attempt', c.attempts)), '[]'::jsonb)
    into v_result
  from claimed c;

  return v_result;
end;
$$;

create or replace function public.safra_notifications_claim_for_session(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_staff boolean;
  v_result jsonb;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_DELIVERY_FORBIDDEN';
  end if;
  v_staff := coalesce(private.safra_is_delivery_staff(), false);
  -- D-134: o envio agendado no servidor (D-133) cobre todo mundo; pelo navegador, só a gestão
  -- e os admins (botão "Forçar envio agora"). Ninguém mais pega nem marca avisos.
  if not v_staff then
    raise exception using errcode = '42501', message = 'SAFRA_DELIVERY_FORBIDDEN';
  end if;

  update public.notifications_log n
     set delivery_status = 'FAILED', failure_reason = 'SEND_FAILED: NO_REPORT', locked_until = null
   where n.delivery_status = 'QUEUED'
     and n.attempts >= 5
     and (n.locked_until is null or n.locked_until < clock_timestamp());

  -- Mesmas regras de validade do carteiro oficial: não mandar atrasado.
  update public.notifications_log n
       set delivery_status = 'FAILED', failure_reason = 'EXPIRED_PROTOCOL_NOT_ACTIVE'
     where n.delivery_status = 'QUEUED'
       and (n.locked_until is null or n.locked_until < clock_timestamp())
       and n.notification_type like 'REMINDER_%'
       and exists (select 1 from public.treatments t where t.id = n.treatment_id and t.status <> 'ACTIVE');
  update public.notifications_log n
       set delivery_status = 'FAILED', failure_reason = 'EXPIRED_TOO_OLD'
     where n.delivery_status = 'QUEUED'
       and (n.locked_until is null or n.locked_until < clock_timestamp())
       and n.queued_at < clock_timestamp() - interval '24 hours';

  -- Lembrete para quem já concluiu a sua parte não sai.
  update public.notifications_log n
     set delivery_status = 'FAILED', failure_reason = 'EXPIRED_PART_ALREADY_CLOSED', locked_until = null
   where n.delivery_status = 'QUEUED'
     and (n.locked_until is null or n.locked_until < clock_timestamp())
     and n.notification_type like 'REMINDER_%'
     and exists (select 1 from public.treatments t
                 where t.id = n.treatment_id
                   and ((n.recipient_role = 'REQUESTER' and t.requester_closed_at is not null)
                     or (n.recipient_role = 'OWNER' and t.owner_closed_at is not null)));

  with picked as (
    select n.id
    from public.notifications_log n
    where n.delivery_status = 'QUEUED'
      and n.next_attempt_at <= clock_timestamp()
      and n.queued_at >= clock_timestamp() - interval '24 hours'
      and (n.locked_until is null or n.locked_until < clock_timestamp())
      and n.attempts < 5
    order by n.next_attempt_at, n.queued_at
    limit greatest(1, least(coalesce(p_limit, 20), 20))
    for update skip locked
  ),
  claimed as (
    update public.notifications_log n
       set attempts = n.attempts + 1,
           locked_until = clock_timestamp() + interval '5 minutes',
           claimed_by = v_actor
      from picked
     where n.id = picked.id
    returning n.id, n.recipient_email, n.subject, n.body, n.attempts
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'to', c.recipient_email, 'subject', c.subject, 'body', c.body, 'attempt', c.attempts)), '[]'::jsonb)
    into v_result
  from claimed c;

  return v_result;
end;
$$;

create or replace function public.safra_notifications_report(p_id uuid, p_ok boolean, p_error text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n public.notifications_log%rowtype;
begin
  select * into v_n from public.notifications_log where id = p_id for update;
  if not found or v_n.delivery_status <> 'QUEUED' then
    return;
  end if;
  -- Envio confirmado sempre vale (evita e-mail repetido). Falha só vale enquanto a rodada que
  -- pegou o aviso ainda o segura (resultado atrasado de rodada vencida não conta).
  if not p_ok and (v_n.locked_until is null or v_n.locked_until < clock_timestamp()) then
    return;
  end if;
  -- Rodada sem tempo para tentar: devolve o aviso sem gastar tentativa.
  if not p_ok and p_error = 'ROUND_TIME_BUDGET' then
    update public.notifications_log
       set attempts = greatest(attempts - 1, 0), locked_until = null
     where id = p_id;
    return;
  end if;

  if p_ok then
    update public.notifications_log set delivery_status = 'SENT', locked_until = null, last_error = null where id = p_id;
  elsif v_n.attempts >= 5 then
    update public.notifications_log
       set delivery_status = 'FAILED',
           failure_reason = left('SEND_FAILED: ' || coalesce(nullif(btrim(p_error), ''), 'unknown'), 500),
           locked_until = null
     where id = p_id;
  else
    -- nova tentativa com espera crescente: 2, 4, 8, 16 minutos
    update public.notifications_log
       set last_error = left(coalesce(nullif(btrim(p_error), ''), 'unknown'), 500),
           locked_until = null,
           next_attempt_at = clock_timestamp() + make_interval(mins => (2 ^ v_n.attempts)::integer)
     where id = p_id;
  end if;
end;
$$;

create or replace function public.safra_submit_proposal(p_title text, p_problem text, p_impact text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_title text := nullif(btrim(coalesce(p_title, '')), '');
  v_problem text := nullif(btrim(coalesce(p_problem, '')), '');
  v_impact text := nullif(btrim(coalesce(p_impact, '')), '');
  v_id uuid;
  v_email text;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_title is null or length(v_title) < 5 or length(v_title) > 150 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_TITLE_REQUIRED';
  end if;
  if v_problem is null or length(v_problem) < 10 or v_impact is null or length(v_impact) < 10 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_DESCRIPTION_REQUIRED';
  end if;
  if length(v_problem) > 3000 or length(v_impact) > 3000 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_TOO_LONG';
  end if;
  -- D-135: uma proposta em andamento por pessoa (a próxima depois de publicada ou recusada).
  if exists (select 1 from public.scenario_proposals sp
             where sp.proposed_by = v_actor and sp.status not in ('PUBLISHED', 'REJECTED')) then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_ONE_OPEN';
  end if;

  select lower(u.email) into v_email from auth.users u where u.id = v_actor;
  begin
    insert into public.scenario_proposals(proposed_by, proposer_name, proposer_email, title, problem_description, safra_impact_description)
    values (v_actor, private.safra_user_display_name(v_actor), v_email, v_title, v_problem, v_impact)
    returning id into v_id;
  exception when unique_violation then
    -- dois envios ao mesmo tempo (duplo clique, duas abas): o índice garante uma por pessoa
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_ONE_OPEN';
  end;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id) values (v_id, 'SUBMITTED', v_actor);

  perform private.safra_enqueue_proposal_notice('PROPOSAL_SUBMITTED', v_id,
    private.safra_principals_json(private.safra_role_principals('safra_governance_admin')), 'PR:' || v_id || ':SUBMITTED');
  return v_id;
end;
$$;

create or replace function public.safra_approve_proposal(p_proposal_id uuid, p_responsible_area_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_p public.scenario_proposals%rowtype;
  v_publishers uuid[];
begin
  select * into v_p from public.scenario_proposals where id = p_proposal_id for update;
  if not found or not coalesce(private.safra_can_approve_proposal(v_p.proposed_by), false) then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_p.status <> 'CONTENT_SUBMITTED' then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_WRONG_STEP';
  end if;
  if not exists (select 1 from public.operational_areas oa where oa.id = p_responsible_area_id) then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_AREA_REQUIRED';
  end if;
  -- O dono escolhido precisa continuar disponível como dono de card (senão a publicação falharia).
  if not coalesce(private.safra_owner_is_available(v_p.owner_principal_id), false) then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_OWNER_UNAVAILABLE';
  end if;

  update public.scenario_proposals
     set status = 'APPROVED', responsible_area_id = p_responsible_area_id,
         approved_at = clock_timestamp(), approved_by = v_actor
   where id = v_p.id;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id) values (v_p.id, 'APPROVED', v_actor);

  -- Avisa quem propôs e os admins que podem publicar (nem quem propôs, nem quem aprovou).
  select coalesce(array_agg(p.id), '{}') into v_publishers
  from private.safra_principals p
  where p.id = any (private.safra_role_principals('safra_platform_admin'))
    and p.user_id is distinct from v_p.proposed_by and p.user_id is distinct from v_actor;
  perform private.safra_enqueue_proposal_notice('PROPOSAL_APPROVED', v_p.id,
    jsonb_build_array(jsonb_build_object('email', v_p.proposer_email, 'name', v_p.proposer_name))
      || private.safra_principals_json(v_publishers),
    'PR:' || v_p.id || ':APPROVED');
end;
$$;

create or replace function public.safra_publish_proposal(p_proposal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_p public.scenario_proposals%rowtype;
  v_number integer;
  v_code text;
  v_scenario uuid;
  v_version uuid;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_platform_admin') then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  select * into v_p from public.scenario_proposals where id = p_proposal_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_p.proposed_by = v_actor or v_p.approved_by = v_actor then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_SEPARATION_OF_DUTIES';
  end if;
  if v_p.status <> 'APPROVED' then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_WRONG_STEP';
  end if;
  -- O dono escolhido precisa continuar disponível como dono de card (senão a publicação falharia).
  if not coalesce(private.safra_owner_is_available(v_p.owner_principal_id), false) then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_OWNER_UNAVAILABLE';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('safra_new_card_number', 0));
  select coalesce(max(substring(code from '^SAFRA-([0-9]+)$')::integer), 0) + 1 into v_number
  from public.scenarios;
  v_code := 'SAFRA-' || case when v_number < 10 then '0' else '' end || v_number::text;

  insert into public.scenarios(code, name, lifecycle_status, responsible_area_id)
  values (v_code, v_p.scenario_name, 'ACTIVE', v_p.responsible_area_id)
  returning id into v_scenario;

  insert into public.scenario_versions(scenario_id, version_no, status, trigger_description, detection_description,
                                       protocol_text, expected_impact_summary, criticality, source_reference, created_by)
  values (v_scenario, 1, 'DRAFT', v_p.trigger_description, v_p.detection_description, v_p.protocol_text,
          v_p.expected_impact_summary, 'CRITICAL', 'M10 proposta ' || v_p.id, v_actor)
  returning id into v_version;

  insert into public.scenario_version_impacted_areas(scenario_version_id, operational_area_id)
  select v_version, a from unnest(v_p.impacted_area_ids) a;

  update public.scenario_versions set status = 'PUBLISHED' where id = v_version;
  update public.scenarios set current_version_id = v_version where id = v_scenario;

  insert into public.scenario_owners(scenario_id, owner_id, assigned_by, assignment_reason)
  values (v_scenario, v_p.owner_principal_id, v_actor, 'M10: dono definido na proposta ' || v_p.id || ' (D-126).');

  update public.scenario_proposals
     set status = 'PUBLISHED', published_at = clock_timestamp(), published_by = v_actor, scenario_id = v_scenario
   where id = v_p.id;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id, note)
  values (v_p.id, 'PUBLISHED', v_actor, v_code);

  perform private.safra_enqueue_proposal_notice('PROPOSAL_PUBLISHED', v_p.id,
    jsonb_build_array(jsonb_build_object('email', v_p.proposer_email, 'name', v_p.proposer_name))
      || private.safra_principals_json(array[v_p.owner_principal_id])
      || private.safra_principals_json(private.safra_role_principals('safra_governance_admin')),
    'PR:' || v_p.id || ':PUBLISHED');

  return jsonb_build_object('scenario_id', v_scenario, 'code', v_code, 'version_no', 1);
end;
$$;

commit;
