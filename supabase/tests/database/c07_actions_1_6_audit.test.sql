begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

-- SAFRA-C07.1 — minutos nao sao fonte primaria persistida
select is(
  (
    select count(*)::bigint
    from information_schema.columns
    where table_schema='public'
      and (
        lower(column_name) like '%minute%'
        or lower(column_name) like '%duration%'
        or lower(column_name) like '%elapsed%'
        or lower(column_name) like '%remaining%'
      )
  ),
  0::bigint,
  'C07.1 no persisted minute/duration/elapsed/remaining source columns'
);

select ok(
  position('elapsed_seconds' in pg_get_function_result(
    'private.safra_evaluate_sla(timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean)'::regprocedure
  )) > 0
  and position('remaining_seconds' in pg_get_function_result(
    'private.safra_evaluate_sla(timestamptz,timestamptz,timestamptz,timestamptz,numeric,text,boolean)'::regprocedure
  )) > 0,
  'C07.1 derived clock output is canonical seconds'
);

-- SAFRA-C07.2 — timestamps + definicao estruturada
select is(
  (
    select count(*)::bigint
    from information_schema.columns
    where table_schema='public'
      and table_name='scenario_slas'
      and column_name in ('start_event','end_event','target_value','target_unit')
      and is_nullable='NO'
  ),
  4::bigint,
  'C07.2 SLA definition has four required structured fields'
);

select is(
  (
    select data_type
    from information_schema.columns
    where table_schema='public'
      and table_name='treatment_events'
      and column_name='occurred_at'
  ),
  'timestamp with time zone',
  'C07.2 treatment event source timestamp is timestamptz'
);

select is(
  (
    select count(*)::bigint
    from information_schema.columns
    where table_schema='public'
      and table_name='treatments'
      and column_name in ('opened_at','closed_at','cancelled_at')
      and data_type='timestamp with time zone'
  ),
  3::bigint,
  'C07.2 treatment lifecycle timestamps are timestamptz'
);

-- SAFRA-C07.3 — ainda nao mensuravel deve ser explicito
select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',null,null,null,
    '2026-09-27 12:30:00+00',1,'HOUR',false)),
  'NOT_MEASURABLE',
  'C07.3 missing start event is explicitly NOT_MEASURABLE'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',null,null,null,
    '2026-09-27 12:30:00+00',1,'HOUR',false)),
  'START_EVENT_MISSING',
  'C07.3 NOT_MEASURABLE has explicit reason'
);

select is(
  (select evaluation_reason from private.safra_evaluate_sla(
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 12:30:00+00',null,null,false)),
  'STRUCTURED_TARGET_MISSING',
  'C07.3 missing structured target is explicitly signaled'
);

-- SAFRA-C07.4 — timezone
select is(
  current_setting('TimeZone'),
  'UTC',
  'C07.4 database canonical timezone is UTC'
);

select is(
  (
    select count(*)::bigint
    from information_schema.columns
    where table_schema='public'
      and table_name in ('treatments','treatment_events','scenario_slas')
      and column_name in (
        'opened_at','closed_at','cancelled_at',
        'occurred_at','created_at','updated_at'
      )
      and data_type <> 'timestamp with time zone'
  ),
  0::bigint,
  'C07.4 audited operational timestamps use timestamptz'
);

-- SAFRA-C07.5 — relogio negativo proibido
select is(
  (select remaining_seconds from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:30:00+00',1,'HOUR',false)),
  0::numeric,
  'C07.5 breached SLA clamps remaining clock at zero'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 11:59:59+00',1,'HOUR',false)),
  'CLOCK_BEFORE_START',
  'C07.5 clock before start is rejected'
);

-- SAFRA-C07.6 — estado atual: tolerancia implicita proibida, suporte documentado ainda ausente
select is(
  (
    select count(*)::bigint
    from information_schema.columns
    where table_schema='public'
      and table_name='scenario_slas'
      and (
        lower(column_name) like '%tolerance%'
        or lower(column_name) like '%grace%'
        or lower(column_name) like '%buffer%'
      )
  ),
  0::bigint,
  'C07.6 no persisted implicit tolerance/grace/buffer fields exist'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:00:00+00',1,'HOUR',false)),
  'ON_TRACK',
  'C07.6 exact deadline is still valid with zero implicit tolerance'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED','2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:00:00.001+00',1,'HOUR',false)),
  'BREACHED',
  'C07.6 one millisecond after deadline breaches because implicit tolerance is zero'
);

select * from finish();
rollback;
