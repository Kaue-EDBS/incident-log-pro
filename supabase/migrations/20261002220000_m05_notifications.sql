-- SAFRA-M05 (02/10/2026) — avisos por e-mail.
--
-- D-111 quem recebe (revisa a D-58): abertura, encerramento e cancelamento vão para o dono do
--       card e para quem abriu; "desfez a conclusão" vai para a outra parte. Jair não recebe
--       e-mail (acompanha pelo Painel e entra no card 12); Bruno e platform admins também não,
--       salvo se forem donos do card. Só e-mail (Teams segue em aberto, GI-SAFRA-011).
-- D-112 lembretes 24 h, 12 h e 1 h antes do fechamento automático de 72 h (com 48 h, 60 h e
--       71 h de aberto), para quem ainda não concluiu a sua parte. Substitui a escada de 2 h, 4 h
--       e de hora em hora (D-67/D-76). Resolve a GI-SAFRA-016.
-- D-113 72 h depois da abertura, com uma parte concluída e a outra não, o protocolo é
--       ENCERRADO automaticamente, valendo a parte concluída (completa a D-101).
-- D-114 o e-mail leva número, card, situação, quem abriu, horários, o resumo do problema e o
--       link para o Painel.
--
-- Técnico (M05): a decisão de quem recebe é do banco, nunca da tela; texto montado no banco
-- (modelo versionado); uma linha por aviso e por pessoa, com chave única (sem duplicar);
-- até 5 tentativas com espera crescente; aviso que não saiu em 24 h, ou lembrete de protocolo
-- já fechado, expira em vez de ser enviado atrasado. O envio de verdade (Microsoft 365) fica
-- desligado até o TI liberar a caixa painel.safra@ e a permissão de envio.
begin;

-- 1. Encerramento automático no próprio registro (D-113) ------------------------------
alter table public.treatments
  add column auto_resolved boolean not null default false;

alter table public.treatments drop constraint treatments_resolved_iff_both_parts;
alter table public.treatments
  add constraint treatments_resolved_iff_both_parts check (
    (status = 'RESOLVED'
      and ((requester_closed_at is not null and owner_closed_at is not null and not auto_resolved)
        or (auto_resolved and ((requester_closed_at is null) <> (owner_closed_at is null)))))
    or
    (status <> 'RESOLVED'
      and not (requester_closed_at is not null and owner_closed_at is not null)
      and not auto_resolved)
  );

alter table public.treatments drop constraint treatments_state_fields_check;
alter table public.treatments
  add constraint treatments_state_fields_check check (
    (
      status = 'ACTIVE'
      and closed_by is null and closed_at is null
      and cancelled_by is null and cancelled_at is null and cancellation_reason is null
      and not auto_cancelled and not auto_resolved
    )
    or
    (
      status = 'RESOLVED'
      and closed_at is not null
      and cancelled_by is null and cancelled_at is null and cancellation_reason is null
      and not auto_cancelled
      -- encerramento por pessoa tem autor; o automático (D-113) não tem
      and ((closed_by is not null and not auto_resolved)
        or (closed_by is null and auto_resolved))
    )
    or
    (
      status = 'CANCELLED'
      and cancelled_at is not null
      and btrim(coalesce(cancellation_reason,'')) <> ''
      and closed_by is null and closed_at is null
      and not auto_resolved
      and ((cancelled_by is not null and not auto_cancelled)
        or (cancelled_by is null and auto_cancelled))
    )
  );

