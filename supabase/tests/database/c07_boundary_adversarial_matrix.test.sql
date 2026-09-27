begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

-- 1) borda exata
select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:00:00+00',1,'HOUR',false)),
  'ON_TRACK',
  'open SLA exactly at deadline remains ON_TRACK'
);

select is(
  (select remaining_seconds from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:00:00+00',1,'HOUR',false)),
  0::numeric,
  'exact deadline has zero remaining seconds'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:00:00.001+00',1,'HOUR',false)),
  'BREACHED',
  'one millisecond after deadline is BREACHED'
);

-- 2) END na borda / apos breach
select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00','2026-09-27 13:00:00+00',null,
    '2026-09-27 13:00:00+00',1,'HOUR',false)),
  'COMPLETED_ON_TIME',
  'END exactly at deadline is completed on time'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00','2026-09-27 13:00:00.001+00',null,
    '2026-09-27 13:00:00.001+00',1,'HOUR',false)),
  'COMPLETED_LATE',
  'END after deadline is completed late'
);

select is(
  (select breached_at from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00','2026-09-27 13:30:00+00',null,
    '2026-09-27 13:30:00+00',1,'HOUR',false)),
  '2026-09-27 13:00:00+00'::timestamptz,
  'late END preserves breach instant at the deadline'
);

-- 3) timezone / DST
select ok(
  '2026-09-27 09:00:00-03'::timestamptz =
  '2026-09-27 12:00:00+00'::timestamptz,
  'offset representations resolve to same instant'
);

select is(
  extract(epoch from (
    '2018-11-04 03:30:00-02'::timestamptz -
    '2018-11-04 00:30:00-03'::timestamptz
  ))::numeric,
  7200::numeric,
  'DST transition uses absolute elapsed time'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2018-11-04 00:30:00-03',
    '2018-11-04 03:30:00-02',
    null,
    '2018-11-04 03:30:00-02',
    2,'HOUR',false)),
  'COMPLETED_ON_TIME',
  'DST crossing at exact absolute target completes on time'
);

-- 4) evento ausente
select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',null,null,null,
    '2026-09-27 12:30:00+00',1,'HOUR',false)),
  'NOT_MEASURABLE',
  'missing START is not measurable'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',null,null,null,
    '2026-09-27 12:30:00+00',1,'HOUR',false)),
  'START_EVENT_MISSING',
  'missing START has explicit reason'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 12:30:00+00',1,'HOUR',false)),
  'ON_TRACK',
  'missing RESOLVED before deadline means SLA is still running'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:30:00+00',1,'HOUR',false)),
  'BREACHED',
  'missing RESOLVED after deadline means breached'
);

-- 5) CANCEL
select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,'2026-09-27 12:30:00+00',
    '2026-09-27 12:30:00+00',1,'HOUR',false)),
  'NOT_MEASURABLE',
  'CANCEL before deadline is not success'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,'2026-09-27 13:00:00+00',
    '2026-09-27 13:00:00+00',1,'HOUR',false)),
  'NOT_MEASURABLE',
  'CANCEL exactly at deadline is not success'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,'2026-09-27 13:00:00.001+00',
    '2026-09-27 13:00:00.001+00',1,'HOUR',false)),
  'BREACHED',
  'CANCEL after deadline preserves breach'
);

-- 6) dois SLAs independentes
select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:30:00+00',1,'HOUR',false)),
  'BREACHED',
  'SLA 1h can breach'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:30:00+00',2,'HOUR',false)),
  'ON_TRACK',
  'SLA 2h can remain on track at same instant'
);

-- 7) manipulacao do relogio / snapshot historico
select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 11:59:59+00',1,'HOUR',false)),
  'NOT_MEASURABLE',
  'as_of before START is not measurable'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 11:59:59+00',1,'HOUR',false)),
  'CLOCK_BEFORE_START',
  'as_of before START has explicit clock reason'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    null,1,'HOUR',false)),
  'NOT_MEASURABLE',
  'missing as_of is not measurable'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    null,1,'HOUR',false)),
  'AS_OF_MISSING',
  'missing as_of has explicit reason'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',
    '2026-09-27 13:30:00+00',
    null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',false)),
  'ON_TRACK',
  'future END is invisible to an earlier historical snapshot'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',
    null,
    '2026-09-27 13:30:00+00',
    '2026-09-27 12:30:00+00',
    1,'HOUR',false)),
  'ON_TRACK',
  'future CANCEL is invisible to an earlier historical snapshot'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',
    '2026-09-27 14:00:00+00',
    null,
    '2026-09-27 13:30:00+00',
    1,'HOUR',false)),
  'BREACHED',
  'future END cannot erase a breach in an earlier snapshot'
);

select ok(
  not has_function_privilege(
    'anon',
    'private.safra_evaluate_sla(timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'private.safra_evaluate_sla(timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean)',
    'EXECUTE'
  ),
  'client roles cannot execute raw SLA evaluator to spoof as_of'
);

select * from finish();
rollback;
