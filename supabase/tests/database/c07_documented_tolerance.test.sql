begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

select is(
  (select count(*)::bigint
   from information_schema.columns
   where table_schema='public'
     and table_name='scenario_slas'
     and column_name in ('tolerance_value','tolerance_unit','tolerance_documentation')),
  3::bigint,
  'C07.6 tolerance contract has three explicit fields'
);

select ok(
  exists(
    select 1 from pg_constraint
    where conrelid='public.scenario_slas'::regclass
      and conname='scenario_slas_tolerance_complete'
  ),
  'C07.6 schema has complete documented-tolerance constraint'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:00:00+00',
    1,'HOUR',
    null,null,null,
    false
  )),
  'ON_TRACK',
  'no tolerance preserves exact deadline semantics'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:00:00.001+00',
    1,'HOUR',
    null,null,null,
    false
  )),
  'BREACHED',
  'no tolerance still breaches one millisecond after base deadline'
);

select is(
  (select deadline_at from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:03:00+00',
    1,'HOUR',
    5,'MINUTE','Aprovado em regra operacional C07.6',
    false
  )),
  '2026-09-27 13:05:00+00'::timestamptz,
  'documented 5 minute tolerance extends effective deadline only'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:00:00.001+00',
    1,'HOUR',
    5,'MINUTE','Aprovado em regra operacional C07.6',
    false
  )),
  'ON_TRACK',
  'documented tolerance prevents breach immediately after base deadline'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:05:00+00',
    1,'HOUR',
    5,'MINUTE','Aprovado em regra operacional C07.6',
    false
  )),
  'ON_TRACK',
  'exact effective deadline remains on track'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:05:00.001+00',
    1,'HOUR',
    5,'MINUTE','Aprovado em regra operacional C07.6',
    false
  )),
  'BREACHED',
  'one millisecond after effective deadline breaches'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00','2026-09-27 13:04:00+00',null,
    '2026-09-27 13:04:00+00',
    1,'HOUR',
    5,'MINUTE','Aprovado em regra operacional C07.6',
    false
  )),
  'COMPLETED_ON_TIME',
  'END inside documented tolerance is completed on time'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00','2026-09-27 13:06:00+00',null,
    '2026-09-27 13:06:00+00',
    1,'HOUR',
    5,'MINUTE','Aprovado em regra operacional C07.6',
    false
  )),
  'COMPLETED_LATE',
  'END after documented tolerance is completed late'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',
    5,'MINUTE',null,
    false
  )),
  'TOLERANCE_CONFIGURATION_INVALID',
  'tolerance without documentation is rejected explicitly'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',
    null,'MINUTE','Documento sem valor',
    false
  )),
  'TOLERANCE_CONFIGURATION_INVALID',
  'partial tolerance configuration is rejected explicitly'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',
    0,'MINUTE','Tolerancia zero nao deve ser persistida',
    false
  )),
  'TOLERANCE_CONFIGURATION_INVALID',
  'zero tolerance must be represented as NULL, not documented override'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 12:30:00+00',
    1,'HOUR',
    5,'SECOND','Unidade persistida nao suportada',
    false
  )),
  'TOLERANCE_CONFIGURATION_INVALID',
  'persisted tolerance unit SECOND is rejected'
);

select ok(
  position('sl.tolerance_value' in pg_get_functiondef(
    'private.safra_treatment_sla_state(uuid,timestamptz)'::regprocedure
  )) > 0
  and position('sl.tolerance_unit' in pg_get_functiondef(
    'private.safra_treatment_sla_state(uuid,timestamptz)'::regprocedure
  )) > 0
  and position('sl.tolerance_documentation' in pg_get_functiondef(
    'private.safra_treatment_sla_state(uuid,timestamptz)'::regprocedure
  )) > 0,
  'treatment SLA state passes persisted tolerance definition into evaluator'
);

select ok(
  not has_function_privilege(
    'anon',
    'private.safra_evaluate_configured_sla(text,timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,numeric,text,text,boolean)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'private.safra_evaluate_configured_sla(text,timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,numeric,text,text,boolean)',
    'EXECUTE'
  ),
  'browser roles cannot bypass persisted documented tolerance through raw evaluator'
);

select is(
  (
    select count(*)::bigint
    from public.scenario_slas
    where
      (tolerance_value is not null or tolerance_unit is not null or tolerance_documentation is not null)
      and not (
        tolerance_value > 0
        and upper(btrim(tolerance_unit)) = any(array['MINUTE'::text,'HOUR'::text,'DAY'::text])
        and btrim(tolerance_documentation) <> ''
      )
  ),
  0::bigint,
  'no persisted SLA has malformed tolerance configuration'
);

select is(
  (select count(*)::bigint from public.scenario_slas),
  0::bigint,
  'C07.6 migration does not infer or publish SLA rows'
);

select * from finish();
rollback;
