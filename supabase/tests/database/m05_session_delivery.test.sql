begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- R and X = regular people; K = Kaue (platform admin).
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('a0200000-0000-4000-8000-00000000000a','d132.requester@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp()),
  ('a0200000-0000-4000-8000-00000000000b','d132.other@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select 'a0200000-0000-4000-8000-00000000000c', p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from private.safra_principals p where p.display_name = 'Kaue Pastrello';

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0200000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0200000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0200000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0200000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0200000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;
create function pg_temp.uid(p_who text) returns uuid language sql as $$
  select ('a0200000-0000-4000-8000-0000000000' || p_who)::uuid
$$;
create function pg_temp.notice(p_key text, p_by uuid) returns uuid language sql as $$
  insert into public.notifications_log(notification_type, recipient_email, delivery_status, idempotency_key,
                                       correlation_id, subject, body, triggered_by)
  values ('TREATMENT_OPENED', 'dest@editoradobrasil.com.br', 'QUEUED', 'd132:' || p_key, gen_random_uuid(),
          'Assunto ' || p_key, 'Corpo ' || p_key, p_by)
  returning id
$$;
create function pg_temp.status(p_key text) returns text language sql as $$
  select delivery_status from public.notifications_log where idempotency_key = 'd132:' || p_key
$$;
create function pg_temp.ids(p_claim jsonb) returns text language sql as $$
  select coalesce(string_agg(n.idempotency_key, ',' order by n.idempotency_key), '')
  from jsonb_array_elements(p_claim) x join public.notifications_log n on n.id = (x->>'id')::uuid
$$;

-- 1. Grants ----------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.safra_notifications_claim_for_session(integer)', 'execute'),
  'anon cannot claim the queue');
select ok(not has_function_privilege('anon', 'public.safra_notifications_report_for_session(uuid,boolean,text)', 'execute'),
  'anon cannot report deliveries');
select ok(not has_function_privilege('authenticated', 'public.safra_notifications_claim(integer)', 'execute'),
  'the original claim stays service_role only');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000099","role":"authenticated","email":"x@gmail.com"}', true);
select throws_ok('select public.safra_notifications_claim_for_session(5)', '42501', 'SAFRA_DELIVERY_FORBIDDEN',
  'a non-corporate user is refused');

-- 2. Who generated the notice ----------------------------------------------------------------
select pg_temp.act_as('0a');
insert into public.notifications_log(notification_type, recipient_email, delivery_status, idempotency_key, correlation_id)
values ('TREATMENT_OPENED', 'dest@editoradobrasil.com.br', 'QUEUED', 'd132:default', gen_random_uuid());
select is((select triggered_by from public.notifications_log where idempotency_key = 'd132:default'), pg_temp.uid('0a'),
  'a notice queued during a person''s action records that person');
update public.notifications_log set delivery_status = 'FAILED', failure_reason = 'TEST' where idempotency_key = 'd132:default';

select pg_temp.notice('r', pg_temp.uid('0a'));
select pg_temp.notice('x', pg_temp.uid('0b'));
select pg_temp.notice('sys', null);

-- 3. A regular person delivers only the notices of their own action -------------------------
select pg_temp.act_as('0a');
select is(pg_temp.ids(public.safra_notifications_claim_for_session(20)), 'd132:r',
  'R claims only the notice that R''s action generated');

select pg_temp.act_as('0b');
select public.safra_notifications_report_for_session(
  (select id from public.notifications_log where idempotency_key = 'd132:r'), true, null);
select is(pg_temp.status('r'), 'QUEUED', 'X cannot mark R''s notice as sent');

select pg_temp.act_as('0a');
select public.safra_notifications_report_for_session(
  (select id from public.notifications_log where idempotency_key = 'd132:r'), true, null);
select is(pg_temp.status('r'), 'SENT', 'R reports R''s delivery');

select pg_temp.act_as('0b');
select is(pg_temp.ids(public.safra_notifications_claim_for_session(20)), 'd132:x',
  'X claims only X''s notice, never the system ones');

-- 4. Governance and admins deliver the rest, including system notices ----------------------
select pg_temp.act_as('0c');
select is(pg_temp.ids(public.safra_notifications_claim_for_session(20)), 'd132:sys',
  'Kaue (admin) claims the system notice; X''s notice is locked by X''s round');
select public.safra_notifications_report_for_session(
  (select id from public.notifications_log where idempotency_key = 'd132:sys'), false, 'HTTP 503');
select ok((select delivery_status = 'QUEUED' and last_error = 'HTTP 503' and locked_until is null
           from public.notifications_log where idempotency_key = 'd132:sys'),
  'a failed delivery goes back to the queue with the reason');

select pg_temp.act_as('0a');
select is(pg_temp.ids(public.safra_notifications_claim_for_session(20)), '',
  'R gets nothing more: X''s and the system notices are not R''s');

select * from finish();
rollback;