create or replace function private.safra_treatment_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_undo text := coalesce(current_setting('safra.undo_part', true), '');
begin
  if tg_op = 'INSERT' then
    new.opened_at := v_now;
    new.created_at := v_now;
    new.updated_at := v_now;
    new.closed_at := null;
    new.cancelled_at := null;
    new.requester_closed_at := null;
    new.owner_closed_at := null;
    new.owner_closed_by := null;
    new.auto_cancelled := false;
    new.auto_resolved := false;
    if new.problem_started_at is null or new.problem_started_at > v_now then
      new.problem_started_at := v_now;
    end if;
    return new;
  end if;

  new.updated_at := v_now;

  -- Partes do encerramento: horário sempre do servidor e nunca reescrito, salvo o
  -- "desfazer" da própria parte (D-99), em até 5 minutos e com o protocolo em andamento.
  if old.requester_closed_at is not null then
    if v_undo = 'REQUESTER'
       and new.requester_closed_at is null
       and old.status = 'ACTIVE' and new.status = 'ACTIVE'
       and v_now - old.requester_closed_at <= interval '5 minutes'
    then
      new.requester_closed_at := null;
    else
      new.requester_closed_at := old.requester_closed_at;
    end if;
  elsif new.requester_closed_at is not null then
    new.requester_closed_at := v_now;
  end if;

  if old.owner_closed_at is not null then
    if v_undo = 'OWNER'
       and new.owner_closed_at is null
       and old.status = 'ACTIVE' and new.status = 'ACTIVE'
       and v_now - old.owner_closed_at <= interval '5 minutes'
    then
      new.owner_closed_at := null;
      new.owner_closed_by := null;
    else
      new.owner_closed_at := old.owner_closed_at;
      new.owner_closed_by := old.owner_closed_by;
    end if;
  elsif new.owner_closed_at is not null then
    new.owner_closed_at := v_now;
  end if;

  -- Só o fechamento automático de 72 h marca auto_cancelled (D-101) e auto_resolved (D-113).
  if old.status = 'ACTIVE' and new.status = 'CANCELLED'
     and coalesce(current_setting('safra.auto_cancel', true), '') = 'on' then
    new.auto_cancelled := true;
  else
    new.auto_cancelled := old.auto_cancelled;
  end if;

  if old.status = 'ACTIVE' and new.status = 'RESOLVED'
     and coalesce(current_setting('safra.auto_cancel', true), '') = 'on' then
    new.auto_resolved := true;
  else
    new.auto_resolved := old.auto_resolved;
  end if;

  if old.status = 'ACTIVE' and new.status = 'RESOLVED' then
    new.closed_at := v_now;
    new.cancelled_at := null;
  elsif old.status = 'ACTIVE' and new.status = 'CANCELLED' then
    new.cancelled_at := v_now;
    new.closed_at := null;
  elsif old.status = 'RESOLVED' then
    new.closed_by := old.closed_by;
    new.closed_at := old.closed_at;
  elsif old.status = 'CANCELLED' then
    new.cancelled_by := old.cancelled_by;
    new.cancelled_at := old.cancelled_at;
    new.cancellation_reason := old.cancellation_reason;
  end if;

  return new;
end;
$$;

create or replace function private.safra_treatment_view_json(p_treatment_id uuid, p_actor uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'treatment_id', t.id,
    'protocol_number', t.protocol_number,
    'status', t.status,
    'situation', private.safra_treatment_situation(t.status, t.requester_closed_at, t.owner_closed_at),
    'scenario', jsonb_build_object('id', sc.id, 'code', sc.code, 'name', sc.name),
    'owner', jsonb_build_object(
      'principal_id', owner_p.id,
      'display_name', owner_p.display_name,
      'corporate_email', owner_p.corporate_email
    ),
    'requester_email', lower(u.email),
    'requester_name', private.safra_user_display_name(t.opened_by),
    'impact_summary', t.impact_summary,
    'impacted_areas', coalesce((
      select jsonb_agg(jsonb_build_object('id', ia.id, 'code', ia.code, 'name', ia.name) order by ia.name)
      from public.treatment_impacted_areas tia
      join public.operational_areas ia on ia.id = tia.operational_area_id
      where tia.treatment_id = t.id and tia.valid_to is null
    ), '[]'::jsonb),
    'problem_started_at', t.problem_started_at,
    'opened_at', t.opened_at,
    'requester_closed_at', t.requester_closed_at,
    'owner_closed_at', t.owner_closed_at,
    'closed_at', t.closed_at,
    'cancelled_at', t.cancelled_at,
    'cancellation_reason', t.cancellation_reason,
    'auto_cancelled', t.auto_cancelled,
    'auto_resolved', t.auto_resolved,
    'auto_resolve_at', case
      when t.status = 'ACTIVE' and ((t.requester_closed_at is null) <> (t.owner_closed_at is null))
      then t.opened_at + interval '72 hours'
    end,
    'auto_cancel_at', case
      when t.status = 'ACTIVE' and t.requester_closed_at is null and t.owner_closed_at is null
      then t.opened_at + interval '72 hours'
    end,
    'server_time', clock_timestamp(),
    'my_role', case
      when t.opened_by = p_actor then 'REQUESTER'
      when private.safra_current_owner_user_id(t.scenario_id) is not distinct from p_actor then 'OWNER'
      else null
    end,
    'can_close_my_part', t.status = 'ACTIVE' and (
      (t.opened_by = p_actor and t.requester_closed_at is null)
      or (t.opened_by <> p_actor
          and private.safra_current_owner_user_id(t.scenario_id) is not distinct from p_actor
          and t.owner_closed_at is null)
    ),
    'can_undo_my_part', t.status = 'ACTIVE' and (
      (t.opened_by = p_actor and t.requester_closed_at is not null
        and clock_timestamp() - t.requester_closed_at <= interval '5 minutes')
      or (t.owner_closed_by = p_actor and t.owner_closed_at is not null
        and clock_timestamp() - t.owner_closed_at <= interval '5 minutes')
    ),
    'undo_until', case
      when t.status <> 'ACTIVE' then null
      when t.opened_by = p_actor and t.requester_closed_at is not null
        then t.requester_closed_at + interval '5 minutes'
      when t.owner_closed_by = p_actor and t.owner_closed_at is not null
        then t.owner_closed_at + interval '5 minutes'
    end,
    'can_cancel', t.status = 'ACTIVE' and (
      t.opened_by = p_actor
      or private.safra_current_owner_user_id(t.scenario_id) is not distinct from p_actor
    )
  )
  from public.treatments t
  join public.scenarios sc on sc.id = t.scenario_id
  join private.safra_principals owner_p on owner_p.id = t.owner_id_at_start
  join auth.users u on u.id = t.opened_by
  where t.id = p_treatment_id;
