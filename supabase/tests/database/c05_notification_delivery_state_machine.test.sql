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

insert into public.notifications_log(
  id,notification_type,recipient_email,delivery_status,idempotency_key,correlation_id
)
values(
  '05050505-9000-4000-8000-000000000001'::uuid,
  'C05_TEST_SENT',
  'c05-test@example.invalid',
  'QUEUED',
  'c05-test-sent-05050505-9000-4000-8000-000000000001',
  '05050505-9000-4000-8000-000000000011'::uuid
);

select ok(
  (
    select delivery_status='QUEUED'
       and sent_at is null
       and failed_at is null
       and failure_reason is null
       and queued_at is not null
       and created_at is not null
    from public.notifications_log
    where id='05050505-9000-4000-8000-000000000001'::uuid
  ),
  'new notification starts QUEUED with server timestamps and no terminal fields'
);

update public.notifications_log
set delivery_status='SENT'
where id='05050505-9000-4000-8000-000000000001'::uuid;

select ok(
  (
    select delivery_status='SENT'
       and sent_at is not null
       and failed_at is null
       and failure_reason is null
    from public.notifications_log
    where id='05050505-9000-4000-8000-000000000001'::uuid
  ),
  'QUEUED can transition to SENT with server-generated sent_at'
);

select throws_ok(
  $$
    update public.notifications_log
       set delivery_status='FAILED',
           failure_reason='must remain terminal'
     where id='05050505-9000-4000-8000-000000000001'::uuid
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
      'c05-test-invalid-05050505-9000-4000-8000-000000000099',
      '05050505-9000-4000-8000-000000000099'::uuid
    )
  $$,
  'P0001',
  'notification must start QUEUED',
  'invalid/direct terminal status cannot be inserted'
);

insert into public.notifications_log(
  id,notification_type,recipient_email,delivery_status,idempotency_key,correlation_id
)
values(
  '05050505-9000-4000-8000-000000000002'::uuid,
  'C05_TEST_FAILED',
  'c05-test@example.invalid',
  'QUEUED',
  'c05-test-failed-05050505-9000-4000-8000-000000000002',
  '05050505-9000-4000-8000-000000000012'::uuid
);

select throws_ok(
  $$
    update public.notifications_log
       set delivery_status='FAILED',
           failure_reason=null
     where id='05050505-9000-4000-8000-000000000002'::uuid
  $$,
  'P0001',
  'FAILED notification requires failure_reason',
  'FAILED requires a non-blank reason'
);

update public.notifications_log
set delivery_status='FAILED',
    failure_reason='provider rejected'
where id='05050505-9000-4000-8000-000000000002'::uuid;

select ok(
  (
    select delivery_status='FAILED'
       and sent_at is null
       and failed_at is not null
       and failure_reason='provider rejected'
    from public.notifications_log
    where id='05050505-9000-4000-8000-000000000002'::uuid
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
