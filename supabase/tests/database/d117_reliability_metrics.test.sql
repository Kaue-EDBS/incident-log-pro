begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- R1, R2 = requesters; O = Renato (owner of SAFRA-09); G = Jair (governance); T = third party.
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('a0070000-0000-4000-8000-00000000000a','d117.r1@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp()),
  ('a0070000-0000-4000-8000-00000000000b','d117.r2@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp()),
  ('a0070000-0000-4000-8000-00000000000c','d117.third@editoradobrasil.com.br','{"provider":"azure"}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values
  ('a0070000-0000-4000-8000-00000000000d', 'Renato de Paulo'),
  ('a0070000-0000-4000-8000-00000000000e', 'Jair Silva')
) as v(id, who)
join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0070000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0070000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0070000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0070000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0070000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

create temp table ctx(k text primary key, v text);
create function pg_temp.t(p_k text) returns uuid language sql as $$ select v::uuid from ctx where k = p_k $$;
create function pg_temp.open(p_k text, p_card text, p_key text) returns void language sql as $$
  insert into ctx
  select p_k, r->>'treatment_id'
  from (select public.safra_start_treatment((select id from public.scenarios where code = p_card), p_key::uuid,
          'D-117: protocolo de teste dos indicadores', '{}'::uuid[]) r) x;
$$;
create function pg_temp.close_both(p_k text, p_requester text) returns void language plpgsql as $$
begin
  perform pg_temp.act_as(p_requester);
  perform public.safra_close_my_part(pg_temp.t(p_k));
  perform pg_temp.act_as('0d');
  perform public.safra_close_my_part(pg_temp.t(p_k));
end;
$$;
-- Exact times, in minutes after a base 20 h ago (inside the current Safra).
create function pg_temp.at(p_minutes integer) returns timestamptz language sql as $$
  select date_trunc('minute', now()) - interval '20 hours' + make_interval(mins => p_minutes)
$$;
create function pg_temp.times(p_k text, p_problem integer, p_open integer, p_req integer, p_owner integer) returns void language plpgsql as $$
begin
  execute 'alter table public.treatments disable trigger user';
  update public.treatments
     set problem_started_at = pg_temp.at(p_problem), opened_at = pg_temp.at(p_open), created_at = pg_temp.at(p_open),
         requester_closed_at = case when p_req is null then null else pg_temp.at(p_req) end,
         owner_closed_at = case when p_owner is null then null else pg_temp.at(p_owner) end,
         closed_at = case when status = 'RESOLVED' and not auto_resolved then pg_temp.at(greatest(p_req, p_owner)) else closed_at end
   where id = pg_temp.t(p_k);
  execute 'alter table public.treatments enable trigger user';
end;
$$;
create function pg_temp.card(p_json jsonb, p_code text) returns jsonb language sql as $$
  select c from jsonb_array_elements(p_json->'cards') c where c->>'code' = p_code
$$;

-- Card 09: p1 and p2 overlap (one failure), p3 later, p4 cancelled, p5 excluded.
select pg_temp.act_as('0a');
select pg_temp.open('p1', 'SAFRA-09', 'a0070000-0000-4000-8000-000000000901');
select pg_temp.act_as('0b');
select pg_temp.open('p2', 'SAFRA-09', 'a0070000-0000-4000-8000-000000000902');
select pg_temp.close_both('p1', '0a');
select pg_temp.close_both('p2', '0b');
select pg_temp.act_as('0a');
select pg_temp.open('p3', 'SAFRA-09', 'a0070000-0000-4000-8000-000000000903');
select pg_temp.close_both('p3', '0a');
select pg_temp.act_as('0a');
select pg_temp.open('p4', 'SAFRA-09', 'a0070000-0000-4000-8000-000000000904');
select public.safra_cancel_treatment(pg_temp.t('p4'), 'D-117: cancelado não conta');
select pg_temp.open('p5', 'SAFRA-09', 'a0070000-0000-4000-8000-000000000905');
select pg_temp.close_both('p5', '0a');
insert into public.treatment_analytics_exclusions(treatment_id, reason) values (pg_temp.t('p5'), 'D-117: demonstração fora do analytics');

-- Card 07: p6 resolved automatically with only the requester part (D-113).
select pg_temp.act_as('0a');
select pg_temp.open('p6', 'SAFRA-07', 'a0070000-0000-4000-8000-000000000906');
select public.safra_close_my_part(pg_temp.t('p6'));
select pg_temp.times('p6', -3200, -3200, -3160, null);   -- 73 h ago: the sweep closes it
select private.safra_auto_cancel_stale();
select pg_temp.times('p6', 60, 60, 100, null);           -- back inside the Safra: 40 min to resolve

-- Exact times (minutes after the base).
select pg_temp.times('p1', 0, 30, 60, 90);
select pg_temp.times('p2', 50, 60, 100, 120);   -- overlaps p1 -> same failure, ends at 120
select pg_temp.times('p3', 225, 240, 260, 270);
select pg_temp.times('p5', 355, 360, 380, 390);  -- excluded (D-115)

-- 1. Governance sees every card and the consolidated row ----------------------------
select pg_temp.act_as('0e');
create temp table m as select public.safra_get_reliability_metrics() as j;

select is((select j->>'scope' from m), 'ALL', 'D-88: governance sees all cards');
select is((select jsonb_array_length(j->'cards') from m), (select count(*)::int from public.scenarios), 'every card is listed, even without failures');
select is((select (pg_temp.card(j, 'SAFRA-09')->>'failures')::int from m), 2,
  'D-117: overlapping protocols of the same card count as one failure; cancelled and excluded do not count');
select is((select (pg_temp.card(j, 'SAFRA-09')->>'protocols')::int from m), 3, 'the 2 failures come from 3 resolved protocols');
select is((select (pg_temp.card(j, 'SAFRA-09')->'mttd'->>'mean')::numeric from m), 1350::numeric,
  'MTTD: opening minus the earliest problem start of each failure (30 and 15 min)');
select is((select (pg_temp.card(j, 'SAFRA-09')->'mttr'->>'mean')::numeric from m), 3600::numeric,
  'MTTR: from the first opening to the last part closed (90 and 30 min)');
select is((select (pg_temp.card(j, 'SAFRA-09')->'mttf'->>'mean')::numeric from m), 7200::numeric,
  'MTTF: from the end of a failure to the start of the next (2 h)');
select is((select (pg_temp.card(j, 'SAFRA-09')->'mtbf'->>'mean')::numeric from m), 12600::numeric,
  'MTBF: from the start of a failure to the start of the next (3 h 30)');
select is((select (pg_temp.card(j, 'SAFRA-09')->'mttr'->>'median')::numeric from m), 3600::numeric,
  'the median is also given (90 and 30 min -> 60 min)');
select is((select (pg_temp.card(j, 'SAFRA-07')->'mttr'->>'mean')::numeric from m), 2400::numeric,
  'D-113: an automatic resolution counts until the part that was closed (40 min)');
select ok((select pg_temp.card(j, 'SAFRA-07')->'mtbf'->>'mean' is null from m),
  'with a single failure there is no MTBF (never an invented zero)');
select is((select (j->'consolidated'->>'failures')::int from m), 3, 'consolidated: 3 failures');
select is((select (j->'consolidated'->'mttr'->>'mean')::numeric from m), 3200::numeric,
  'consolidated MTTR mean over every failure');
select ok((select (j->>'excluded')::int >= 1 from m), 'the number of excluded protocols is shown');

-- 2. Owner sees only own cards; others are refused ----------------------------------
select pg_temp.act_as('0d');
select ok((select j->>'scope' = 'OWNER'
                  and pg_temp.card(j, 'SAFRA-09') is not null
                  and jsonb_array_length(j->'cards') < (select count(*)::int from public.scenarios)
           from (select public.safra_get_reliability_metrics() as j) x),
  'D-88: the card owner sees only own cards');
select pg_temp.act_as('0c');
select throws_ok($$ select public.safra_get_reliability_metrics() $$,
  '42501', 'SAFRA_ANALYTICS_FORBIDDEN', 'a person who owns no card does not see analytics');
select ok(not has_function_privilege('anon', 'public.safra_get_reliability_metrics(uuid)', 'EXECUTE'),
  'anon cannot read analytics');

select * from finish();
rollback;
