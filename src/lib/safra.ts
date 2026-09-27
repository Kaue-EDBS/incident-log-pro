export type SafraArea = {
  id: string;
  code: string;
  name: string;
};

export type SafraOwner = {
  principal_id: string;
  display_name: string | null;
  corporate_email: string;
};

export type SafraStartCatalogItem = {
  scenario_id: string;
  code: string;
  name: string;
  scenario_version_id: string;
  version_no: number;
  criticality: string | null;
  trigger_description: string | null;
  protocol_text: string | null;
  expected_impact_summary: string | null;
  responsible_area: SafraArea;
  owner: SafraOwner;
  potential_impacted_areas: SafraArea[];
  structured_sla_count: number;
  active_treatment_count: number;
};

export type SafraSlaSnapshot = {
  sla_id: string;
  code: string;
  label: string;
  state: string;
  reason: string;
  started_at: string | null;
  ended_at: string | null;
  deadline_at: string | null;
  elapsed_seconds: number | null;
  remaining_seconds: number | null;
  breached_at: string | null;
  target_text: string;
};

export type SafraStartResult = {
  treatment_id: string;
  status: "ACTIVE" | "RESOLVED" | "CANCELLED";
  opened_at: string;
  opened_by_user_id: string;
  start_correlation_id: string;
  start_idempotency_key: string;
  impact_summary: string | null;
  idempotent_replay: boolean;
  scenario: {
    id: string;
    code: string;
    name: string;
    scenario_version_id: string;
    version_no: number;
    criticality: string | null;
    trigger_description: string | null;
    protocol_text: string | null;
    expected_impact_summary: string | null;
  };
  owner: SafraOwner;
  responsible_area: SafraArea;
  impacted_areas: SafraArea[];
  slas: SafraSlaSnapshot[];
};
