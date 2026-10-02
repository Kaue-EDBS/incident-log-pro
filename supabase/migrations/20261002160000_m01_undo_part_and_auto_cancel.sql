-- SAFRA-M01 (02/10/2026) — regras de mudança de situação do protocolo.
--
-- D-98  sem reabrir: ENCERRADO e CANCELADO nunca voltam a EM ANDAMENTO (já garantido pelos
--       gatilhos do C05/C02; esta fase só reforça com testes).
-- D-99  desfazer o "Concluído" da própria parte em até 5 minutos, enquanto o protocolo
--       estiver em andamento (se a outra parte já concluiu, ele virou ENCERRADO e não volta).
-- D-100 sem correção pelo admin: protocolo errado é cancelado e aberto de novo.
-- D-101 cancelamento automático 72 horas depois da abertura, só se nenhuma parte concluiu.
begin;

-- 1. Cancelamento automático no próprio registro -------------------------------------
alter table public.treatments
  add column auto_cancelled boolean not null default false;

alter table public.treatments drop constraint treatments_state_fields_check;
alter table public.treatments
  add constraint treatments_state_fields_check check (
    (
      status = 'ACTIVE'
      and closed_by is null and closed_at is null
      and cancelled_by is null and cancelled_at is null and cancellation_reason is null
      and not auto_cancelled
    )
    or
    (
      status = 'RESOLVED'
      and closed_by is not null and closed_at is not null
      and cancelled_by is null and cancelled_at is null and cancellation_reason is null
      and not auto_cancelled
    )
    or
    (
      status = 'CANCELLED'
      and cancelled_at is not null
      and btrim(coalesce(cancellation_reason,'')) <> ''
      and closed_by is null and closed_at is null
      -- cancelamento por pessoa tem autor; o automático (D-101) não tem
      and ((cancelled_by is not null and not auto_cancelled)
        or (cancelled_by is null and auto_cancelled))
    )
  );

alter table public.treatment_events drop constraint treatment_events_type_check;
alter table public.treatment_events
  add constraint treatment_events_type_check
  check (event_type = any (array[
    'TREATMENT_OPENED'::text,
    'NOTE_ADDED'::text,
    'IMPACT_AREA_ADDED'::text,
    'IMPACT_AREA_REMOVED'::text,
    'REQUESTER_PART_CLOSED'::text,
    'OWNER_PART_CLOSED'::text,
    'REQUESTER_PART_UNDONE'::text,
    'OWNER_PART_UNDONE'::text,
    'TREATMENT_RESOLVED'::text,
    'TREATMENT_CANCELLED'::text,
    'ADMIN_CORRECTION_RECORDED'::text
  ]));

-- 2. Relógio do servidor: partes só são apagadas pelo "desfazer" e dentro de 5 min ----
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

  -- Só o cancelamento automático (D-101) marca auto_cancelled.
  if old.status = 'ACTIVE' and new.status = 'CANCELLED'
     and coalesce(current_setting('safra.auto_cancel', true), '') = 'on' then
    new.auto_cancelled := true;
  else
    new.auto_cancelled := old.auto_cancelled;
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

-- 3. Visão de um protocolo: desfazer e cancelamento automático ----------------------
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

