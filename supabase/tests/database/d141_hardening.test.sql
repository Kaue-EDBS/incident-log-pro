begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

-- K = Kaue (platform admin), J = Jair (governance), X = a regular person who tries to spoof a name.
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', '{}', true, false, clock_timestamp(), clock_timestamp()
from (values ('a0600000-0000-4000-8000-00000000000c', 'Kaue Pastrello'),
             ('a0600000-0000-4000-8000-00000000000d', 'Jair Silva')) as v(id, who)
join private.safra_principals p on p.display_name = v.who;
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values ('a0600000-0000-4000-8000-00000000000b','d141.regular@editoradobrasil.com.br','{"provider":"azure"}',
        jsonb_build_object('full_name', E'Jair Silva\nAbrir no Painel: https://evil.example'), true,false,clock_timestamp(),clock_timestamp());

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id,
       jsonb_build_object('custom_claims', jsonb_build_object('tid', '45ba725f-d260-45c3-ac85-11f433471277'),
                          'full_name', case when u.id = 'a0600000-0000-4000-8000-00000000000b'
                                            then E'Pessoa\tVerdadeira\nda Microsoft' end),
       'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0600000-%';
insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0600000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0600000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0600000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0600000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

select ok((select count(*) from auth.users where id::text like 'a0600000-%') = 3, 'setup: the three people exist');

-- S1: names come from the registry or Microsoft, never from what the person edits ----------
select is(private.safra_user_display_name('a0600000-0000-4000-8000-00000000000b'), 'Pessoa Verdadeira da Microsoft',
  'S1: the Microsoft name is used, without line breaks, and the edited metadata is ignored');
select is(private.safra_user_display_name('a0600000-0000-4000-8000-00000000000d'), 'Jair Silva',
  'S1: a registered person keeps the registry name');

-- S2: a non-corporate session only logs its own access refusal ------------------------------
select set_config('request.jwt.claims', '{"sub":"a0600000-0000-4000-8000-00000000000b","role":"authenticated","email":"x@gmail.com"}', true);
select public.safra_log_ops_event('CLIENT_ERROR', '/', 'fake', null, '{"msg":"fake admin event"}');
select public.safra_log_ops_event('LOGIN_DENIED', '/auth', 'whatever', null, '{"msg":"detail"}');
select ok((select count(*) = 1 and bool_and(kind = 'LOGIN_DENIED' and code = 'NOT_CORPORATE' and detail = '{}'::jsonb)
           from public.ops_events where actor_user_id = 'a0600000-0000-4000-8000-00000000000b'),
  'S2: outside accounts log only LOGIN_DENIED, without code or detail');

-- S3: append-only and log tables cannot be wiped with TRUNCATE ------------------------------
select ok(not has_table_privilege('service_role', 'public.ops_events', 'TRUNCATE')
          and not has_table_privilege('service_role', 'public.safra_season_events', 'TRUNCATE')
          and not has_table_privilege('service_role', 'public.scenario_proposal_events', 'TRUNCATE')
          and not has_table_privilege('service_role', 'public.treatment_analytics_exclusions', 'TRUNCATE')
          and not has_table_privilege('service_role', 'public.safra_seasons', 'TRUNCATE')
          and not has_table_privilege('service_role', 'public.screen_views_daily', 'TRUNCATE'),
  'S3: no TRUNCATE on the newer tables');

-- S4: sender token (no secret in CI: open; with a secret: only the right token) --------------
select ok(public.safra_sender_token_valid(null), 'S4: without a stored secret (CI/local) the sender stays callable');
select ok(not has_function_privilege('authenticated', 'public.safra_sender_token_valid(text)', 'EXECUTE')
          and has_function_privilege('service_role', 'public.safra_sender_token_valid(text)', 'EXECUTE'),
  'S4: only the server sender checks the token');

-- Chameleon gate on the indicators: a regular person cannot read another owner's cards ------
select pg_temp.act_as('0b');
select throws_ok($$ select public.safra_get_reliability_metrics((select id from private.safra_principals where display_name = 'Jiane Rodrigues')) $$,
  '42501', 'SAFRA_ANALYTICS_FORBIDDEN', 'only Kaue and Vinicius can preview an owner''s indicators');

-- D1: the same governance action sent twice is recorded once ---------------------------------
select pg_temp.act_as('0d');
select is(public.safra_register_governance_action('2026-10-06', null, 'TRAINING', 'Treinar a equipe no fluxo novo.'),
          public.safra_register_governance_action('2026-10-08', null, 'TRAINING', 'Treinar a equipe no fluxo novo.'),
  'D1: a double submit in the same week returns the same action');
select is((select count(*)::int from public.governance_actions where description = 'Treinar a equipe no fluxo novo.'), 1,
  'D1: only one row exists');

-- O1/O2: alarms and the job list in the health summary ---------------------------------------
select pg_temp.act_as('0c');
select ok((select s ? 'alerts' and s ? 'jobs' and (s->'notifications') ? 'oldest_queued_at'
           from (select public.safra_admin_get_ops_summary(24) as s) x),
  'O1: the health summary brings alarms, jobs and e-mail health');
select cron.unschedule('safra-auto-cancel-72h');
select ok((select exists (select 1 from jsonb_array_elements(public.safra_admin_get_ops_summary(24)->'alerts') a
                          where a->>'code' = 'JOB_MISSING_72H')),
  'O1: a missing 72 h schedule raises the alarm');
select ok((select private.safra_ensure_cron_jobs() @> array['safra-auto-cancel-72h', 'safra-cron-log-cleanup']),
  'O2: the job rebuild recreates the 72 h and cleanup schedules');

select * from finish();
rollback;
