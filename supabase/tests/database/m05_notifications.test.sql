begin;
create extension if not exists pgtap with schema extensions;
select plan(30);

-- R = requester; O = owner of SAFRA-09 (Renato); J = Jair (governance).
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('a0050000-0000-4000-8000-00000000000a','m05.requester@editoradobrasil.com.br','{"provider":"azure"}','{"full_name":"Paula Pedido"}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values
  ('a0050000-0000-4000-8000-00000000000d', 'Renato de Paulo'),
  ('a0050000-0000-4000-8000-00000000000e', 'Jair Silva')
) as v(id, who)
join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0050000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0050000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0050000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0050000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0050000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

create temp table ctx(k text primary key, v text);
create function pg_temp.t(p_k text) returns uuid language sql as $$ select v::uuid from ctx where k = p_k $$;
create function pg_temp.open(p_k text, p_key text) returns void language sql as $$
  insert into ctx
  select p_k, r->>'treatment_id'
  from (select public.safra_start_treatment((select id from public.scenarios where code = 'SAFRA-09'), p_key::uuid,
          'Pedidos parados na integração desde as 9h', '{}'::uuid[]) r) x;
$$;
create function pg_temp.age(p_k text, p_open interval) returns void language plpgsql as $$
begin
  execute 'alter table public.treatments disable trigger user';
  update public.treatments
     set opened_at = opened_at - p_open, problem_started_at = problem_started_at - p_open,
         created_at = created_at - p_open,
         requester_closed_at = requester_closed_at - p_open,
         owner_closed_at = owner_closed_at - p_open
   where id = pg_temp.t(p_k);
  execute 'alter table public.treatments enable trigger user';
end;
$$;
-- Avisos de um protocolo: "TIPO>papel", em ordem alfabética (estável entre execuções).
create function pg_temp.sent(p_k text) returns text language sql as $$
  select string_agg(notification_type || '>' || recipient_role, ',' order by notification_type, recipient_role)
  from public.notifications_log where treatment_id = pg_temp.t(p_k);
$$;
create function pg_temp.owner_email() returns text language sql as $$
  select lower(corporate_email) from private.safra_principals where display_name = 'Renato de Paulo';
$$;

-- 1. Who gets which notice (D-111) -----------------------------------------------
select pg_temp.act_as('0a');
select pg_temp.open('t1', 'a0050000-0000-4000-8000-000000000901');

select is(pg_temp.sent('t1'), 'TREATMENT_OPENED>OWNER,TREATMENT_OPENED>REQUESTER',
  'D-111: opening notifies the card owner and who opened');
select is((select count(*)::int from public.notifications_log where lower(recipient_email) = 'jair.silva@editoradobrasil.com.br'), 0,
  'D-111: Jair receives no e-mail');
select ok((select bool_and(delivery_status = 'QUEUED' and channel = 'EMAIL' and template_version = 1 and attempts = 0)
           from public.notifications_log where treatment_id = pg_temp.t('t1')),
  'M05: notices start queued, by e-mail, template version 1');

select ok((select subject = '[Painel Safra] Novo protocolo ' || (select protocol_number from public.treatments where id = pg_temp.t('t1')) || ' no seu card'
           from public.notifications_log where treatment_id = pg_temp.t('t1') and recipient_role = 'OWNER'),
  'D-114: the owner subject says there is a new protocol on the card');
select ok((select body like '%Paula Pedido abriu o protocolo%' and body like '%Problema: Pedidos parados na integração desde as 9h%'
                  and body like '%https://painelsafra.lovable.app/protocolos-dos-meus-cards%'
           from public.notifications_log where treatment_id = pg_temp.t('t1') and recipient_role = 'OWNER'),
  'D-114: the e-mail has who opened, the summary and the link to the Painel');
select ok((select body like '%/meus-protocolos%' and lower(recipient_email) = 'm05.requester@editoradobrasil.com.br'
           from public.notifications_log where treatment_id = pg_temp.t('t1') and recipient_role = 'REQUESTER'),
  'D-114: who opened gets the link to "Meus protocolos"');

