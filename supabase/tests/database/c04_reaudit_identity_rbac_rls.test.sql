begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users(
  id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at
)
values(
  '04040404-0000-4000-8000-000000000001'::uuid,
  'c04.expired.test@editoradobrasil.com.br',
  '{"provider":"azure"}'::jsonb,
  true,
  false,
  clock_timestamp(),
  clock_timestamp()
);

insert into auth.sessions(id,user_id,created_at,updated_at)
values(
  '04040404-0000-4000-8000-000000000002'::uuid,
  '04040404-0000-4000-8000-000000000001'::uuid,
  clock_timestamp(),
  clock_timestamp()
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub','04040404-0000-4000-8000-000000000001',
    'email','c04.expired.test@editoradobrasil.com.br',
    'session_id','04040404-0000-4000-8000-000000000002',
    'is_anonymous',false,
    'app_metadata',json_build_object('provider','azure'),
    'exp',extract(epoch from clock_timestamp()-interval '5 minutes')::bigint
  )::text,
  true
);

select ok(
  not public.safra_is_corporate_user(),
  'expired JWT fails canonical corporate predicate even with a live session row'
);

select throws_ok(
  $$
    select public.safra_start_treatment(
      (select id from public.scenarios where code='SAFRA-01'),
      '04040404-0000-4000-8000-000000000010'::uuid,
      'C04-AUD expired JWT zero-effect regression',
      '{}'::uuid[]
    );
  $$,
  '42501',
  'SAFRA_START_FORBIDDEN',
  'expired JWT cannot execute START'
);

select is(
  (
    select count(*)::bigint
    from public.treatments
    where start_idempotency_key='04040404-0000-4000-8000-000000000010'
  ),
  0::bigint,
  'expired JWT START persists zero treatments'
);

select is(
  (
    select count(*)::bigint
    from public.treatment_events e
    join public.treatments t on t.id=e.treatment_id
    where t.start_idempotency_key='04040404-0000-4000-8000-000000000010'
  ),
  0::bigint,
  'expired JWT START persists zero treatment events'
);

select is(
  (
    select count(*)::bigint
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in ('safra_end_treatment','safra_cancel_treatment')
  ),
  0::bigint,
  'END/CANCEL RPCs remain absent until their governed implementation phases'
);

select ok(
  not has_table_privilege('authenticated','public.applications','SELECT'),
  'authenticated cannot read retired applications table'
);

select ok(
  not has_table_privilege('authenticated','public.incidents','SELECT'),
  'authenticated cannot read retired incidents table'
);

select ok(
  not has_table_privilege('authenticated','public.incidents','INSERT')
  and not has_table_privilege('authenticated','public.incidents','UPDATE')
  and not has_table_privilege('authenticated','public.incidents','DELETE'),
  'authenticated has no write path to retired incidents table'
);

select is(
  (
    select count(*)::bigint
    from pg_policies
    where schemaname='public'
      and tablename in ('applications','incidents')
  ),
  0::bigint,
  'retired Reliability tables expose no browser RLS policies'
);

select ok(
  has_table_privilege('service_role','public.applications','SELECT')
  and has_table_privilege('service_role','public.incidents','SELECT'),
  'trusted service_role read access remains preserved for historical persistence'
);

select ok(
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='applications')
  and
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='incidents'),
  'RLS remains enabled on both historical tables'
);

select * from finish();
rollback;
