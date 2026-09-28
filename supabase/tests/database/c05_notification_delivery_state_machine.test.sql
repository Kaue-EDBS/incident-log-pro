begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid='public.notifications_log'::regclass
      and conname='notifications_delivery_status_check'
  ),
  'delivery status vocabulary constraint exists'
);

select matches(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid='public.notifications_log'::regclass
      and conname='notifications_delivery_status_check'
  ),
  'QUEUED.*SENT.*FAILED',
  'delivery status constraint names QUEUED, SENT and FAILED'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid='public.notifications_log'::regclass
      and conname='notifications_delivery_state_fields_check'
  ),
  'status/timestamp consistency constraint exists'
);

create temporary table c05_notification_ids(
  queued_to_sent uuid,
  queued_to_failed uuid
) on commit drop;

insert into public.notifications_log(
  notification_type,recipient_email,delivery_status,idempotency_key,correlation_id
)
values(
  'C05_TEST_SENT',
  'c05-test@example.invalid',
  'QUEUED',
  'c05-test-sent-'||gen_random_uuid()::text,
  gen_random_uuid()
)
returning id into temporary table c05_sent_returning;

insert into c05_notification_ids(queued_to_sent)
select id from c05_sent_returning;

select ok(
  (
    select delivery_status='QUEUED'
       and sent_at is null
       and failed_at is null
       and failure_reason is null
       and queued_at is not null
       and created_at is not null
    from public.notifications_log
    where id=(select queued_to_sent from c05_notification_ids)
  ),
  'new notification starts QUEUED with server timestamps and no terminal fields'
);

update public.notifications_log
set delivery_status='SENT'
where id=(select queued_to_sent from c05_notification_ids);

select ok(
  (
    select delivery_status='SENT'
       and sent_at is not null
       and failed_at is null
       and failure_reason is null
    from public.notifications_log
    where id=(select queued_to_sent from c05_notification_ids)
  ),
  'QUEUED can transition to SENT with server-generated sent_at'
);

select throws_ok(
  $$
    update public.notifications_log
       set delivery_status='FAILED',
           failure_reason='must remain terminal'
     where id=(select queued_to_sent from c05_notification_ids)
  $$,
  'P0001',
  'terminal notification status is immutable',
  'SENT cannot transition to another terminal status'
);

select throws_ok(
  $$
    insert into public.notifications_log(
      notification_type,recipient_email,delivery_status,idempotency_key,correlation_id
    )
    values(
      'C05_TEST_INVALID',
      'c05-test@example.invalid',
      'TOTALLY_INVALID_STATUS',
      'c05-test-invalid-'||gen_random_uuid()::text,
      gen_random_uuid()
    )
  $$,
  'P0001',
  'notification must start QUEUED',
  'invalid/direct terminal status cannot be inserted'
);

insert into public.notifications_log(
  notification_type,recipient_email,delivery_status,idempotency_key,correlation_id
)
values(
  'C05_TEST_FAILED',
  'c05-test@example.invalid',
  'QUEUED',
  'c05-test-failed-'||gen_random_uuid()::text,
  gen_random_uuid()
)
returning id into temporary table c05_failed_returning;

insert into c05_notification_ids(queued_to_failed)
select id from c05_failed_returning;

select throws_ok(
  $$
    update public.notifications_log
       set delivery_status='FAILED',
           failure_reason=null
     where id=(select queued_to_failed from c05_notification_ids)
  $$,
  'P0001',
  'FAILED notification requires failure_reason',
  'FAILED requires a non-blank reason'
);

update public.notifications_log
set delivery_status='FAILED',
    failure_reason='provider rejected'
where id=(select queued_to_failed from c05_notification_ids);

select ok(
  (
    select delivery_status='FAILED'
       and sent_at is null
       and failed_at is not null
       and failure_reason='provider rejected'
    from public.notifications_log
    where id=(select queued_to_failed from c05_notification_ids)
  ),
  'QUEUED can transition to FAILED with server-generated failed_at and preserved reason'
);

select ok(
  (
    select count(*)=0
    from public.notifications_log
    where delivery_status not in ('QUEUED','SENT','FAILED')
  ),
  'no notification row uses a status outside the canonical vocabulary'
);

select * from finish();
rollback;
