begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

-- P = proposer (regular), J = Jair (governance), D = Daniel (card owner consulted).
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('a0400000-0000-4000-8000-00000000000a','audit.proposer@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values ('a0400000-0000-4000-8000-00000000000c', 'Jair Silva'),
             ('a0400000-0000-4000-8000-0000000000d1', 'Daniel Garcia')) as v(id, who)
join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0400000-%';
insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0400000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0400000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0400000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0400000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;
create function pg_temp.notice(p_key text) returns uuid language sql as $$
  insert into public.notifications_log(notification_type, recipient_email, delivery_status, idempotency_key,
                                       correlation_id, subject, body)
  values ('TREATMENT_OPENED', 'dest@editoradobrasil.com.br', 'QUEUED', 'audit:' || p_key, gen_random_uuid(), 'S', 'B')
  returning id
$$;
create function pg_temp.row_of(p_key text) returns public.notifications_log language sql as $$
  select * from public.notifications_log where idempotency_key = 'audit:' || p_key
$$;
create temp table ctx(k text primary key, v text);

select ok((select count(*) from auth.users where id::text like 'a0400000-%') = 3, 'setup: the three people exist');

-- A1. A notice claimed 5 times without a result no longer blocks the queue ------------------
select pg_temp.notice('stuck');
update public.notifications_log set attempts = 5 where idempotency_key = 'audit:stuck';
select pg_temp.notice('next');
select lives_ok($$ select public.safra_notifications_claim(20) $$,
  'A1: the claim does not break on a notice that already used its 5 attempts');
select ok((pg_temp.row_of('stuck')).delivery_status = 'FAILED'
          and (pg_temp.row_of('stuck')).failure_reason = 'SEND_FAILED: NO_REPORT'
          and (pg_temp.row_of('next')).attempts = 1,
  'A1: the stuck notice fails with a reason and the next one is claimed');

-- A2. A late result (the round lost its lock) is ignored ------------------------------------
update public.notifications_log set locked_until = clock_timestamp() - interval '1 minute' where idempotency_key = 'audit:next';
select public.safra_notifications_report((pg_temp.row_of('next')).id, true, null);
select is((pg_temp.row_of('next')).delivery_status, 'QUEUED', 'A2: a result after the lock expired does not count');

-- A4. A long proposal fits in the e-mail limit ----------------------------------------------
select pg_temp.act_as('0a');
select lives_ok($$ insert into ctx values ('long', public.safra_submit_proposal('Proposta com textos longos',
  repeat('Problema muito detalhado. ', 115), repeat('Efeito muito detalhado. ', 125))::text) $$,
  'A4: a proposal with 3000 + 3000 characters is accepted');
select ok((select max(length(body)) <= 6000 and count(*) >= 1 from public.notifications_log
           where proposal_id = (select v::uuid from ctx where k = 'long')),
  'A4: its notices stay within 6000 characters');

-- A5. Card owners only see a proposal after Jair forwards it --------------------------------
insert into ctx values ('quiet', public.safra_submit_proposal('Proposta recusada sem encaminhar',
  'Problema de teste para recusar.', 'Efeito de teste para recusar.')::text);
select pg_temp.act_as('0c');
select public.safra_reject_proposal((select v::uuid from ctx where k = 'quiet'), 'Não é um problema da Safra.');
select pg_temp.act_as('d1');
select ok(not exists (select 1 from jsonb_array_elements(public.safra_get_proposals()->'items') x
                      where x->>'proposal_id' = (select v from ctx where k = 'quiet')),
  'A5: a proposal rejected before forwarding is not shown to card owners');

-- A7. The disposable database never calls the production sender -----------------------------
select is((select count(*)::int from cron.job where jobname = 'safra-send-notifications'), 0,
  'A7: without the owner login at migration time there is no schedule calling production');

select * from finish();
rollback;
