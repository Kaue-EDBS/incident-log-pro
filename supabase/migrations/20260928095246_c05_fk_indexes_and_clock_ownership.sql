-- C05-AUD Block C
-- HYG-02: support indexes for foreign-key lookup/join paths.
-- HYG-03: server-clock is the single owner of updated_at on
--         scenario_versions and treatments; guards validate only.

create index if not exists idx_governance_issues_resolved_by
  on public.governance_issues(resolved_by);

create index if not exists idx_scenario_proposal_owner_responses_candidate_owner_id
  on public.scenario_proposal_owner_responses(candidate_owner_id);

create index if not exists idx_scenario_version_impacted_areas_operational_area_id
  on public.scenario_version_impacted_areas(operational_area_id);

create index if not exists idx_scenario_version_systems_system_id
  on public.scenario_version_systems(system_id);

create index if not exists idx_treatment_impacted_areas_operational_area_id
  on public.treatment_impacted_areas(operational_area_id);

create or replace function private.safra_guard_scenario_version_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'RETIRED' then
    raise exception 'RETIRED scenario_version is immutable';
  end if;

  if old.status = 'PUBLISHED' then
    if new.scenario_id is distinct from old.scenario_id
       or new.version_no is distinct from old.version_no
       or new.trigger_description is distinct from old.trigger_description
       or new.detection_description is distinct from old.detection_description
       or new.protocol_text is distinct from old.protocol_text
       or new.expected_impact_summary is distinct from old.expected_impact_summary
       or new.criticality is distinct from old.criticality
       or new.source_reference is distinct from old.source_reference
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at
       or new.published_at is distinct from old.published_at
    then
      raise exception 'PUBLISHED scenario_version content is immutable';
    end if;

    if new.status not in ('PUBLISHED','RETIRED') then
      raise exception 'PUBLISHED scenario_version may only remain PUBLISHED or become RETIRED';
    end if;

    if new.status = 'RETIRED' and new.retired_at is null then
      raise exception 'RETIRED scenario_version requires retired_at';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_treatments_updated_at on public.treatments;

comment on function private.safra_guard_scenario_version_update() is
  'Validates scenario_version immutability and lifecycle transitions. Does not own timestamps; trg_00_scenario_versions_server_clock is the clock authority.';

comment on function private.safra_treatment_server_clock() is
  'Single timestamp authority for treatment lifecycle timestamps and updated_at.';