$$;

revoke all on function private.safra_treatment_view_json(uuid, uuid) from public, anon, authenticated;

-- 2. Fila de avisos -------------------------------------------------------------------
alter table public.notifications_log
  add column event_id uuid references public.treatment_events(id) on delete restrict,
  add column recipient_name text,
  add column recipient_role text,
  add column template_version integer,
  add column subject text,
  add column body text,
  add column attempts integer not null default 0,
  add column next_attempt_at timestamptz not null default clock_timestamp(),
  add column locked_until timestamptz,
  add column last_error text,
  add constraint notifications_attempts_range check (attempts between 0 and 5),
  add constraint notifications_recipient_role_check check (recipient_role is null or recipient_role in ('REQUESTER', 'OWNER')),
  add constraint notifications_subject_len check (subject is null or length(subject) <= 200),
  add constraint notifications_body_len check (body is null or length(body) <= 6000),
  add constraint notifications_last_error_len check (last_error is null or length(last_error) <= 500);

create index idx_notifications_log_event_id on public.notifications_log(event_id);
create index idx_notifications_log_queue on public.notifications_log(next_attempt_at)
  where delivery_status = 'QUEUED';

-- Endereço do Painel nos e-mails (muda por migration se o domínio mudar, GI-SAFRA-015).
create or replace function private.safra_app_url()
returns text
language sql
immutable
set search_path = ''
as $$ select 'https://painelsafra.lovable.app'::text $$;

revoke all on function private.safra_app_url() from public, anon, authenticated;

-- Modelo de e-mail, versão 1 (D-114). Texto simples, em português.
create or replace function private.safra_render_notification(
  p_type text,
  p_treatment_id uuid,
  p_recipient_role text,
  p_recipient_name text,
  p_actor_name text
)
returns table(subject text, body text)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_t public.treatments%rowtype;
  v_card text;
  v_requester text;
  v_owner text;
  v_hello text;
  v_head text;
  v_subject text;
  v_url text;
  v_tz text := 'America/Sao_Paulo';
