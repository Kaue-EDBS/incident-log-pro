begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id=sc.current_version_id
   join public.operational_areas oa on oa.id=sc.responsible_area_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and oa.name = sv.source_reference::jsonb->>'responsible_area'),
  11::bigint,
  'responsible area matches Matriz v3 source for all 11 scenarios'
);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id=sc.current_version_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and sv.protocol_text = sv.source_reference::jsonb->>'protocol'),
  11::bigint,
  'protocol matches Matriz v3 source for all 11 scenarios'
);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id=sc.current_version_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and sv.criticality is null),
  11::bigint,
  'criticality remains null for all 11 while source does not support nominal classification'
);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id=sc.current_version_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and btrim(sv.source_reference::jsonb->>'sla_target') <> ''),
  11::bigint,
  'SLA textual is preserved for all 11 scenarios'
);

select is(
  (select count(*)::bigint
   from public.scenario_slas sl
   join public.scenario_versions sv on sv.id=sl.scenario_version_id
   join public.scenarios sc on sc.id=sv.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'),
  0::bigint,
  'no structured SLA is inferred before C07'
);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id=sc.current_version_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and not exists (
       (
         select btrim(x)
         from regexp_split_to_table(sv.source_reference::jsonb->>'impacted_areas', ',') x
         except
         select oa.name
         from public.scenario_version_impacted_areas via
         join public.operational_areas oa on oa.id=via.operational_area_id
         where via.scenario_version_id=sv.id
       )
       union all
       (
         select oa.name
         from public.scenario_version_impacted_areas via
         join public.operational_areas oa on oa.id=via.operational_area_id
         where via.scenario_version_id=sv.id
         except
         select btrim(x)
         from regexp_split_to_table(sv.source_reference::jsonb->>'impacted_areas', ',') x
       )
     )),
  11::bigint,
  'potential impacted areas match Matriz v3 exactly'
);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id=sc.current_version_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and 1 = (
       select count(*)
       from public.scenario_version_systems vss
       join public.systems sys on sys.id=vss.system_id
       where vss.scenario_version_id=sv.id
         and sys.name = sv.source_reference::jsonb->>'tool'
     )),
  11::bigint,
  'literal Ferramenta value is linked for every scenario version'
);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id=sc.current_version_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and sv.source_reference::jsonb->>'mapping'='EDB05'),
  2::bigint,
  'exactly two scenarios map to EDB05'
);

select is(
  (select count(*)::bigint
   from public.scenarios sc
   join public.scenario_versions sv on sv.id=sc.current_version_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'
     and sv.source_reference::jsonb->>'mapping'='EDB06'),
  9::bigint,
  'exactly nine scenarios map to EDB06'
);

select is(
  (select count(distinct sys.name)::bigint
   from public.scenario_version_systems vss
   join public.systems sys on sys.id=vss.system_id
   join public.scenario_versions sv on sv.id=vss.scenario_version_id
   join public.scenarios sc on sc.id=sv.scenario_id
   where sc.code ~ '^SAFRA-(0[1-9]|1[01])$'),
  10::bigint,
  'Matriz v3 produces ten unique literal Ferramenta catalog entries'
);

select * from finish();
rollback;
