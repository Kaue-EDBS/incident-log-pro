begin;
create extension if not exists pgtap with schema extensions;
select plan(35);

-- Actors: R and R2 request; O is the owner of SAFRA-09 (Renato); T is a third party.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('c0810000-0000-4000-8000-00000000000a','c081.requester@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp()),
  ('c0810000-0000-4000-8000-00000000000b','c081.requester2@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp()),
  ('c0810000-0000-4000-8000-00000000000c','c081.third@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select 'c0810000-0000-4000-8000-00000000000d', corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from private.safra_principals where display_name = 'Renato de Paulo';

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, jsonb_build_object('custom_claims', jsonb_build_object('tid', '45ba725f-d260-45c3-ac85-11f433471277'), 'full_name', u.raw_user_meta_data->>'full_name'), 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'c0810000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('c0810000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'c0810000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'c0810000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('c0810000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

create temp table ctx(k text primary key, v text);
create function pg_temp.t(p_k text) returns uuid language sql as $$ select v::uuid from ctx where k = p_k $$;
create function pg_temp.card(p_code text) returns uuid language sql as $$ select id from public.scenarios where code = p_code $$;

-- 1. START validations (D-83, D-89) ---------------------------------------------
select pg_temp.act_as('0a');

select throws_ok(
  $$ select public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000901'::uuid, null, '{}'::uuid[]) $$,
  '22023', 'SAFRA_IMPACT_SUMMARY_REQUIRED', 'D-83: START without a problem summary is refused');

select throws_ok(
  $$ select public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000902'::uuid, 'curto', '{}'::uuid[]) $$,
  '22023', 'SAFRA_IMPACT_SUMMARY_REQUIRED', 'D-83: a summary shorter than 10 characters is refused');

select throws_ok(
  $$ select public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000903'::uuid,
       'Ruptura do título X no pico', '{}'::uuid[], now() + interval '1 hour') $$,
  '22023', 'SAFRA_PROBLEM_START_IN_FUTURE', 'D-89: problem start in the future is refused');

insert into ctx
select 't1', r->>'treatment_id'
from (select public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000904'::uuid,
        'Ruptura do título X no pico', '{}'::uuid[], now() - interval '30 minutes') r) x;

select is((select protocol_number from public.treatments where id = pg_temp.t('t1')), '09-0001',
  'D-82: first protocol of card 09 is 09-0001');

select ok((select problem_started_at < opened_at - interval '29 minutes' from public.treatments where id = pg_temp.t('t1')),
  'D-89: reported problem start is stored before the opening');

select is(
  (public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000904'::uuid,
     'Ruptura do título X no pico', '{}'::uuid[]))->>'protocol_number',
  '09-0001', 'idempotent replay returns the same protocol number');

select throws_ok(
  $$ select public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000905'::uuid,
       'Segunda abertura do mesmo card', '{}'::uuid[]) $$,
  'P0001', 'SAFRA_START_ACTIVE_EXISTS', 'D-57: second open requester part on the same card is refused');

select ok(
  (select (c->'my_open_treatment'->>'protocol_number') = '09-0001'
          and (c->'my_open_treatment'->>'situation') = 'EM_ANDAMENTO'
   from jsonb_array_elements(public.safra_get_start_catalog()) c where c->>'code' = 'SAFRA-09'),
  'catalog shows my open protocol on the card');

-- 2. Sequence per card -----------------------------------------------------------
select pg_temp.act_as('0b');
insert into ctx
select 't2', r->>'treatment_id'
from (select public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000906'::uuid,
        'Outro solicitante no mesmo card', '{}'::uuid[]) r) x;
insert into ctx
select 't4', r->>'treatment_id'
from (select public.safra_start_treatment(pg_temp.card('SAFRA-03'), 'c0810000-0000-4000-8000-000000000907'::uuid,
        'Pedidos parados há mais de 48h', '{}'::uuid[]) r) x;

select is(
  (select string_agg(protocol_number, ',' order by protocol_number) from public.treatments
   where id in (pg_temp.t('t2'), pg_temp.t('t4'))),
  '03-0001,09-0002', 'D-82: sequence is per card (09-0002 and 03-0001)');

select is(jsonb_array_length(public.safra_get_my_treatments()), 2, 'my protocols lists only my own (R2 has 2)');

select pg_temp.act_as('0a');
select is(jsonb_array_length(public.safra_get_my_treatments()), 1, 'my protocols does not leak other requesters');

-- 3. Third party cannot act -------------------------------------------------------
select pg_temp.act_as('0c');
select throws_ok($$ select public.safra_close_my_part(pg_temp.t('t1')) $$, '42501', 'SAFRA_CLOSE_FORBIDDEN',
  'D-64: a third party cannot close a protocol');
select throws_ok($$ select public.safra_cancel_treatment(pg_temp.t('t1'), 'tentativa de terceiro') $$, '42501', 'SAFRA_CANCEL_FORBIDDEN',
  'D-66: a third party cannot cancel a protocol');
select is(jsonb_array_length(public.safra_get_owner_treatments()), 0, 'a non-owner sees no card protocols');

