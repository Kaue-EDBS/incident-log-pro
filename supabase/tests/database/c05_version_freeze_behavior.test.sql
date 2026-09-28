begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- C05-AUD-02: behavior, not only trigger presence.
select throws_ok(
  $$
    update public.scenario_versions sv
       set protocol_text = coalesce(protocol_text,'') || ' C05-FREEZE-MUTATION'
      from public.scenarios sc
     where sc.current_version_id=sv.id
       and sc.code='SAFRA-01'
  $$,
  'P0001',
  'PUBLISHED scenario_version content is immutable',
  'published scenario version content cannot be rewritten'
);

select throws_ok(
  $$
    update public.scenario_versions sv
       set status='DRAFT'
      from public.scenarios sc
     where sc.current_version_id=sv.id
       and sc.code='SAFRA-01'
  $$,
  'P0001',
  'PUBLISHED scenario_version may only remain PUBLISHED or become RETIRED',
  'published version cannot move backwards to DRAFT'
);

select throws_ok(
  $$
    delete from public.scenario_version_impacted_areas
     where ctid = (
       select svia.ctid
       from public.scenario_version_impacted_areas svia
       join public.scenarios sc on sc.current_version_id=svia.scenario_version_id
       where sc.code='SAFRA-01'
       limit 1
     )
  $$,
  'P0001',
  'child content of PUBLISHED scenario_version is immutable',
  'impacted areas of a published version are immutable'
);

select throws_ok(
  $$
    delete from public.scenario_version_systems
     where ctid = (
       select svs.ctid
       from public.scenario_version_systems svs
       join public.scenarios sc on sc.current_version_id=svs.scenario_version_id
       where sc.code='SAFRA-01'
       limit 1
     )
  $$,
  'P0001',
  'child content of PUBLISHED scenario_version is immutable',
  'systems of a published version are immutable'
);

select throws_ok(
  $$
    insert into public.scenario_slas(
      scenario_version_id,code,label,start_event,end_event,
      target_value,target_unit,target_text
    )
    select
      current_version_id,'C05-FREEZE-SLA','C05 freeze SLA',
      'START','END',1,'MINUTE','must never persist'
    from public.scenarios
    where code='SAFRA-01'
  $$,
  'P0001',
  'child content of PUBLISHED scenario_version is immutable',
  'SLA cannot be added to a published version'
);

insert into auth.users(
  id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at
)
values(
  '05050505-2000-4000-8000-000000000001'::uuid,
  'c05.freeze.fixture@example.invalid',
  '{"provider":"email"}'::jsonb,
  false,false,clock_timestamp(),clock_timestamp()
);

insert into public.treatments(
  id,scenario_id,scenario_version_id,status,opened_by,
  owner_id_at_start,responsible_area_id_at_start,
  impact_summary,start_correlation_id,start_idempotency_key
)
select
  '05050505-2000-4000-8000-000000000010'::uuid,
  sc.id,sc.current_version_id,'ACTIVE',
  '05050505-2000-4000-8000-000000000001'::uuid,
  so.owner_id,sc.responsible_area_id,
  'C05 version freeze behavior fixture',
  '05050505-2000-4000-8000-000000000011'::uuid,
  'c05-version-freeze-05050505-2000-4000-8000-000000000010'
from public.scenarios sc
join public.scenario_owners so
  on so.scenario_id=sc.id
 and so.valid_to is null
where sc.code='SAFRA-01';

select throws_ok(
  $$
    update public.treatments
       set scenario_version_id=(
         select current_version_id from public.scenarios where code='SAFRA-02'
       )
     where id='05050505-2000-4000-8000-000000000010'::uuid
  $$,
  'P0001',
  'treatment START snapshot fields are immutable',
  'treatment scenario_version_id snapshot is immutable'
);

select throws_ok(
  $$
    update public.treatments
       set owner_id_at_start=(
         select so.owner_id
         from public.scenario_owners so
         join public.scenarios sc on sc.id=so.scenario_id
         where sc.code='SAFRA-09' and so.valid_to is null
       )
     where id='05050505-2000-4000-8000-000000000010'::uuid
  $$,
  'P0001',
  'treatment START snapshot fields are immutable',
  'treatment owner snapshot is immutable'
);

select throws_ok(
  $$
    update public.treatments
       set responsible_area_id_at_start=(
         select id from public.operational_areas
         where id is distinct from (
           select responsible_area_id_at_start
           from public.treatments
           where id='05050505-2000-4000-8000-000000000010'::uuid
         )
         limit 1
       )
     where id='05050505-2000-4000-8000-000000000010'::uuid
  $$,
  'P0001',
  'treatment START snapshot fields are immutable',
  'treatment responsible-area snapshot is immutable'
);

select throws_ok(
  $$
    update public.treatments
       set opened_at=opened_at + interval '1 second'
     where id='05050505-2000-4000-8000-000000000010'::uuid
  $$,
  'P0001',
  'treatment START snapshot fields are immutable',
  'treatment opened_at snapshot is immutable'
);

select ok(
  exists(
    select 1
    from public.treatments
    where id='05050505-2000-4000-8000-000000000010'::uuid
      and status='ACTIVE'
      and scenario_version_id=(
        select current_version_id from public.scenarios where code='SAFRA-01'
      )
  ),
  'all rejected mutations leave the treatment snapshot unchanged'
);

select * from finish();
rollback;
