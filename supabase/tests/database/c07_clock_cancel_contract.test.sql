begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select is(
  (select remaining_seconds from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00',null,null,'2026-09-27 13:30:00+00',1,'HOUR',false)),
  0::numeric,
  'breached running SLA clamps remaining clock at zero'
);

select is(
  (select remaining_seconds from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00','2026-09-27 13:30:00+00',null,'2026-09-27 13:30:00+00',1,'HOUR',false)),
  0::numeric,
  'late completion clamps remaining clock at zero'
);

select is(
  (select remaining_seconds from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00',null,'2026-09-27 13:30:00+00','2026-09-27 13:30:00+00',1,'HOUR',false)),
  0::numeric,
  'cancel after breach clamps remaining clock at zero'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00',null,'2026-09-27 12:30:00+00','2026-09-27 12:30:00+00',1,'HOUR',false)),
  'NOT_MEASURABLE',
  'cancel before deadline is not SLA success'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00',null,'2026-09-27 13:00:00+00','2026-09-27 13:00:00+00',1,'HOUR',false)),
  'NOT_MEASURABLE',
  'cancel exactly at deadline is not SLA success'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00',null,'2026-09-27 13:00:00.001+00','2026-09-27 13:00:00.001+00',1,'HOUR',false)),
  'BREACHED',
  'cancel after deadline preserves breach'
);

select is(
  (select evaluation_reason from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00',null,'2026-09-27 11:59:59+00','2026-09-27 12:00:00+00',1,'HOUR',false)),
  'CANCEL_BEFORE_START',
  'cancel before start is rejected'
);

select is(
  (select evaluation_reason from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00','2026-09-27 11:59:59+00',null,'2026-09-27 12:00:00+00',1,'HOUR',false)),
  'END_BEFORE_START',
  'end before start is rejected'
);

select is(
  (select evaluation_reason from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00',null,null,'2026-09-27 11:59:59+00',1,'HOUR',false)),
  'CLOCK_BEFORE_START',
  'server clock before start is rejected'
);

select ok(
  not exists (
    select 1
    from (
      select * from private.safra_evaluate_sla(
        '2026-09-27 12:00:00+00',null,null,'2026-09-27 12:30:00+00',1,'HOUR',false)
      union all
      select * from private.safra_evaluate_sla(
        '2026-09-27 12:00:00+00',null,null,'2026-09-27 13:30:00+00',1,'HOUR',false)
      union all
      select * from private.safra_evaluate_sla(
        '2026-09-27 12:00:00+00','2026-09-27 12:45:00+00',null,'2026-09-27 12:45:00+00',1,'HOUR',false)
      union all
      select * from private.safra_evaluate_sla(
        '2026-09-27 12:00:00+00','2026-09-27 13:30:00+00',null,'2026-09-27 13:30:00+00',1,'HOUR',false)
      union all
      select * from private.safra_evaluate_sla(
        '2026-09-27 12:00:00+00',null,'2026-09-27 12:30:00+00','2026-09-27 12:30:00+00',1,'HOUR',false)
      union all
      select * from private.safra_evaluate_sla(
        '2026-09-27 12:00:00+00',null,'2026-09-27 13:30:00+00','2026-09-27 13:30:00+00',1,'HOUR',false)
    ) x
    where coalesce(elapsed_seconds,0) < 0
       or coalesce(remaining_seconds,0) < 0
  ),
  'valid SLA evaluation matrix never exposes negative elapsed/remaining clock'
);

select is(
  (select count(*)::bigint
   from (
     select sla_state from private.safra_evaluate_sla(
       '2026-09-27 12:00:00+00',null,'2026-09-27 12:30:00+00','2026-09-27 12:30:00+00',1,'HOUR',false)
     union all
     select sla_state from private.safra_evaluate_sla(
       '2026-09-27 12:00:00+00',null,'2026-09-27 13:00:00+00','2026-09-27 13:00:00+00',1,'HOUR',false)
     union all
     select sla_state from private.safra_evaluate_sla(
       '2026-09-27 12:00:00+00',null,'2026-09-27 13:30:00+00','2026-09-27 13:30:00+00',1,'HOUR',false)
   ) c
   where sla_state in ('COMPLETED_ON_TIME','COMPLETED_LATE')),
  0::bigint,
  'CANCEL paths can never produce COMPLETED states'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00','2026-09-27 12:30:00+00',null,'2026-09-27 12:30:00+00',1,'HOUR',false)),
  'COMPLETED_ON_TIME',
  'only the real END event can complete on time'
);

select is(
  (select evaluation_reason from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00','2026-09-27 12:30:00+00','2026-09-27 12:20:00+00','2026-09-27 12:30:00+00',1,'HOUR',false)),
  'CONFLICTING_TERMINAL_EVENTS',
  'END and CANCEL together are rejected as conflicting terminal events'
);

select * from finish();
rollback;
