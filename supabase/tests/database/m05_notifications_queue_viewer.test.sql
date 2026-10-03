begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

-- K = Kaue (platform admin), M = Amanda (platform admin, not Kaue), X = a regular person.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values ('a0300000-0000-4000-8000-00000000000c', 'Kaue Pastrello'),
             ('a0300000-0000-4000-8000-00000000000e', 'Amanda Bueno')) as v(id, who)
join private.safra_principals p on p.display_name = v.who;
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('a0300000-0000-4000-8000-00000000000b','queue.viewer.other@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, jsonb_build_object('custom_claims', jsonb_build_object('tid', '45ba725f-d260-45c3-ac85-11f433471277'), 'full_name', u.raw_user_meta_data->>'full_name'), 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0300000-%';
insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0300000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0300000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0300000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0300000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

insert into public.notifications_log(notification_type, recipient_email, delivery_status, idempotency_key,
                                     correlation_id, subject, body)
values ('TREATMENT_OPENED', 'dest@editoradobrasil.com.br', 'QUEUED', 'viewer:1', gen_random_uuid(),
        '[Painel Safra] Assunto', 'Texto que não aparece no visor');
update public.notifications_log set last_error = 'HTTP 503' where idempotency_key = 'viewer:1';

select ok(not has_function_privilege('anon', 'public.safra_admin_get_notifications_queue(integer)', 'execute'),
  'anon cannot read the queue');

select pg_temp.act_as('0b');
select throws_ok('select public.safra_admin_get_notifications_queue(10)', '42501', 'SAFRA_OPS_FORBIDDEN',
  'a regular person cannot read the queue');

select pg_temp.act_as('0e');
select throws_ok('select public.safra_admin_get_notifications_queue(10)', '42501', 'SAFRA_OPS_FORBIDDEN',
  'another admin cannot read the queue (only Kaue)');

select pg_temp.act_as('0c');
select ok((select x->>'error' = 'HTTP 503' and x->>'subject' = '[Painel Safra] Assunto'
           from jsonb_array_elements(public.safra_admin_get_notifications_queue(10)->'items') x
           where x->>'recipient_email' = 'dest@editoradobrasil.com.br'),
  'Kaue sees each e-mail with the reason of the error');
select ok(not exists (select 1 from jsonb_array_elements(public.safra_admin_get_notifications_queue(10)->'items') x
                      where x ? 'body'),
  'the notice text is never shown');

select * from finish();
rollback;
