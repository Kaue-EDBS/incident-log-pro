begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00',null,null,'2026-09-25 12:59:59+00',1,'HOUR',false)),
  'ON_TRACK','active SLA before deadline is ON_TRACK'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00',null,null,'2026-09-25 13:00:00+00',1,'HOUR',false)),
  'ON_TRACK','exact deadline remains ON_TRACK; breach begins after deadline'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00',null,null,'2026-09-25 13:00:00.001+00',1,'HOUR',false)),
  'BREACHED','time after deadline is BREACHED'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00','2026-09-25 13:00:00+00',null,'2026-09-25 13:00:00+00',1,'HOUR',false)),
  'COMPLETED_ON_TIME','END exactly at deadline is on time'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00','2026-09-25 13:00:00.001+00',null,'2026-09-25 13:00:00.001+00',1,'HOUR',false)),
  'COMPLETED_LATE','END after deadline is late'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    null,null,null,'2026-09-25 12:30:00+00',1,'HOUR',false)),
  'NOT_MEASURABLE','missing start event is not measurable'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00',null,null,'2026-09-25 12:30:00+00',null,null,false)),
  'NOT_MEASURABLE','missing structured target is not measurable'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00',null,'2026-09-25 12:30:00+00','2026-09-25 12:30:00+00',1,'HOUR',false)),
  'NOT_MEASURABLE','CANCEL before deadline is not SLA success'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00',null,'2026-09-25 13:30:00+00','2026-09-25 13:30:00+00',1,'HOUR',false)),
  'BREACHED','CANCEL after breach preserves breach'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00',null,null,'2026-09-25 11:59:59+00',1,'HOUR',false)),
  'NOT_MEASURABLE','clock before start is rejected'
);

select is(
  (select deadline_at from private.safra_evaluate_sla(
    '2026-09-25 09:00:00-03',null,null,'2026-09-25 09:30:00-03',1,'HOUR',false)),
  '2026-09-25 13:00:00+00'::timestamptz,
  'timezone conversion preserves absolute deadline'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-11-01 00:30:00-04',null,null,'2026-11-01 01:00:00-05',2,'HOUR',false)),
  'ON_TRACK','DST boundary uses timestamptz elapsed time'
);

select is(
  (select sla_state from private.safra_evaluate_sla(
    '2026-09-25 12:00:00+00',null,null,'2026-09-25 12:30:00+00',1,'HOUR',true)),
  'NOT_APPLICABLE','NOT_APPLICABLE requires explicit rule input'
);

select is(
  (select count(*)::bigint from public.scenario_slas),
  0::bigint,
  'C07 engine does not infer/publish structured SLA rows'
);

select * from finish();
rollback;
