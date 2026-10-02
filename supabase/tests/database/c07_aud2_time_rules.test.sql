begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- Reference opening: 01/10/2026 08:00 São Paulo = 11:00 UTC.

-- 1. Escada de avisos (D-76) — substituída pela D-112 (M05); função removida -------------------------------------------------

-- 2. Tempos de encerramento (D-77) ------------------------------------------
select is(
  (select row(measurement_status, requester_time, owner_time, consolidated_time)::text
   from private.safra_close_times('2026-10-01 08:00-03', '2026-10-01 09:30-03', '2026-10-01 11:00-03', null)),
  row('CLOSED', interval '1 hour 30 minutes', interval '3 hours', interval '3 hours')::text,
  'both parts closed: consolidated time runs until the last part'
);

select is(
  (select consolidated_time from private.safra_close_times(
     '2026-10-01 08:00-03', '2026-10-01 12:00-03', '2026-10-01 10:00-03', null)),
  interval '4 hours',
  'owner first, requester last: consolidated uses the requester time'
);

select is(
  (select row(measurement_status, requester_time, owner_time, consolidated_time)::text
   from private.safra_close_times('2026-10-01 08:00-03', '2026-10-01 09:00-03', null, null)),
  row('IN_PROGRESS', interval '1 hour', null::interval, null::interval)::text,
  'one part open: that part and the consolidated time stay empty, never zero'
);

select is(
  (select row(measurement_status, requester_time, owner_time, consolidated_time)::text
   from private.safra_close_times('2026-10-01 08:00-03', '2026-10-01 09:00-03', null, '2026-10-01 10:00-03')),
  row('CANCELLED', null::interval, null::interval, null::interval)::text,
  'cancelled protocol is not counted as resolved (D-72)'
);

select is(
  (select consolidated_time from private.safra_close_times(
     '2026-10-01 08:00-03', '2026-10-01 08:00-03', '2026-10-01 08:00-03', null)),
  interval '0',
  'closing at the opening instant gives zero, not negative'
);

select throws_ok(
  $$ select * from private.safra_close_times('2026-10-01 08:00-03', null, '2026-10-01 07:59-03', null) $$,
  '22023', 'SAFRA_TIME_NEGATIVE',
  'negative close time is rejected'
);

select is(
  (select consolidated_time from private.safra_close_times(
     '2018-11-03 23:00-03', '2018-11-04 03:00-02', '2018-11-04 01:30-02', null)),
  interval '3 hours',
  'DST start: durations are absolute elapsed time'
);

select ok(
  (select requester_seconds = 177300 and owner_seconds = 93600 and consolidated_seconds = 177300
   from private.safra_close_times('2026-10-01 08:00-03', '2026-10-03 09:15-03', '2026-10-02 10:00-03', null)),
  'multi-day times are also returned as total seconds (safe for analytics)'
);

select is(
  (select consolidated_seconds from private.safra_close_times(
     '2018-11-03 23:00-03', '2018-11-04 03:00-02', '2018-11-04 01:30-02', null)),
  10800::numeric,
  'DST start: 3 elapsed hours are 10800 seconds'
);

select ok(
  (select requester_seconds is null and owner_seconds = 3600 and consolidated_seconds is null
   from private.safra_close_times('2026-10-01 08:00-03', null, '2026-10-01 09:00-03', null)),
  'open part keeps empty seconds, never zero'
);

-- 3. Fuso do analytics -------------------------------------------------------
select is(
  private.safra_local_day('2026-10-01 23:30-03'),
  date '2026-10-01',
  '23:30 São Paulo stays on the local day (UTC would already be the next day)'
);

select is(
  private.safra_local_day('2026-10-02 00:30-03'),
  date '2026-10-02',
  '00:30 São Paulo moves to the next local day'
);

-- 4. Superfície e ausência de duração gravada --------------------------------
select is(
  (select count(*)::bigint from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private'
     and p.proname in ('safra_close_times', 'safra_local_day')
     and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))),
  0::bigint,
  'time rules are not client-callable'
);

select is(
  (select count(*)::bigint from information_schema.columns
   where table_schema = 'public'
     -- ops_events.duration_ms is a measured response time (D-95), not a protocol duration.
     and table_name <> 'ops_events'
     and (column_name ~* '(duration|elapsed|minutes|seconds)' or data_type = 'interval')),
  0::bigint,
  'no table stores a calculated duration (times are always derived)'
);

select is(
  (select count(*)::bigint from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'private') and p.proname ilike '%sla%'),
  0::bigint,
  'SLA engine retired (D-75)'
);

select ok(
  (select prosrc like '%D-76%' from pg_proc where proname = 'safra_c01_aud2_resolve_governance_issues'),
  'GI-SAFRA-009 resolution text cites the D-76 ladder'
);

select ok(to_regprocedure('private.safra_reminder_steps(timestamptz, timestamptz, timestamptz, timestamptz, timestamptz)') is null,
  'D-112: the old 2h/4h/hourly reminder ladder is gone');

select * from finish();
rollback;
