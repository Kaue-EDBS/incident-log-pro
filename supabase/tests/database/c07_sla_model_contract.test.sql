begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select is(
  (select is_nullable
   from information_schema.columns
   where table_schema='public' and table_name='scenario_slas' and column_name='start_event'),
  'NO',
  'C07 SLA model requires start_event'
);

select is(
  (select is_nullable
   from information_schema.columns
   where table_schema='public' and table_name='scenario_slas' and column_name='end_event'),
  'NO',
  'C07 SLA model requires end_event'
);

select is(
  (select is_nullable
   from information_schema.columns
   where table_schema='public' and table_name='scenario_slas' and column_name='target_value'),
  'NO',
  'C07 SLA model requires target_value'
);

select is(
  (select is_nullable
   from information_schema.columns
   where table_schema='public' and table_name='scenario_slas' and column_name='target_unit'),
  'NO',
  'C07 SLA model requires target_unit'
);

select ok(
  exists(
    select 1
    from pg_constraint
    where conrelid='public.scenario_slas'::regclass
      and conname='scenario_slas_target_value_positive'
  ),
  'target_value keeps positive-value invariant'
);

select ok(
  exists(
    select 1
    from pg_constraint
    where conrelid='public.scenario_slas'::regclass
      and conname='scenario_slas_target_unit_supported'
  ),
  'target_unit keeps supported-unit invariant'
);

select ok(
  exists(
    select 1
    from pg_constraint
    where conrelid='public.scenario_slas'::regclass
      and conname='scenario_slas_distinct_events'
  ),
  'start_event and end_event must remain distinct'
);

select is(
  col_description('public.scenario_slas'::regclass,
    (select ordinal_position
     from information_schema.columns
     where table_schema='public' and table_name='scenario_slas' and column_name='target_value')) is not null,
  true,
  'target_value has canonical semantic documentation'
);

select is(
  col_description('public.scenario_slas'::regclass,
    (select ordinal_position
     from information_schema.columns
     where table_schema='public' and table_name='scenario_slas' and column_name='target_unit')) is not null,
  true,
  'target_unit has canonical semantic documentation'
);

select is(
  (select count(*)::bigint from public.scenario_slas),
  0::bigint,
  'model hardening does not infer or publish SLA rows'
);

select * from finish();
rollback;