begin
  select * into v_t from public.treatments where id = p_treatment_id;
  select btrim(regexp_replace(sc.name, '\s*\([^)]*\)', '', 'g')) into v_card
  from public.scenarios sc where sc.id = v_t.scenario_id;
  v_requester := private.safra_user_display_name(v_t.opened_by);
  select coalesce(nullif(btrim(p.display_name), ''), p.corporate_email) into v_owner
  from public.scenario_owners so join private.safra_principals p on p.id = so.owner_id
  where so.scenario_id = v_t.scenario_id and so.valid_to is null;
  v_url := private.safra_app_url()
           || case when p_recipient_role = 'OWNER' then '/protocolos-dos-meus-cards' else '/meus-protocolos' end;
  v_hello := 'Olá, ' || coalesce(nullif(btrim(p_recipient_name), ''), 'tudo bem') || '.';

  case p_type
    when 'TREATMENT_OPENED' then
      if p_recipient_role = 'OWNER' then
        v_subject := 'Novo protocolo ' || v_t.protocol_number || ' no seu card';
        v_head := v_requester || ' abriu o protocolo ' || v_t.protocol_number || ' no card "' || v_card || '". '
               || 'Quando estiver resolvido do seu lado, conclua a sua parte no Painel.';
      else
        v_subject := 'Protocolo ' || v_t.protocol_number || ' aberto';
        v_head := 'Você abriu o protocolo ' || v_t.protocol_number || ' no card "' || v_card || '". '
               || 'O dono do card (' || coalesce(v_owner, 'dono do card') || ') também foi avisado. '
               || 'Quando estiver resolvido do seu lado, conclua a sua parte no Painel.';
      end if;
    when 'TREATMENT_RESOLVED' then
      v_subject := 'Protocolo ' || v_t.protocol_number || ' encerrado';
      v_head := case when v_t.auto_resolved
        then 'O protocolo ' || v_t.protocol_number || ' foi encerrado automaticamente: passaram 72 horas e valeu a parte já concluída.'
        else 'O protocolo ' || v_t.protocol_number || ' foi encerrado: as duas partes concluíram.' end;
    when 'TREATMENT_CANCELLED' then
      v_subject := 'Protocolo ' || v_t.protocol_number || ' cancelado';
      v_head := case when v_t.auto_cancelled
        then 'O protocolo ' || v_t.protocol_number || ' foi cancelado automaticamente: passaram 72 horas sem nenhuma conclusão.'
        else coalesce(p_actor_name, 'Alguém') || ' cancelou o protocolo ' || v_t.protocol_number || '. Motivo: ' || coalesce(v_t.cancellation_reason, '—') end;
    when 'PART_UNDONE' then
      v_subject := 'Conclusão desfeita no protocolo ' || v_t.protocol_number;
      v_head := coalesce(p_actor_name, 'A outra parte') || ' desfez a conclusão da parte dele. '
             || 'O protocolo ' || v_t.protocol_number || ' voltou a ficar em andamento.';
    when 'REMINDER_24H', 'REMINDER_12H', 'REMINDER_1H' then
      v_subject := 'Faltam ' || case p_type when 'REMINDER_24H' then '24 horas' when 'REMINDER_12H' then '12 horas' else '1 hora' end
                || ': protocolo ' || v_t.protocol_number;
      v_head := 'Falta você concluir a sua parte do protocolo ' || v_t.protocol_number || '. '
             || case when v_t.requester_closed_at is null and v_t.owner_closed_at is null
                  then 'Se ninguém concluir, ele será cancelado automaticamente em '
                  else 'Se você não concluir, ele será encerrado automaticamente, valendo a parte já concluída, em ' end
             || to_char((v_t.opened_at + interval '72 hours') at time zone v_tz, 'DD/MM/YYYY "às" HH24:MI') || '.';
    else
      raise exception 'unknown notification type %', p_type;
  end case;

  subject := '[Painel Safra] ' || v_subject;
  body := v_hello || E'\n\n' || v_head || E'\n\n'
       || 'Protocolo: ' || v_t.protocol_number || E'\n'
       || 'Card: ' || v_card || E'\n'
       || 'Aberto por: ' || v_requester || E'\n'
       || 'Dono do card: ' || coalesce(v_owner, '—') || E'\n'
       || 'Problema começou: ' || to_char(v_t.problem_started_at at time zone v_tz, 'DD/MM/YYYY HH24:MI') || E'\n'
       || 'Aberto em: ' || to_char(v_t.opened_at at time zone v_tz, 'DD/MM/YYYY HH24:MI') || E'\n'
       || 'Problema: ' || coalesce(v_t.impact_summary, '—') || E'\n\n'
       || 'Abrir no Painel: ' || v_url || E'\n\n'
       || 'Aviso automático do Painel Safra. Não responda este e-mail.';
  return next;
