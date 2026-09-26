-- Audit performance hardening: index foreign-key columns used by SAFRA relationships.
-- Safe on empty/low-volume operational tables and avoids parent-delete/join scans later.

create index if not exists idx_scenarios_responsible_area_id
  on public.scenarios(responsible_area_id);
create index if not exists idx_scenarios_current_version_id
  on public.scenarios(current_version_id);

create index if not exists idx_scenario_versions_created_by
  on public.scenario_versions(created_by);

create index if not exists idx_scenario_owners_assigned_by
  on public.scenario_owners(assigned_by);

create index if not exists idx_treatments_version_scenario
  on public.treatments(scenario_version_id, scenario_id);
create index if not exists idx_treatments_opened_by
  on public.treatments(opened_by);
create index if not exists idx_treatments_closed_by
  on public.treatments(closed_by);
create index if not exists idx_treatments_cancelled_by
  on public.treatments(cancelled_by);
create index if not exists idx_treatments_owner_at_start
  on public.treatments(owner_id_at_start);
create index if not exists idx_treatments_responsible_area_at_start
  on public.treatments(responsible_area_id_at_start);

create index if not exists idx_treatment_events_actor_user_id
  on public.treatment_events(actor_user_id);

create index if not exists idx_treatment_impacted_areas_added_by
  on public.treatment_impacted_areas(added_by);
create index if not exists idx_treatment_impacted_areas_removed_by
  on public.treatment_impacted_areas(removed_by);

create index if not exists idx_treatment_impact_measurements_treatment_id
  on public.treatment_impact_measurements(treatment_id);
create index if not exists idx_treatment_impact_measurements_recorded_by
  on public.treatment_impact_measurements(recorded_by);

create index if not exists idx_treatment_escalations_changed_by
  on public.treatment_escalations(changed_by);

create index if not exists idx_scenario_proposals_proposed_by
  on public.scenario_proposals(proposed_by);

create index if not exists idx_notifications_log_treatment_id
  on public.notifications_log(treatment_id);
create index if not exists idx_notifications_log_proposal_id
  on public.notifications_log(proposal_id);
create index if not exists idx_notifications_log_recipient_principal_id
  on public.notifications_log(recipient_principal_id);
