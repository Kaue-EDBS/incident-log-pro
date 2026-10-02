-- SAFRA-M05/M10 — correções da auditoria de 02/10/2026 (D-134).
-- A1 fila: aviso pego 5 vezes sem resultado vira FAILED (SEND_FAILED: NO_REPORT) em vez de
--    travar a fila inteira (attempts > 5 quebrava o check e abortava todo claim); só pega
--    attempts < 5; a validade (24 h, protocolo encerrado) não mexe em aviso sendo enviado.
-- A2 o resultado do carteiro do servidor só vale enquanto a rodada dele segura o aviso;
--    o claim do servidor limpa claimed_by (resultado de rodada antiga do navegador não vale).
-- A3 D-134: pelo navegador, só gestão/admins pegam a fila (botão "Forçar envio agora"); o envio
--    agendado (D-133) cobre todo mundo. Ninguém mais marca como enviado aviso que não enviou.
-- A4 aviso de proposta cabe no limite de 6.000 caracteres (problema/efeito com até 1.500 cada).
-- A5 donos de card só veem a proposta depois que o Jair encaminhou (antes: recusada sem
--    encaminhar aparecia para eles).
-- A6 número do card com 3 dígitos (SAFRA-100) sem cortar.
-- A7 o agendamento do envio só existe no banco de produção (onde o login do owner existe):
--    o banco descartável do CI e o local não chamam mais a função de produção.
begin;

