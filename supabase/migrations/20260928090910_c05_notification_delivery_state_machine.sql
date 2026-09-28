-- C05-AUD-01 — govern notification delivery state machine.
-- Canonical states: QUEUED -> SENT | FAILED.
-- SENT and FAILED are terminal. Delivery timestamps are server-generated.

alter table public.notifications_log
  drop constraint if exists notifications_status_not_blank;

alter table public.notifications_log
  add constraint notifications_delivery_status_check
  check (delivery_status in ('QUEUED','SENT','FAILED'));

alter table public.notifications_log
  add constraint notifications_delivery_state_fields_check
  check (
    (
      delivery_status='QUEUED'
      and sent_at is null
      and failed_at is null
      and failure_reason is null
    )
    or
    (
      delivery_status='SENT'
      and sent_at is not null
      and failed_at is null
      and failure_reason is null
    )
    or
    (
      delivery_status='FAILED'
      and sent_at is null
      and failed_at is not null
      and btrim(coalesce(failure_reason,'')) <> ''
    )
  );

create or replace function private.safra_notification_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then
    if new.delivery_status <> 'QUEUED' then
      raise exception 'notification must start QUEUED';
    end if;

    new.queued_at := v_now;
    new.created_at := v_now;
    new.sent_at := null;
    new.failed_at := null;
    new.failure_reason := null;
    return new;
  end if;

  new.queued_at := old.queued_at;
  new.created_at := old.created_at;

  if old.delivery_status in ('SENT','FAILED') then
    if new.delivery_status is distinct from old.delivery_status then
      raise exception 'terminal notification status is immutable';
    end if;

    new.sent_at := old.sent_at;
    new.failed_at := old.failed_at;
    new.failure_reason := old.failure_reason;
    return new;
  end if;

  if old.delivery_status <> 'QUEUED' then
    raise exception 'invalid previous notification status';
  end if;

  if new.delivery_status = 'QUEUED' then
    new.sent_at := null;
    new.failed_at := null;
    new.failure_reason := null;
  elsif new.delivery_status = 'SENT' then
    new.sent_at := v_now;
    new.failed_at := null;
    new.failure_reason := null;
  elsif new.delivery_status = 'FAILED' then
    if btrim(coalesce(new.failure_reason,'')) = '' then
      raise exception 'FAILED notification requires failure_reason';
    end if;
    new.sent_at := null;
    new.failed_at := v_now;
  else
    raise exception 'invalid notification delivery_status';
  end if;

  return new;
end;
$$;

revoke all on function private.safra_notification_server_clock()
from public, anon, authenticated;

comment on constraint notifications_delivery_status_check on public.notifications_log is
  'Canonical notification delivery states: QUEUED, SENT, FAILED.';

comment on constraint notifications_delivery_state_fields_check on public.notifications_log is
  'Keeps delivery_status consistent with sent_at, failed_at and failure_reason.';

comment on function private.safra_notification_server_clock() is
  'Enforces QUEUED -> SENT|FAILED, terminal delivery states and server-side notification timestamps.';