-- Closing a part does not notify; undo notifies the other party.
select public.safra_close_my_part(pg_temp.t('t1'));
select is((select count(*)::int from public.notifications_log where treatment_id = pg_temp.t('t1')), 2,
  'D-111: closing one part sends no notice');
select public.safra_undo_my_part(pg_temp.t('t1'));
select is((select recipient_role from public.notifications_log where treatment_id = pg_temp.t('t1') and notification_type = 'PART_UNDONE'), 'OWNER',
  'D-111: requester undo notifies the owner');
select ok((select body like '%Paula Pedido desfez a conclusão%' from public.notifications_log
           where treatment_id = pg_temp.t('t1') and notification_type = 'PART_UNDONE'),
  'D-114: the undo notice says who undid');

-- Both close: resolved notice to both.
select public.safra_close_my_part(pg_temp.t('t1'));
select pg_temp.act_as('0d');
select public.safra_close_my_part(pg_temp.t('t1'));
select is((select count(*)::int from public.notifications_log where treatment_id = pg_temp.t('t1') and notification_type = 'TREATMENT_RESOLVED'), 2,
  'D-111: resolution notifies both');

-- Cancel: both, with the reason.
select pg_temp.act_as('0a');
select pg_temp.open('t2', 'a0050000-0000-4000-8000-000000000902');
select public.safra_cancel_treatment(pg_temp.t('t2'), 'Abri no card errado, desculpem');
select ok((select count(*) = 2 and bool_and(body like '%Motivo: Abri no card errado, desculpem%')
           from public.notifications_log where treatment_id = pg_temp.t('t2') and notification_type = 'TREATMENT_CANCELLED'),
  'D-111/D-114: cancel notifies both with the reason');

-- No duplicates for the same event and person.
select ok((select count(*) = count(distinct idempotency_key) from public.notifications_log),
  'M05: one notice per event and person (unique key)');

-- 2. Reminders 24/12/1 h before the 72 h close (D-112) ------------------------------
-- t4: who opened closes at once (frees the D-57 lock); t3: nobody closes.
select pg_temp.open('t4', 'a0050000-0000-4000-8000-000000000904');
select public.safra_close_my_part(pg_temp.t('t4'));
select pg_temp.open('t3', 'a0050000-0000-4000-8000-000000000903');
select pg_temp.age('t3', interval '49 hours');
select pg_temp.age('t4', interval '49 hours');
select private.safra_auto_cancel_stale();

select ok(pg_temp.sent('t3') like '%REMINDER_24H>OWNER,REMINDER_24H>REQUESTER%',
  'D-112: with 48 h and nobody closed, both get the 24 h reminder');
select ok((select bool_and(body like '%será cancelado automaticamente em%') from public.notifications_log
           where treatment_id = pg_temp.t('t3') and notification_type = 'REMINDER_24H'),
  'D-112: the reminder says it will be cancelled automatically, and when');
select is((select string_agg(recipient_role, ',') from public.notifications_log where treatment_id = pg_temp.t('t4') and notification_type = 'REMINDER_24H'), 'OWNER',
  'D-112: only who has not closed is reminded');
select ok((select body like '%será encerrado automaticamente, valendo a parte já concluída%' from public.notifications_log
           where treatment_id = pg_temp.t('t4') and notification_type = 'REMINDER_24H'),
  'D-112/D-113: the reminder says it will be resolved automatically');

select private.safra_auto_cancel_stale();
select is((select count(*)::int from public.notifications_log where treatment_id = pg_temp.t('t3') and notification_type like 'REMINDER_%'), 2,
  'D-112: the sweep does not repeat a reminder');