create or replace function private.safra_excerpt(p_text text, p_max integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when length(coalesce(p_text, '')) <= p_max then coalesce(p_text, '')
              else left(p_text, p_max - 1) || '…' end
$$;

revoke all on function private.safra_excerpt(text, integer) from public, anon, authenticated;

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
  -- Só vale enquanto a rodada que pegou o aviso ainda o segura (evita resultado atrasado
  -- de uma rodada vencida sobre outra rodada).
  if not found or v_n.delivery_status <> 'QUEUED'
     or v_n.locked_until is null or v_n.locked_until < clock_timestamp() then
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

  if v_staff then
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
  end if;

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

create or replace function private.safra_enqueue_proposal_notice(
  p_type text,
  p_proposal_id uuid,
  p_recipients jsonb,  -- [{email, name, principal_id}]
  p_key_prefix text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_p public.scenario_proposals%rowtype;
  v_subject text;
  v_head text;
  v_count integer := 0;
  r record;
begin
  select * into v_p from public.scenario_proposals where id = p_proposal_id;

  case p_type
    when 'PROPOSAL_SUBMITTED' then
      v_subject := 'Nova proposta de card: ' || v_p.title;
      v_head := v_p.proposer_name || ' propôs um card novo. Encaminhe aos donos de card para avaliarem quem assume.';
    when 'PROPOSAL_OWNER_REQUEST' then
      v_subject := 'Você assume o card proposto? ' || v_p.title;
      v_head := 'O Jair pediu que você diga se aceita ser dono deste card novo. Responda no Painel.';
    when 'PROPOSAL_OWNER_DEFINED' then
      v_subject := 'Dono definido para a proposta: ' || v_p.title;
      v_head := 'O dono do card proposto foi definido. Quem propôs completa agora o conteúdo do card no Painel.';
    when 'PROPOSAL_CONTENT_SUBMITTED' then
      v_subject := 'Proposta pronta para aprovação: ' || v_p.title;
      v_head := 'O conteúdo do card proposto foi completado e aguarda a sua aprovação no Painel.';
    when 'PROPOSAL_APPROVED' then
      v_subject := 'Proposta aprovada: ' || v_p.title;
      v_head := 'A proposta foi aprovada e aguarda a publicação por um administrador.';
    when 'PROPOSAL_PUBLISHED' then
      v_subject := 'Card publicado: ' || coalesce(v_p.scenario_name, v_p.title);
      v_head := 'O card novo foi publicado e já pode receber protocolos.';
    when 'PROPOSAL_REJECTED' then
      v_subject := 'Proposta recusada: ' || v_p.title;
      v_head := 'A proposta foi recusada. Motivo: ' || coalesce(v_p.rejection_reason, '—');
    else
      raise exception 'unknown proposal notice %', p_type;
  end case;

  for r in
    select distinct on (lower(x->>'email')) lower(x->>'email') as email, x->>'name' as name,
           nullif(x->>'principal_id', '')::uuid as principal_id
    from jsonb_array_elements(coalesce(p_recipients, '[]'::jsonb)) x
    where btrim(coalesce(x->>'email', '')) <> ''
    order by lower(x->>'email')
  loop
    insert into public.notifications_log(
      proposal_id, notification_type, recipient_email, recipient_principal_id, recipient_name,
      channel, provider, delivery_status, idempotency_key, correlation_id, template_version, subject, body)
    values (
      v_p.id, p_type, r.email, r.principal_id, r.name, 'EMAIL', 'MS_GRAPH', 'QUEUED',
      p_key_prefix || ':' || r.email, gen_random_uuid(), 1,
      '[Painel Safra] ' || v_subject,
      -- Trechos limitados: o texto inteiro está no Painel; o aviso cabe nos 6.000 caracteres.
      left('Olá, ' || coalesce(nullif(btrim(r.name), ''), 'tudo bem') || '.' || E'\n\n' || v_head || E'\n\n'
        || 'Proposta: ' || v_p.title || E'\n'
        || 'Proposta por: ' || v_p.proposer_name || E'\n'
        || 'Problema: ' || private.safra_excerpt(v_p.problem_description, 1500) || E'\n'
        || 'Como afeta a Safra: ' || private.safra_excerpt(v_p.safra_impact_description, 1500) || E'\n\n'
        || 'Abrir no Painel: ' || private.safra_app_url() || '/propostas' || E'\n\n'
        || 'Aviso automático do Painel Safra. Não responda este e-mail.', 6000))
    on conflict (idempotency_key) do nothing;
    if found then v_count := v_count + 1; end if;
  end loop;
  return v_count;
end;
$$;

create or replace function public.safra_get_proposals()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_me uuid := private.safra_actor_principal_id();
  v_all boolean;
  v_governance boolean;
  v_admin boolean;
  v_candidate boolean;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  v_governance := private.safra_has_role('safra_governance_admin');
  v_admin := private.safra_has_role('safra_platform_admin');
  v_all := v_governance or v_admin or private.safra_has_role('safra_executive_admin');
  v_candidate := v_me is not null and exists (select 1 from private.safra_proposal_candidates() c where c = v_me);

  return jsonb_build_object(
    'me', jsonb_build_object('name', private.safra_user_display_name(v_actor),
                             'email', (select lower(u.email) from auth.users u where u.id = v_actor),
                             'is_candidate', v_candidate),
    'candidates', (select coalesce(jsonb_agg(jsonb_build_object('principal_id', p.id,
                     'name', coalesce(nullif(btrim(p.display_name), ''), p.corporate_email)) order by p.display_name), '[]'::jsonb)
                   from private.safra_principals p where p.id in (select private.safra_proposal_candidates())),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'proposal_id', sp.id,
        'status', sp.status,
        'title', sp.title,
        'problem_description', sp.problem_description,
        'safra_impact_description', sp.safra_impact_description,
        'proposer_name', sp.proposer_name,
        'submitted_at', sp.submitted_at,
        'mine', sp.proposed_by = v_actor,
        'owner_name', (select coalesce(nullif(btrim(p.display_name), ''), p.corporate_email) from private.safra_principals p where p.id = sp.owner_principal_id),
        'owner_decision', sp.owner_decision,
        'owner_note', sp.owner_note,
        'scenario_name', sp.scenario_name,
        'trigger_description', sp.trigger_description,
        'detection_description', sp.detection_description,
        'protocol_text', sp.protocol_text,
        'expected_impact_summary', sp.expected_impact_summary,
        'impacted_area_ids', to_jsonb(sp.impacted_area_ids),
        'responsible_area', (select oa.name from public.operational_areas oa where oa.id = sp.responsible_area_id),
        'published_code', (select sc.code from public.scenarios sc where sc.id = sp.scenario_id),
        'rejection_reason', sp.rejection_reason,
        'responses', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', coalesce(nullif(btrim(p.display_name), ''), p.corporate_email),
            'response', r.response, 'note', r.response_note, 'responded_at', r.responded_at) order by r.responded_at)
          from public.scenario_proposal_owner_responses r join private.safra_principals p on p.id = r.candidate_owner_id
          where r.proposal_id = sp.id), '[]'::jsonb),
        'my_response', (select r.response from public.scenario_proposal_owner_responses r
                        where r.proposal_id = sp.id and r.candidate_owner_id = v_me),
        'events', coalesce((
          select jsonb_agg(jsonb_build_object('event_type', e.event_type, 'occurred_at', e.occurred_at,
                   'actor_name', case when e.actor_user_id is null then 'Sistema' else private.safra_user_display_name(e.actor_user_id) end,
                   'note', e.note) order by e.occurred_at, e.id)
          from public.scenario_proposal_events e where e.proposal_id = sp.id), '[]'::jsonb),
        'can_forward', v_governance and sp.status = 'SUBMITTED',
        'can_respond', v_candidate and sp.status = 'OWNER_CONSULTATION',
        'can_define_owner', v_governance and sp.status = 'OWNER_CONSULTATION',
        'can_submit_content', sp.proposed_by = v_actor and sp.status in ('OWNER_DEFINED', 'CONTENT_SUBMITTED'),
        'can_approve', sp.status = 'CONTENT_SUBMITTED' and coalesce(private.safra_can_approve_proposal(sp.proposed_by), false),
        'can_reject', sp.status not in ('PUBLISHED', 'REJECTED') and coalesce(private.safra_can_approve_proposal(sp.proposed_by), false),
        'can_publish', v_admin and sp.status = 'APPROVED' and sp.proposed_by <> v_actor and sp.approved_by is distinct from v_actor
      ) order by sp.submitted_at desc)
      from public.scenario_proposals sp
      where v_all
         or sp.proposed_by = v_actor
         or (v_candidate and sp.forwarded_at is not null)
    ), '[]'::jsonb)
  );
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

select cron.unschedule('safra-send-notifications')
where exists (select 1 from cron.job where jobname = 'safra-send-notifications');

do $do$
begin
  if exists (select 1 from auth.users where lower(email) = 'kaue.pastrello@editoradobrasil.com.br') then
    perform cron.schedule('safra-send-notifications', '*/2 * * * *', $job$
      select net.http_post(
        url := 'https://trqkwqkjjjeppuddwenu.supabase.co/functions/v1/safra-send-notifications',
        headers := '{"Content-Type": "application/json"}'::jsonb,
        body := '{}'::jsonb,
        timeout_milliseconds := 60000
      )
    $job$);
  end if;
end;
$do$;

commit;