-- 4. Requester closes first (D-66/D-72) -------------------------------------------
select pg_temp.act_as('0a');
select is(public.safra_close_my_part(pg_temp.t('t1'))->>'situation', 'AGUARDANDO_DONO',
  'D-72: requester closes first -> waiting for the owner');
select is(public.safra_close_my_part(pg_temp.t('t1'))->>'already_closed', 'true',
  'double click on close is idempotent');
select is((select count(*)::int from public.treatment_events where treatment_id = pg_temp.t('t1') and event_type = 'REQUESTER_PART_CLOSED'), 1,
  'only one REQUESTER_PART_CLOSED event');

insert into ctx
select 't3', r->>'treatment_id'
from (select public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000908'::uuid,
        'Nova ruptura após fechar a minha parte', '{}'::uuid[]) r) x;
select is((select protocol_number from public.treatments where id = pg_temp.t('t3')), '09-0003',
  'D-66: closing the requester part releases the lock; next protocol is 09-0003');

-- 5. Owner (Renato) ---------------------------------------------------------------
select pg_temp.act_as('0d');
select is(jsonb_array_length(public.safra_get_owner_treatments()), 3, 'owner sees the 3 protocols of his card only');
select throws_ok($$ select public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000909'::uuid,
       'Dono tentando abrir o próprio card', '{}'::uuid[]) $$, 'P0001', 'SAFRA_START_OWNER_OWN_CARD',
  'D-65 still holds');

select is(public.safra_close_my_part(pg_temp.t('t1'))->>'situation', 'ENCERRADO',
  'owner closes the last part -> protocol closed');
select ok((select status = 'RESOLVED' and closed_at is not null and owner_closed_by = 'c0810000-0000-4000-8000-00000000000d'::uuid
           from public.treatments where id = pg_temp.t('t1')),
  'RESOLVED with server time and owner as author of his part');
select is((select string_agg(event_type, ',' order by occurred_at, event_type) from public.treatment_events where treatment_id = pg_temp.t('t1')),
  'TREATMENT_OPENED,REQUESTER_PART_CLOSED,OWNER_PART_CLOSED,TREATMENT_RESOLVED',
  'full history of a two-part close');

select is(public.safra_close_my_part(pg_temp.t('t2'))->>'situation', 'AGUARDANDO_SOLICITANTE',
  'D-72: owner closes first -> waiting for the requester');
select throws_ok($$ select public.safra_cancel_treatment(pg_temp.t('t3'), 'curto') $$, '22023', 'SAFRA_CANCEL_REASON_REQUIRED',
  'D-66: cancel requires a reason');
select is(public.safra_cancel_treatment(pg_temp.t('t3'), 'Alarme falso: estoque reposto pelo PCP')->>'situation', 'CANCELADO',
  'D-66: the owner can cancel with a reason');
select throws_ok($$ select public.safra_cancel_treatment(pg_temp.t('t1'), 'Cancelar um já encerrado') $$, 'P0001', 'SAFRA_TREATMENT_NOT_ACTIVE',
  'a closed protocol cannot be cancelled');

-- 6. Requester still locked while only the owner closed ----------------------------
select pg_temp.act_as('0b');
select throws_ok($$ select public.safra_start_treatment(pg_temp.card('SAFRA-09'), 'c0810000-0000-4000-8000-000000000910'::uuid,
       'Tentando abrir com a minha parte aberta', '{}'::uuid[]) $$, 'P0001', 'SAFRA_START_ACTIVE_EXISTS',
  'D-72: owner closed first, requester stays locked until closing his part');
select is(public.safra_cancel_treatment(pg_temp.t('t2'), 'Resolvido por outra equipe antes')->>'situation', 'CANCELADO',
  'the requester can cancel while waiting');

-- 7. Database guards --------------------------------------------------------------
select throws_ok($$ update public.treatments set status = 'RESOLVED', closed_by = opened_by, closed_at = now() where id = pg_temp.t('t4') $$,
  '23514', null, 'RESOLVED without both parts is rejected by the database');
select throws_ok($$ update public.treatments set problem_started_at = opened_at - interval '1 day' where id = pg_temp.t('t4') $$,
  'P0001', 'treatment START snapshot fields are immutable', 'reported problem start cannot be rewritten');

update public.treatments set requester_closed_at = '2000-01-01' where id = pg_temp.t('t4');
select ok((select requester_closed_at > now() - interval '1 minute' from public.treatments where id = pg_temp.t('t4')),
  'part close time always comes from the server clock');

select ok(not has_table_privilege('authenticated', 'public.treatments', 'UPDATE'),
  'the browser cannot write protocol rows directly');

select ok(
  not has_function_privilege('anon','public.safra_close_my_part(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.safra_cancel_treatment(uuid,text)','EXECUTE')
  and not has_function_privilege('anon','public.safra_get_my_treatments()','EXECUTE')
  and not has_function_privilege('anon','public.safra_get_owner_treatments()','EXECUTE')
  and has_function_privilege('authenticated','public.safra_close_my_part(uuid)','EXECUTE'),
  'protocol commands are closed to anon and open to authenticated');

select ok(to_regprocedure('public.safra_start_treatment(uuid,uuid,text,uuid[])') is null,
  'old 4-argument START is gone (no ambiguous overload)');

select * from finish();
rollback;
