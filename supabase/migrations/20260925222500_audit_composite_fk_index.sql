-- Complete coverage for the composite scenarios -> scenario_versions FK.
create index if not exists idx_scenarios_current_version_same_scenario
  on public.scenarios(current_version_id, id);
