-- RECONSTITUÍDA em 01/10/2026 (C05-AUD2, D-52) a partir das definições vigentes no PRIMARY.
-- Versão aplicada no PRIMARY em 28/09/2026 fora do repositório; SQL original não preservado.
-- Efeito: notifications_log passa a ter uma máquina de estados explícita
-- (QUEUED -> SENT | FAILED; FAILED exige motivo; estados terminais imutáveis).
-- Idempotente: reaplicar no PRIMARY não altera nada.

alter table public.notifications_log drop constraint if exists notifications_status_not_blank;

alter table public.notifications_log drop constraint if exists notifications_delivery_status_check;
alter table public.notifications_log
  add constraint notifications_delivery_status_check
  check (delivery_status = any (array['QUEUED'::text, 'SENT'::text, 'FAILED'::text]));

alter table public.notifications_log drop constraint if exists notifications_delivery_state_fields_check;
alter table public.notifications_log
  add constraint notifications_delivery_state_fields_check
  check (
    ((delivery_status = 'QUEUED'::text) and (sent_at is null) and (failed_at is null) and (failure_reason is null))
    or ((delivery_status = 'SENT'::text) and (sent_at is not null) and (failed_at is null) and (failure_reason is null))
    or ((delivery_status = 'FAILED'::text) and (sent_at is null) and (failed_at is not null) and (btrim(coalesce(failure_reason, ''::text)) <> ''::text))
  );

create or replace function private.safra_notification_server_clock()
 returns trigger
 language plpgsql
 set search_path to ''
as $function$
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
$function$;

revoke all on function private.safra_notification_server_clock() from public, anon, authenticated;
