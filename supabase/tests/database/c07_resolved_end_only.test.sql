begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

select ok(
  exists(
    select 1
    from pg_constraint
    where conrelid='public.scenario_slas'::regclass
      and conname='scenario_slas_end_event_resolved_only'
  ),
  'scenario_slas has resolved-only END constraint'
);

select like(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid='public.scenario_slas'::regclass
      and conname='scenario_slas_end_event_resolved_only'
  ),
  '%TREATMENT_RESOLVED%',
  'resolved-only constraint explicitly names TREATMENT_RESOLVED'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',
    '2026-09-27 12:30:00+00',
    null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',false
  )),
  'COMPLETED_ON_TIME',
  'TREATMENT_RESOLVED can complete SLA on time'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',
    '2026-09-27 13:30:00+00',
    null,
    '2026-09-27 13:30:00+00',
    1,'HOUR',false
  )),
  'COMPLETED_LATE',
  'TREATMENT_RESOLVED can complete SLA late'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'NOTE_ADDED',
    '2026-09-27 12:00:00+00',
    '2026-09-27 12:30:00+00',
    null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',false
  )),
  'NOT_MEASURABLE',
  'non-resolved END cannot complete SLA'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'NOTE_ADDED',
    '2026-09-27 12:00:00+00',
    '2026-09-27 12:30:00+00',
    null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',false
  )),
  'END_EVENT_NOT_TREATMENT_RESOLVED',
  'non-resolved END returns explicit governance reason'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_CANCELLED',
    '2026-09-27 12:00:00+00',
    '2026-09-27 12:30:00+00',
    null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',false
  )),
  'NOT_MEASURABLE',
  'TREATMENT_CANCELLED cannot be configured as a successful END'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    '  treatment_resolved  ',
    '2026-09-27 12:00:00+00',
    '2026-09-27 12:30:00+00',
    null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',false
  )),
  'COMPLETED_ON_TIME',
  'END event normalization accepts canonical value with case/space differences'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    null,
    '2026-09-27 12:00:00+00',
    '2026-09-27 12:30:00+00',
    null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',false
  )),
  'NOT_MEASURABLE',
  'missing END configuration cannot complete SLA'
);

select is(
  (
    select count(*)::bigint
    from public.scenario_slas
    where upper(btrim(end_event)) <> 'TREATMENT_RESOLVED'
  ),
  0::bigint,
  'no structured SLA violates the resolved-only END contract'
);

select is(
  (
    select count(*)::bigint
    from (
      select sla_state
      from private.safra_evaluate_configured_sla(
        'NOTE_ADDED',
        '2026-09-27 12:00:00+00',
        '2026-09-27 12:30:00+00',
        null,
        '2026-09-27 12:30:00+00',
        1,'HOUR',false
      )
      union all
      select sla_state
      from private.safra_evaluate_configured_sla(
        'TREATMENT_CANCELLED',
        '2026-09-27 12:00:00+00',
        '2026-09-27 13:30:00+00',
        null,
        '2026-09-27 13:30:00+00',
        1,'HOUR',false
      )
    ) x
    where sla_state in ('COMPLETED_ON_TIME','COMPLETED_LATE')
  ),
  0::bigint,
  'unsupported END events can never produce COMPLETED states'
);

select * from finish();
rollback;