-- 4. Desfazer a minha parte (D-99) -------------------------------------------------
create or replace function public.safra_undo_my_part(p_treatment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_t public.treatments%rowtype;
  v_role text;
  v_closed_at timestamptz;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_UNDO_FORBIDDEN';
  end if;

  select * into v_t from public.treatments where id = p_treatment_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_UNDO_FORBIDDEN';
  end if;

  if v_t.opened_by = v_actor then
    v_role := 'REQUESTER';
    v_closed_at := v_t.requester_closed_at;
  elsif v_t.owner_closed_by = v_actor
     or private.safra_current_owner_user_id(v_t.scenario_id) is not distinct from v_actor then
    v_role := 'OWNER';
    v_closed_at := case when v_t.owner_closed_by = v_actor then v_t.owner_closed_at end;
  else
    raise exception using errcode = '42501', message = 'SAFRA_UNDO_FORBIDDEN';
  end if;

  if v_t.status <> 'ACTIVE' then
    raise exception using errcode = 'P0001', message = 'SAFRA_TREATMENT_NOT_ACTIVE';
  end if;

  if v_closed_at is null then
    raise exception using errcode = 'P0001', message = 'SAFRA_UNDO_NOTHING_TO_UNDO';
  end if;

  if clock_timestamp() - v_closed_at > interval '5 minutes' then
    raise exception using errcode = 'P0001', message = 'SAFRA_UNDO_WINDOW_EXPIRED';
  end if;

  -- D-57: depois de concluir, a pessoa pode ter aberto outro protocolo no mesmo card.
  if v_role = 'REQUESTER' and exists (
    select 1 from public.treatments o
    where o.scenario_id = v_t.scenario_id
      and o.opened_by = v_actor
      and o.id <> v_t.id
      and o.status = 'ACTIVE'
      and o.requester_closed_at is null
  ) then
    raise exception using errcode = 'P0001', message = 'SAFRA_UNDO_BLOCKED_BY_NEW_PROTOCOL';
  end if;

  perform set_config('safra.undo_part', v_role, true);
  update public.treatments
     set requester_closed_at = case when v_role = 'REQUESTER' then null else requester_closed_at end,
         owner_closed_at = case when v_role = 'OWNER' then null else owner_closed_at end,
         owner_closed_by = case when v_role = 'OWNER' then null else owner_closed_by end
   where id = v_t.id;
  perform set_config('safra.undo_part', '', true);

  insert into public.treatment_events(treatment_id, event_type, actor_user_id, correlation_id, payload)
  values (v_t.id,
          case when v_role = 'REQUESTER' then 'REQUESTER_PART_UNDONE' else 'OWNER_PART_UNDONE' end,
          v_actor, gen_random_uuid(),
          jsonb_build_object('source', 'SAFRA_M01_UNDO_PART', 'role', v_role, 'undone_closed_at', v_closed_at));

  return private.safra_treatment_view_json(v_t.id, v_actor);
end;
$$;

revoke all on function public.safra_undo_my_part(uuid) from public, anon;
grant execute on function public.safra_undo_my_part(uuid) to authenticated, service_role;

comment on function public.safra_undo_my_part(uuid) is
  'M01 D-99: undo my own closed part within 5 minutes while the protocol is still ACTIVE; append-only *_PART_UNDONE event.';

-- 5. Cancelamento automático em 72 h (D-101) ----------------------------------------
create or replace function private.safra_auto_cancel_stale()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  perform set_config('safra.auto_cancel', 'on', true);

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

  get diagnostics v_count = row_count;
  perform set_config('safra.auto_cancel', '', true);
  return v_count;
end;
$$;

revoke all on function private.safra_auto_cancel_stale() from public, anon, authenticated;

comment on function private.safra_auto_cancel_stale() is
  'M01 D-101: cancels ACTIVE protocols 72 h after opening when no part was closed. Run by pg_cron every 10 minutes.';

-- Agendamento: a cada 10 minutos (o cancelamento acontece entre 72 h e 72 h 10 min).
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
select cron.schedule('safra-auto-cancel-72h', '*/10 * * * *', 'select private.safra_auto_cancel_stale()');
-- O agendador guarda um registro por execução (144 por dia): manter só 7 dias.
select cron.schedule('safra-cron-log-cleanup', '17 3 * * *',
  $$delete from cron.job_run_details where end_time < now() - interval '7 days'$$);

-- 6. Saúde do sistema mostra os cancelamentos automáticos (D-95) ------------------
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
      'active_now', (select count(*) from public.treatments where status = 'ACTIVE'),
      'oldest_active_opened_at', (select min(opened_at) from public.treatments where status = 'ACTIVE')
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

commit;
