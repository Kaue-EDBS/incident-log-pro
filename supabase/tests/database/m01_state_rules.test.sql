begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

-- Actors: R and R2 request; O is the owner of SAFRA-09 (Renato); T is a third party.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('a0010000-0000-4000-8000-00000000000a','m01.requester@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp()),
  ('a0010000-0000-4000-8000-00000000000b','m01.requester2@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp()),
  ('a0010000-0000-4000-8000-00000000000c','m01.third@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select 'a0010000-0000-4000-8000-00000000000d', corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from private.safra_principals where display_name = 'Renato de Paulo';

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0010000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0010000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0010000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0010000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0010000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

create temp table ctx(k text primary key, v text);
create function pg_temp.t(p_k text) returns uuid language sql as $$ select v::uuid from ctx where k = p_k $$;
create function pg_temp.card(p_code text) returns uuid language sql as $$ select id from public.scenarios where code = p_code $$;
create function pg_temp.open(p_k text, p_card text, p_key text) returns void language sql as $$
  insert into ctx
  select p_k, r->>'treatment_id'
  from (select public.safra_start_treatment(pg_temp.card(p_card), p_key::uuid,
          'M01: protocolo de teste das regras', '{}'::uuid[]) r) x;
$$;
-- Move a protocol back in time (test only; the server clock normally forbids it).
create function pg_temp.age(p_k text, p_open interval, p_part interval default null) returns void language plpgsql as $$
begin
  execute 'alter table public.treatments disable trigger user';
  update public.treatments
     set opened_at = opened_at - p_open,
         problem_started_at = problem_started_at - p_open,
         created_at = created_at - p_open,
         requester_closed_at = case when p_part is null then requester_closed_at else requester_closed_at - p_part end
   where id = pg_temp.t(p_k);
  execute 'alter table public.treatments enable trigger user';
end;
$$;

-- 1. D-99: desfazer a própria parte em até 5 minutos -----------------------------
select pg_temp.act_as('0a');
select pg_temp.open('t1', 'SAFRA-09', 'a0010000-0000-4000-8000-000000000901');

select ok((public.safra_get_my_treatments()->0->>'auto_cancel_at') is not null,
  'D-101: a fresh protocol shows when it will be cancelled automatically');

select throws_ok($$ select public.safra_undo_my_part(pg_temp.t('t1')) $$,
  'P0001', 'SAFRA_UNDO_NOTHING_TO_UNDO', 'D-99: nothing to undo before closing');

select is((public.safra_close_my_part(pg_temp.t('t1')))->>'situation', 'AGUARDANDO_DONO',
  'requester closes the part');

select ok(
  (select (x->>'can_undo_my_part')::boolean and (x->>'undo_until') is not null and (x->>'auto_cancel_at') is null
   from jsonb_array_elements(public.safra_get_my_treatments()) x where x->>'treatment_id' = pg_temp.t('t1')::text),
  'D-99: the view offers undo with a deadline; D-101 no longer applies once a part closed');

select pg_temp.act_as('0c');
select throws_ok($$ select public.safra_undo_my_part(pg_temp.t('t1')) $$,
  '42501', 'SAFRA_UNDO_FORBIDDEN', 'D-99: a third party cannot undo');

select pg_temp.act_as('0a');
select is((public.safra_undo_my_part(pg_temp.t('t1')))->>'situation', 'EM_ANDAMENTO',
  'D-99: the requester undoes within 5 minutes');

select ok((select requester_closed_at is null from public.treatments where id = pg_temp.t('t1')),
  'D-99: the requester part is open again');

select is((select count(*)::int from public.treatment_events
           where treatment_id = pg_temp.t('t1') and event_type = 'REQUESTER_PART_UNDONE'
             and payload->>'undone_closed_at' is not null), 1,
  'D-99: the undo is recorded as an append-only event');

-- Owner part.
select pg_temp.act_as('0d');
select is((public.safra_close_my_part(pg_temp.t('t1')))->>'situation', 'AGUARDANDO_SOLICITANTE',
  'owner closes the part');
select is((public.safra_undo_my_part(pg_temp.t('t1')))->>'situation', 'EM_ANDAMENTO',
  'D-99: the owner undoes within 5 minutes');
select ok((select owner_closed_at is null and owner_closed_by is null from public.treatments where id = pg_temp.t('t1')),
  'D-99: owner part and author are cleared');
select is((select count(*)::int from public.treatment_events
           where treatment_id = pg_temp.t('t1') and event_type = 'OWNER_PART_UNDONE'), 1,
  'D-99: owner undo is recorded');

-- After 5 minutes.
select pg_temp.act_as('0a');
select public.safra_close_my_part(pg_temp.t('t1'));
select pg_temp.age('t1', interval '1 hour', interval '6 minutes');

select ok(
  (select not (x->>'can_undo_my_part')::boolean
   from jsonb_array_elements(public.safra_get_my_treatments()) x where x->>'treatment_id' = pg_temp.t('t1')::text),
  'D-99: after 5 minutes the view no longer offers undo');
select throws_ok($$ select public.safra_undo_my_part(pg_temp.t('t1')) $$,
  'P0001', 'SAFRA_UNDO_WINDOW_EXPIRED', 'D-99: undo after 5 minutes is refused');

-- The database itself keeps a closed part, even for a direct update.
update public.treatments set requester_closed_at = null where id = pg_temp.t('t1');
select ok((select requester_closed_at is not null from public.treatments where id = pg_temp.t('t1')),
  'D-99: a direct update cannot clear a closed part');

-- Resolved protocols cannot be undone (D-98).
select pg_temp.act_as('0b');
select pg_temp.open('t2', 'SAFRA-09', 'a0010000-0000-4000-8000-000000000902');
select public.safra_close_my_part(pg_temp.t('t2'));
select pg_temp.act_as('0d');
select is((public.safra_close_my_part(pg_temp.t('t2')))->>'situation', 'ENCERRADO',
  'both parts closed: ENCERRADO');
select pg_temp.act_as('0b');
select throws_ok($$ select public.safra_undo_my_part(pg_temp.t('t2')) $$,
  'P0001', 'SAFRA_TREATMENT_NOT_ACTIVE', 'D-98/D-99: an ENCERRADO protocol cannot be undone');

-- D-57: undo is blocked when the person already opened another protocol on the same card.
select pg_temp.act_as('0a');
select pg_temp.open('t3', 'SAFRA-07', 'a0010000-0000-4000-8000-000000000903');
select public.safra_close_my_part(pg_temp.t('t3'));
select pg_temp.open('t4', 'SAFRA-07', 'a0010000-0000-4000-8000-000000000904');
select throws_ok($$ select public.safra_undo_my_part(pg_temp.t('t3')) $$,
  'P0001', 'SAFRA_UNDO_BLOCKED_BY_NEW_PROTOCOL', 'D-57/D-99: undo refused when a new protocol is open on the card');

-- 2. D-98: sem reabrir -----------------------------------------------------------
select throws_ok(
  $$ update public.treatments set status = 'ACTIVE', closed_by = null, closed_at = null where id = pg_temp.t('t2') $$,
  'P0001', 'closed treatment row is immutable; record an append-only correction event instead',
  'D-98: an ENCERRADO protocol never goes back to ACTIVE');

select ok(not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'public' and p.proname ~* '(reopen|reabrir)'),
  'D-98: there is no reopen command');

-- 3. D-100: sem correção pelo admin ----------------------------------------------
select ok(not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'public' and p.proname ~* '(correct|corrig|edit_treatment|update_treatment)'),
  'D-100: there is no admin correction command');

-- 4. D-101: cancelamento automático em 72 h ---------------------------------------
select pg_temp.act_as('0b');
select pg_temp.open('t5', 'SAFRA-09', 'a0010000-0000-4000-8000-000000000905');
select pg_temp.age('t5', interval '73 hours');
select pg_temp.age('t1', interval '73 hours');  -- requester part closed: must stay
select pg_temp.open('t6', 'SAFRA-04', 'a0010000-0000-4000-8000-000000000906');
select pg_temp.age('t6', interval '71 hours');  -- under 72 h: must stay

select ok(private.safra_auto_cancel_stale() >= 1, 'D-101: the sweep cancels stale protocols');

select ok(
  (select status = 'CANCELLED' and auto_cancelled and cancelled_by is null
          and cancellation_reason like 'Cancelado automaticamente: 72 horas%'
   from public.treatments where id = pg_temp.t('t5')),
  'D-101: 72 h without any closed part -> CANCELLED automatically, no human author');

select is((select count(*)::int from public.treatment_events
           where treatment_id = pg_temp.t('t5') and event_type = 'TREATMENT_CANCELLED'
             and actor_user_id is null and payload->>'source' = 'SAFRA_M01_AUTO_CANCEL_72H'), 1,
  'D-101: the automatic cancel is recorded as an event without actor');

select is((select status from public.treatments where id = pg_temp.t('t1')), 'ACTIVE',
  'D-101: a protocol with one part closed is never cancelled automatically');

select is((select status from public.treatments where id = pg_temp.t('t6')), 'ACTIVE',
  'D-101: a protocol under 72 h is not cancelled');

select is(private.safra_auto_cancel_stale(), 0, 'D-101: the sweep is idempotent');

select ok(
  (select (x->>'auto_cancelled')::boolean and x->>'situation' = 'CANCELADO'
   from jsonb_array_elements(public.safra_get_my_treatments()) x where x->>'treatment_id' = pg_temp.t('t5')::text),
  'D-101: the person sees the protocol as automatically cancelled');

-- A person cannot fake an automatic cancel (no author and no flag).
select throws_ok(
  $$ update public.treatments set status = 'CANCELLED', cancelled_by = null, cancelled_at = now(),
       cancellation_reason = 'tentativa sem autor' where id = pg_temp.t('t6') $$,
  '23514', null, 'D-101: CANCELLED without author is only allowed for the automatic cancel');

select is((select count(*)::int from cron.job where jobname = 'safra-auto-cancel-72h' and schedule = '*/10 * * * *'), 1,
  'D-101: the sweep is scheduled every 10 minutes');
select is((select count(*)::int from cron.job where jobname = 'safra-cron-log-cleanup'), 1,
  'the scheduler log is trimmed daily (7 days)');

-- 5. Surface ---------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.safra_undo_my_part(uuid)', 'EXECUTE'),
  'anon cannot undo');
select ok(not has_function_privilege('authenticated', 'private.safra_auto_cancel_stale()', 'EXECUTE'),
  'only the scheduler runs the automatic cancel');
select ok((select prosecdef from pg_proc where proname = 'safra_undo_my_part'),
  'undo is a governed SECURITY DEFINER command');

select * from finish();
rollback;
