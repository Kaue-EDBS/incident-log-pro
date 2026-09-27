import { z } from "zod";

export const SafraAreaSchema = z.object({
  id: z.string().uuid(),
  code: z.string(),
  name: z.string(),
});

export type SafraArea = z.infer<typeof SafraAreaSchema>;

export const SafraOwnerSchema = z.object({
  principal_id: z.string().uuid(),
  display_name: z.string().nullable(),
  corporate_email: z.string().email(),
});

export type SafraOwner = z.infer<typeof SafraOwnerSchema>;

const SafraCriticalitySchema = z.enum(["CRITICAL", "HIGH", "MODERATE"]).nullable();

export const SafraStartCatalogItemSchema = z.object({
  scenario_id: z.string().uuid(),
  code: z.string(),
  name: z.string(),
  scenario_version_id: z.string().uuid(),
  version_no: z.number().int().positive(),
  criticality: SafraCriticalitySchema,
  trigger_description: z.string().nullable(),
  protocol_text: z.string().nullable(),
  expected_impact_summary: z.string().nullable(),
  responsible_area: SafraAreaSchema,
  owner: SafraOwnerSchema,
  potential_impacted_areas: z.array(SafraAreaSchema),
  structured_sla_count: z.number().int().nonnegative(),
  active_treatment_count: z.number().int().nonnegative(),
});

export const SafraStartCatalogSchema = z.array(SafraStartCatalogItemSchema);

export type SafraStartCatalogItem = z.infer<typeof SafraStartCatalogItemSchema>;

export const SafraSlaSnapshotSchema = z.object({
  sla_id: z.string().uuid(),
  code: z.string(),
  label: z.string(),
  state: z.enum([
    "ON_TRACK",
    "BREACHED",
    "COMPLETED_ON_TIME",
    "COMPLETED_LATE",
    "NOT_MEASURABLE",
    "NOT_APPLICABLE",
  ]),
  reason: z.string(),
  started_at: z.string().nullable(),
  ended_at: z.string().nullable(),
  deadline_at: z.string().nullable(),
  elapsed_seconds: z.number().nullable(),
  remaining_seconds: z.number().nullable(),
  breached_at: z.string().nullable(),
  target_text: z.string(),
});

export type SafraSlaSnapshot = z.infer<typeof SafraSlaSnapshotSchema>;

export const SafraStartResultSchema = z.object({
  treatment_id: z.string().uuid(),
  status: z.enum(["ACTIVE", "RESOLVED", "CANCELLED"]),
  opened_at: z.string(),
  opened_by_user_id: z.string().uuid(),
  start_correlation_id: z.string().uuid(),
  start_idempotency_key: z.string().uuid(),
  impact_summary: z.string().nullable(),
  idempotent_replay: z.boolean(),
  scenario: z.object({
    id: z.string().uuid(),
    code: z.string(),
    name: z.string(),
    scenario_version_id: z.string().uuid(),
    version_no: z.number().int().positive(),
    criticality: SafraCriticalitySchema,
    trigger_description: z.string().nullable(),
    protocol_text: z.string().nullable(),
    expected_impact_summary: z.string().nullable(),
  }),
  owner: SafraOwnerSchema,
  responsible_area: SafraAreaSchema,
  impacted_areas: z.array(SafraAreaSchema),
  slas: z.array(SafraSlaSnapshotSchema),
});

export type SafraStartResult = z.infer<typeof SafraStartResultSchema>;
