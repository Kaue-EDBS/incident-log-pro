begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

select is(
  current_setting('TimeZone'),
  'UTC',
  'database canonical timezone remains UTC'
);

select ok(
  '2026-09-27 09:00:00-03'::timestamptz = '2026-09-27 12:00:00+00'::timestamptz,
  'same absolute instant is preserved across offsets'
);

select is(
  extract(epoch from (
    '2026-09-27 10:30:00-03'::timestamptz -
    '2026-09-27 09:00:00-03'::timestamptz
  ))::numeric,
  extract(epoch from (
    '2026-09-27 13:30:00+00'::timestamptz -
    '2026-09-27 12:00:00+00'::timestamptz
  ))::numeric,
  'duration is invariant across timezone representation'
);

select is(
  ('2026-09-27 22:30:00-03'::timestamptz at time zone 'America/Sao_Paulo')::date,
  date '2026-09-27',
  '22:30 Sao Paulo remains in the correct local analytics day'
);

select is(
  ('2026-09-27 22:30:00-03'::timestamptz at time zone 'UTC')::date,
  date '2026-09-28',
  'negative control proves raw UTC day would misbucket 22:30 Sao Paulo'
);

select is(
  ('2026-09-27 23:30:00-03'::timestamptz at time zone 'America/Sao_Paulo')::date,
  date '2026-09-27',
  '23:30 Sao Paulo remains in the correct local analytics day'
);

select is(
  ('2026-09-28 00:30:00-03'::timestamptz at time zone 'America/Sao_Paulo')::date,
  date '2026-09-28',
  '00:30 Sao Paulo moves to the next local analytics day'
);

select is(
  date_trunc('hour', '2026-09-27 22:30:00-03'::timestamptz at time zone 'America/Sao_Paulo'),
  timestamp '2026-09-27 22:00:00',
  'analytics hourly bucket uses Sao Paulo local hour'
);

with samples(ts) as (
  values
    ('2026-09-27 21:30:00-03'::timestamptz),
    ('2026-09-27 22:30:00-03'::timestamptz),
    ('2026-09-27 23:30:00-03'::timestamptz),
    ('2026-09-28 00:30:00-03'::timestamptz)
)
select is(
  (
    select count(*)::bigint
    from samples
    where (ts at time zone 'America/Sao_Paulo')::date = date '2026-09-27'
  ),
  3::bigint,
  'local daily analytics bucket returns three events for Sep 27'
);

with samples(ts) as (
  values
    ('2026-09-27 21:30:00-03'::timestamptz),
    ('2026-09-27 22:30:00-03'::timestamptz),
    ('2026-09-27 23:30:00-03'::timestamptz),
    ('2026-09-28 00:30:00-03'::timestamptz)
)
select is(
  (
    select count(*)::bigint
    from samples
    where (ts at time zone 'America/Sao_Paulo')::date = date '2026-09-28'
  ),
  1::bigint,
  'local daily analytics bucket returns one event for Sep 28'
);

select is(
  extract(epoch from (
    '2018-11-04 03:30:00-02'::timestamptz -
    '2018-11-04 00:30:00-03'::timestamptz
  ))::numeric,
  7200::numeric,
  'historical DST offset change preserves absolute elapsed time'
);

select is(
  (
    select count(*)::bigint
    from information_schema.columns
    where table_schema='public'
      and table_name in (
        'treatments',
        'treatment_events',
        'treatment_escalations',
        'notifications_log',
        'governance_issues'
      )
      and (
        column_name like '%_at'
        or column_name in ('created_at','updated_at')
      )
      and data_type <> 'timestamp with time zone'
  ),
  0::bigint,
  'all operational analytics timestamps remain timestamptz'
);

select * from finish();
rollback;