end;
$$;

revoke all on function private.safra_render_notification(text, uuid, text, text, text) from public, anon, authenticated;

-- Coloca na fila um aviso para cada pessoa (sem duplicar o mesmo e-mail).
create or replace function private.safra_enqueue_notification(
  p_type text,
  p_treatment_id uuid,
  p_event_id uuid,
  p_roles text[],
  p_actor_name text,
  p_key_prefix text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_t public.treatments%rowtype;
  v_count integer := 0;
  r record;
begin
  select * into v_t from public.treatments where id = p_treatment_id;

  for r in
    select distinct on (lower(x.email)) x.role, lower(x.email) as email, x.name, x.principal_id
    from (
      -- quem abriu
      select 'REQUESTER' as role, u.email::text as email, private.safra_user_display_name(u.id) as name,
             (select p.id from private.safra_principals p where p.user_id = u.id) as principal_id, 1 as ord
      from auth.users u
      where u.id = v_t.opened_by and 'REQUESTER' = any (p_roles)
      union all
      -- dono vigente do card, se disponível (D-78)
      select 'OWNER', p.corporate_email::text, coalesce(nullif(btrim(p.display_name), ''), p.corporate_email), p.id, 2
      from public.scenario_owners so
      join private.safra_principals p on p.id = so.owner_id
      where so.scenario_id = v_t.scenario_id and so.valid_to is null
        and private.safra_owner_is_available(p.id)
        and 'OWNER' = any (p_roles)
    ) x
    where btrim(coalesce(x.email, '')) <> ''
    order by lower(x.email), x.ord
  loop
    insert into public.notifications_log(
      treatment_id, event_id, notification_type, recipient_email, recipient_principal_id,
      recipient_name, recipient_role, channel, provider, delivery_status, idempotency_key,
      correlation_id, template_version, subject, body
    )
    select v_t.id, p_event_id, p_type, r.email, r.principal_id, r.name, r.role, 'EMAIL', 'MS_GRAPH', 'QUEUED',
           p_key_prefix || ':' || r.email, gen_random_uuid(), 1, rn.subject, rn.body
    from private.safra_render_notification(p_type, v_t.id, r.role, r.name, p_actor_name) rn
    on conflict (idempotency_key) do nothing;
    if found then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

revoke all on function private.safra_enqueue_notification(text, uuid, uuid, text[], text, text) from public, anon, authenticated;

-- Cada evento do protocolo decide quem é avisado (D-111).
create or replace function private.safra_notify_on_treatment_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_name text := case when new.actor_user_id is null then null
                            else private.safra_user_display_name(new.actor_user_id) end;
begin
  case new.event_type
    when 'TREATMENT_OPENED', 'TREATMENT_RESOLVED', 'TREATMENT_CANCELLED' then
      perform private.safra_enqueue_notification(new.event_type, new.treatment_id, new.id,
        array['REQUESTER', 'OWNER'], v_actor_name, 'EV:' || new.id);
    when 'REQUESTER_PART_UNDONE' then
      perform private.safra_enqueue_notification('PART_UNDONE', new.treatment_id, new.id,
        array['OWNER'], v_actor_name, 'EV:' || new.id);
    when 'OWNER_PART_UNDONE' then
      perform private.safra_enqueue_notification('PART_UNDONE', new.treatment_id, new.id,
        array['REQUESTER'], v_actor_name, 'EV:' || new.id);
    else
      null; -- concluir a própria parte não gera aviso (D-111)
  end case;
  return null;
end;
$$;

revoke all on function private.safra_notify_on_treatment_event() from public, anon, authenticated;

create trigger trg_90_treatment_events_notify
after insert on public.treatment_events
for each row execute function private.safra_notify_on_treatment_event();

-- 3. Fechamento automático e lembretes (D-101, D-112, D-113) ---------------------------
create or replace function private.safra_auto_cancel_stale()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cancelled integer;
  v_resolved integer;
  r record;
begin
  perform set_config('safra.auto_cancel', 'on', true);

  -- D-101: ninguém concluiu em 72 h -> cancelado.
  with stale as (
    select t.id
    from public.treatments t
    where t.status = 'ACTIVE'
      and t.requester_closed_at is null
      and t.owner_closed_at is null
      and t.opened_at <= clock_timestamp() - interval '72 hours'
    order by t.opened_at
    limit 500
    for update skip locked
  ),
  cancelled as (
    update public.treatments t
       set status = 'CANCELLED',
           cancelled_by = null,
           cancelled_at = clock_timestamp(),
           cancellation_reason = 'Cancelado automaticamente: 72 horas sem nenhuma conclusão (D-101).'
      from stale
     where t.id = stale.id
    returning t.id
  )
  insert into public.treatment_events(treatment_id, event_type, actor_user_id, correlation_id, payload)
  select c.id, 'TREATMENT_CANCELLED', null, gen_random_uuid(),
         jsonb_build_object('source', 'SAFRA_M01_AUTO_CANCEL_72H', 'role', 'SYSTEM')
  from cancelled c;
  get diagnostics v_cancelled = row_count;

  -- D-113: uma parte concluiu, a outra não, em 72 h -> encerrado, valendo a parte concluída.
  with stale as (
    select t.id
    from public.treatments t
    where t.status = 'ACTIVE'
      and (t.requester_closed_at is null) <> (t.owner_closed_at is null)
      and t.opened_at <= clock_timestamp() - interval '72 hours'
    order by t.opened_at
    limit 500
    for update skip locked
  ),
  resolved as (
    update public.treatments t
       set status = 'RESOLVED',
           closed_by = null,
           closed_at = clock_timestamp()
      from stale
     where t.id = stale.id
    returning t.id
  )
  insert into public.treatment_events(treatment_id, event_type, actor_user_id, correlation_id, payload)
  select r2.id, 'TREATMENT_RESOLVED', null, gen_random_uuid(),
         jsonb_build_object('source', 'SAFRA_M05_AUTO_RESOLVE_72H', 'role', 'SYSTEM')
  from resolved r2;
  get diagnostics v_resolved = row_count;

  perform set_config('safra.auto_cancel', '', true);

  -- D-112: lembretes com 48 h, 60 h e 71 h de aberto, a quem ainda não concluiu.
  -- Se o agendador atrasar, só o lembrete mais recente vale (sem rajada de e-mails).
  for r in
    select t.id,
           case when t.opened_at + interval '71 hours' <= clock_timestamp() then 'REMINDER_1H'
                when t.opened_at + interval '60 hours' <= clock_timestamp() then 'REMINDER_12H'
                else 'REMINDER_24H' end as kind,
           array_remove(array[
             case when t.requester_closed_at is null then 'REQUESTER' end,
             case when t.owner_closed_at is null then 'OWNER' end
           ], null) as roles
    from public.treatments t
    where t.status = 'ACTIVE'
      and t.opened_at + interval '48 hours' <= clock_timestamp()
      and t.opened_at + interval '72 hours' > clock_timestamp()
    order by t.opened_at
    limit 2000
  loop
    perform private.safra_enqueue_notification(r.kind, r.id, null, r.roles, null, 'RM:' || r.id || ':' || r.kind);
  end loop;

  return v_cancelled + v_resolved;
end;
$$;

revoke all on function private.safra_auto_cancel_stale() from public, anon, authenticated;

comment on function private.safra_auto_cancel_stale() is
  'M01/M05: 72 h after opening, cancels protocols with no closed part (D-101) and resolves protocols with one closed part (D-113); queues the 24/12/1 h reminders (D-112). Run by pg_cron every 10 minutes.';

-- 4. Carteiro: só o serviço de envio (service_role) usa ---------------------------------
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
  update public.notifications_log n
     set delivery_status = 'FAILED',
         failure_reason = 'EXPIRED_PROTOCOL_NOT_ACTIVE'
   where n.delivery_status = 'QUEUED'
     and n.notification_type like 'REMINDER_%'
     and exists (select 1 from public.treatments t where t.id = n.treatment_id and t.status <> 'ACTIVE');

  update public.notifications_log n
     set delivery_status = 'FAILED',
         failure_reason = 'EXPIRED_TOO_OLD'
   where n.delivery_status = 'QUEUED'
     and n.queued_at < clock_timestamp() - interval '24 hours';

  with picked as (
    select n.id
    from public.notifications_log n
    where n.delivery_status = 'QUEUED'
      and n.next_attempt_at <= clock_timestamp()
      and (n.locked_until is null or n.locked_until < clock_timestamp())
    order by n.next_attempt_at, n.queued_at
    limit greatest(1, least(coalesce(p_limit, 20), 100))
    for update skip locked
  ),
  claimed as (
    update public.notifications_log n
       set attempts = n.attempts + 1,
           locked_until = clock_timestamp() + interval '5 minutes'
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

revoke all on function public.safra_notifications_claim(integer) from public, anon, authenticated;
revoke all on function public.safra_notifications_report(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.safra_notifications_claim(integer) to service_role;
grant execute on function public.safra_notifications_report(uuid, boolean, text) to service_role;

-- 5. Saúde do sistema e histórico mostram os avisos -----------------------------------
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
begin
  if v_actor is null
     or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_platform_admin')
  then
    raise exception using errcode = '42501', message = 'SAFRA_OPS_FORBIDDEN';
  end if;

  return jsonb_build_object(
    'since', v_since,
    'server_time', clock_timestamp(),
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
      'expired', (select count(*) from public.notifications_log where failed_at >= v_since and failure_reason like 'EXPIRED%')
    ),
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

revoke all on function public.safra_admin_get_ops_summary(integer) from public, anon;
grant execute on function public.safra_admin_get_ops_summary(integer) to authenticated, service_role;

create or replace function public.safra_get_treatment_timeline(p_treatment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_t public.treatments%rowtype;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_TIMELINE_FORBIDDEN';
  end if;

  select * into v_t from public.treatments where id = p_treatment_id;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_TIMELINE_FORBIDDEN';
  end if;

  -- D-108: só a gestão (Jair e Bruno) e os platform admins.
  if not (
    private.safra_has_role('safra_governance_admin')
    or private.safra_has_role('safra_executive_admin')
    or private.safra_has_role('safra_platform_admin')
  ) then
    raise exception using errcode = '42501', message = 'SAFRA_TIMELINE_FORBIDDEN';
  end if;

  return jsonb_build_object(
    'treatment', private.safra_treatment_view_json(v_t.id, v_actor),
    'scenario_version_no', (select sv.version_no from public.scenario_versions sv where sv.id = v_t.scenario_version_id),
    'opened_by_name', private.safra_user_display_name(v_t.opened_by),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'event_id', e.id,
        'occurred_at', e.occurred_at,
        'event_type', e.event_type,
        'actor_role', case
          when e.actor_user_id is null then 'SYSTEM'
          when e.actor_user_id = v_t.opened_by then 'REQUESTER'
          else 'OWNER'
        end,
        'actor_name', case
          when e.actor_user_id is null then 'Sistema'
          else private.safra_user_display_name(e.actor_user_id)
        end
      ) order by e.occurred_at, e.created_at, e.id)
      from public.treatment_events e
      where e.treatment_id = v_t.id
    ), '[]'::jsonb),
    -- M03/M05: avisos do protocolo (só a gestão e os admins chegam aqui, D-108).
    'notifications', coalesce((
      select jsonb_agg(jsonb_build_object(
        'notification_id', n.id,
        'notification_type', n.notification_type,
        'recipient_name', n.recipient_name,
        'delivery_status', n.delivery_status,
        'queued_at', n.queued_at,
        'sent_at', n.sent_at,
        'failed_at', n.failed_at
      ) order by n.queued_at, n.id)
      from public.notifications_log n
      where n.treatment_id = v_t.id
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.safra_get_treatment_timeline(uuid) from public, anon;
grant execute on function public.safra_get_treatment_timeline(uuid) to authenticated, service_role;

-- 6. GI-SAFRA-016 resolvida pela D-112 (só onde o login do owner existe) ---------------
do $$
declare
  v_owner uuid;
begin
  select u.id into v_owner from auth.users u where lower(u.email) = 'kaue.pastrello@editoradobrasil.com.br';
  if v_owner is not null then
    update public.governance_issues
       set status = 'RESOLVED',
           resolved_by = v_owner,
           resolution_text = 'D-112 (02/10/2026): lembretes por e-mail 24 h, 12 h e 1 h antes do fechamento automático de 72 h, para quem ainda não concluiu a sua parte.'
     where issue_key = 'GI-SAFRA-016'
       and status = 'OPEN';
  end if;
end;
$$;

commit;