select pg_temp.age('t3', interval '12 hours');
select private.safra_auto_cancel_stale();
select is((select count(*)::int from public.notifications_log where treatment_id = pg_temp.t('t3') and notification_type = 'REMINDER_12H'), 2,
  'D-112: at 60 h, the 12 h reminder');
select pg_temp.age('t3', interval '10 hours 30 minutes');
select private.safra_auto_cancel_stale();
select is((select count(*)::int from public.notifications_log where treatment_id = pg_temp.t('t3') and notification_type = 'REMINDER_1H'), 2,
  'D-112: at 71 h, the 1 h reminder');

-- 3. Auto-close at 72 h (D-101, D-113) ------------------------------------------
select pg_temp.age('t4', interval '24 hours');
select pg_temp.age('t3', interval '1 hour');
select ok(private.safra_auto_cancel_stale() >= 2, 'the sweep closes stale protocols');
select is((select status || '/' || auto_resolved::text || '/' || (closed_by is null)::text from public.treatments where id = pg_temp.t('t4')),
  'RESOLVED/true/true', 'D-113: 72 h with one part closed -> resolved automatically, no human author');
select ok((select count(*) = 2 and bool_and(body like '%encerrado automaticamente%') from public.notifications_log
           where treatment_id = pg_temp.t('t4') and notification_type = 'TREATMENT_RESOLVED'),
  'D-113: both are told it was resolved automatically');
select is((select status from public.treatments where id = pg_temp.t('t3')), 'CANCELLED',
  'D-101: nobody closed in 72 h -> cancelled');

-- 4. Sender: claim, retry, expire (service_role only) -------------------------------
select ok(not has_function_privilege('authenticated', 'public.safra_notifications_claim(integer)', 'EXECUTE')
          and not has_function_privilege('anon', 'public.safra_notifications_claim(integer)', 'EXECUTE')
          and not has_function_privilege('authenticated', 'public.safra_notifications_report(uuid, boolean, text)', 'EXECUTE'),
  'M05: only the sending service can take and report notices');

-- The sender functions run as their owner (SECURITY DEFINER); the grants are checked above.
-- Reminders of protocols that are no longer active expire instead of being sent late.
select ok(jsonb_array_length(public.safra_notifications_claim(100)) >= 1, 'the sender takes queued notices');
select is((select count(*)::int from public.notifications_log
           where treatment_id = pg_temp.t('t3') and notification_type like 'REMINDER_%' and failure_reason = 'EXPIRED_PROTOCOL_NOT_ACTIVE'), 6,
  'M05: reminders of a closed protocol expire');

create temp table one as
select id from public.notifications_log where treatment_id = pg_temp.t('t1') and notification_type = 'TREATMENT_OPENED' and recipient_role = 'OWNER';
select public.safra_notifications_report((select id from one), true);
select is((select delivery_status from public.notifications_log where id = (select id from one)), 'SENT', 'M05: a delivered notice is SENT');

create temp table two as
select id from public.notifications_log where treatment_id = pg_temp.t('t1') and notification_type = 'TREATMENT_OPENED' and recipient_role = 'REQUESTER';
select public.safra_notifications_report((select id from two), false, 'HTTP 503');
select ok((select delivery_status = 'QUEUED' and last_error = 'HTTP 503' and next_attempt_at > clock_timestamp()
           from public.notifications_log where id = (select id from two)),
  'M05: a failed send is retried later');
-- the 5th round claimed it again (a result only counts while that round holds the lock)
update public.notifications_log set attempts = 5, locked_until = clock_timestamp() + interval '5 minutes'
 where id = (select id from two);
select public.safra_notifications_report((select id from two), false, 'HTTP 503');
select is((select delivery_status || '/' || failure_reason from public.notifications_log where id = (select id from two)),
  'FAILED/SEND_FAILED: HTTP 503', 'M05: after 5 attempts the notice is FAILED with the reason');

select ok(not has_table_privilege('authenticated', 'public.notifications_log', 'SELECT'),
  'nobody reads the notification queue directly');

select * from finish();
rollback;
