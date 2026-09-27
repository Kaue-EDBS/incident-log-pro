begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into public.scenarios(code,name,lifecycle_status,responsible_area_id)
select 'TEST-C07-MULTI-SLA','Synthetic multi-SLA scenario','ACTIVE',id
from public.operational_areas
order by code
limit 1;

insert into public.scenario_versions(
  scenario_id,version_no,status,trigger_description,source_reference
)
select id,1,'DRAFT','Synthetic test trigger','C07 multi-SLA pgTAP'
from public.scenarios
where code='TEST-C07-MULTI-SLA';

with v as (
  select sv.id
  from public.scenario_versions sv
  join public.scenarios sc on sc.id=sv.scenario_id
  where sc.code='TEST-C07-MULTI-SLA' and sv.version_no=1
)
insert into public.scenario_slas(
  scenario_version_id,code,label,start_event,end_event,target_value,target_unit,target_text
)
select id,'TEST-SLA-1H','Synthetic SLA 1h','TREATMENT_OPENED','TREATMENT_RESOLVED',1,'HOUR','Synthetic test only' from v
union all
select id,'TEST-SLA-2H','Synthetic SLA 2h','TREATMENT_OPENED','TREATMENT_RESOLVED',2,'HOUR','Synthetic test only' from v;

select is(
  (
    select count(*)::bigint
    from public.scenario_slas sl
    join public.scenario_versions sv on sv.id=sl.scenario_version_id
    join public.scenarios sc on sc.id=sv.scenario_id
    where sc.code='TEST-C07-MULTI-SLA'
      and sl.code in ('TEST-SLA-1H','TEST-SLA-2H')
  ),
  2::bigint,
  'one scenario version supports multiple SLA definitions'
);

select is(
  (
    select count(distinct sl.code)::bigint
    from public.scenario_slas sl
    join public.scenario_versions sv on sv.id=sl.scenario_version_id
    join public.scenarios sc on sc.id=sv.scenario_id
    where sc.code='TEST-C07-MULTI-SLA'
      and sl.code in ('TEST-SLA-1H','TEST-SLA-2H')
  ),
  2::bigint,
  'multiple SLAs remain independently identified by code'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:30:00+00',1,'HOUR',false
  )),
  'BREACHED',
  'first SLA can breach independently'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:30:00+00',2,'HOUR',false
  )),
  'ON_TRACK',
  'second SLA can remain on track independently'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    null,null,null,
    '2026-09-27 13:30:00+00',1,'HOUR',false
  )),
  'NOT_MEASURABLE',
  'missing required start event is NOT_MEASURABLE'
);

select is(
  (select evaluation_reason from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    null,null,null,
    '2026-09-27 13:30:00+00',1,'HOUR',false
  )),
  'START_EVENT_MISSING',
  'missing required start event has explicit reason'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 12:30:00+00',1,'HOUR',false
  )),
  'ON_TRACK',
  'missing RESOLVED event on active SLA means still running, not invalid'
);

select is(
  (select sla_state from private.safra_evaluate_configured_sla(
    'TREATMENT_RESOLVED',
    '2026-09-27 12:00:00+00',null,null,
    '2026-09-27 13:30:00+00',1,'HOUR',false
  )),
  'BREACHED',
  'missing RESOLVED event after deadline means BREACHED'
);

select throws_ok(
  $$
    with v as (
      select sv.id
      from public.scenario_versions sv
      join public.scenarios sc on sc.id=sv.scenario_id
      where sc.code='TEST-C07-MULTI-SLA' and sv.version_no=1
      limit 1
    )
    insert into public.scenario_slas(
      scenario_version_id,code,label,start_event,end_event,target_value,target_unit,target_text
    )
    select id,'TEST-SLA-1H','Duplicate','TREATMENT_OPENED','TREATMENT_RESOLVED',3,'HOUR','Synthetic duplicate' from v;
  $$,
  '23505',
  null,
  'same SLA code cannot be duplicated inside one scenario version'
);

select is(
  (select count(*)::bigint from public.scenario_slas),
  2::bigint,
  'test creates only the two intended synthetic SLA rows before rollback'
);

select * from finish();
rollback;
