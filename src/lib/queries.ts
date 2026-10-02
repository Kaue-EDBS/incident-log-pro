import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { z } from "zod";
import { supabase } from "@/integrations/supabase/client";
import { measured } from "./ops";
import {
  SafraStartCatalogSchema,
  SafraStartResultSchema,
  SafraTimelineSchema,
  SafraTreatmentListSchema,
  SafraTreatmentSchema,
} from "./safra";
import type { SafraStartCatalogItem, SafraStartResult, SafraTreatment } from "./safra";

const KEYS = {
  catalog: ["safra-start-catalog"],
  mine: ["safra-my-treatments"],
  owner: ["safra-owner-treatments"],
  roles: ["safra-my-roles"],
  chameleon: ["safra-can-use-chameleon"],
} as const;

function useInvalidateProtocols() {
  const qc = useQueryClient();
  return () => {
    void qc.invalidateQueries({ queryKey: KEYS.catalog });
    void qc.invalidateQueries({ queryKey: KEYS.mine });
    void qc.invalidateQueries({ queryKey: KEYS.owner });
    void qc.invalidateQueries({ queryKey: ["safra-treatment-timeline"] });
    void qc.invalidateQueries({ queryKey: ["safra-all-treatments"] });
  };
}

export function useSafraStartCatalog() {
  return useQuery({
    queryKey: KEYS.catalog,
    queryFn: async (): Promise<SafraStartCatalogItem[]> => {
      const { data, error } = await measured("safra_get_start_catalog", () =>
        supabase.rpc("safra_get_start_catalog"),
      );
      if (error) throw error;
      return SafraStartCatalogSchema.parse(data ?? []);
    },
  });
}

export function useMyTreatments() {
  return useQuery({
    queryKey: KEYS.mine,
    queryFn: async (): Promise<SafraTreatment[]> => {
      const { data, error } = await measured("safra_get_my_treatments", () =>
        supabase.rpc("safra_get_my_treatments"),
      );
      if (error) throw error;
      return SafraTreatmentListSchema.parse(data ?? []);
    },
  });
}

export function useOwnerTreatments(enabled: boolean) {
  return useQuery({
    queryKey: KEYS.owner,
    enabled,
    queryFn: async (): Promise<SafraTreatment[]> => {
      const { data, error } = await measured("safra_get_owner_treatments", () =>
        supabase.rpc("safra_get_owner_treatments"),
      );
      if (error) throw error;
      return SafraTreatmentListSchema.parse(data ?? []);
    },
  });
}

/** Modo Camaleão (D-92): admin da plataforma vê os protocolos dos cards de um dono, só leitura. */
export function useAdminOwnerTreatments(ownerPrincipalId: string | null) {
  return useQuery({
    queryKey: ["safra-admin-owner-treatments", ownerPrincipalId],
    enabled: ownerPrincipalId !== null,
    queryFn: async (): Promise<SafraTreatment[]> => {
      const { data, error } = await measured("safra_admin_get_owner_treatments", () =>
        supabase.rpc("safra_admin_get_owner_treatments", {
          p_owner_principal_id: ownerPrincipalId ?? "",
        }),
      );
      if (error) throw error;
      return SafraTreatmentListSchema.parse(data ?? []);
    },
  });
}

/** Papéis governados no banco; só decidem o que a tela mostra, nunca a permissão. */
export function useMySafraRoles() {
  return useQuery({
    queryKey: KEYS.roles,
    queryFn: async (): Promise<string[]> => {
      const { data, error } = await measured("get_my_safra_roles", () =>
        supabase.rpc("get_my_safra_roles"),
      );
      if (error) throw error;
      return Array.isArray(data) ? data.map(String) : [];
    },
  });
}

/** Modo Camaleão (D-96): o banco decide quem vê o seletor (hoje Kaue e Vinicius). */
export function useCanUseChameleon(enabled: boolean) {
  return useQuery({
    queryKey: KEYS.chameleon,
    enabled,
    queryFn: async (): Promise<boolean> => {
      const { data, error } = await measured("safra_can_use_chameleon", () =>
        supabase.rpc("safra_can_use_chameleon"),
      );
      if (error) throw error;
      return data === true;
    },
  });
}

/** Histórico de um protocolo, carregado só quando a pessoa abre (M02/M03). */
export function useTreatmentTimeline(treatmentId: string, enabled: boolean) {
  return useQuery({
    queryKey: ["safra-treatment-timeline", treatmentId],
    enabled,
    queryFn: async () => {
      const { data, error } = await measured("safra_get_treatment_timeline", () =>
        supabase.rpc("safra_get_treatment_timeline", { p_treatment_id: treatmentId }),
      );
      if (error) throw error;
      return SafraTimelineSchema.parse(data);
    },
  });
}

const NowSummarySchema = z.object({
  active: z.number(),
  nobody_closed: z.number(),
  waiting_owner: z.number(),
  waiting_requester: z.number(),
  closing_within_24h: z.number(),
  oldest_opened_at: z.string().nullable(),
  oldest_protocol_number: z.string().nullable(),
  opened_today: z.number(),
  closed_today: z.number(),
});

export type NowSummary = z.infer<typeof NowSummarySchema>;

const AllTreatmentsSchema = z.object({
  summary: NowSummarySchema.nullable().default(null),
  total: z.number(),
  items: SafraTreatmentListSchema,
});

/** Todos os protocolos, para a gestão e os admins (M03, D-104). */
export function useAllTreatments(
  enabled: boolean,
  filters: { status: string | null; scenarioId: string | null },
) {
  return useQuery({
    queryKey: ["safra-all-treatments", filters.status, filters.scenarioId],
    enabled,
    queryFn: async () => {
      const { data, error } = await measured("safra_get_all_treatments", () =>
        supabase.rpc("safra_get_all_treatments", {
          ...(filters.status ? { p_status: filters.status } : {}),
          ...(filters.scenarioId ? { p_scenario_id: filters.scenarioId } : {}),
        }),
      );
      if (error) throw error;
      return AllTreatmentsSchema.parse(data);
    },
  });
}

const MetricPairSchema = z.object({ mean: z.number().nullable(), median: z.number().nullable() });
const ReliabilityRowSchema = z.object({
  failures: z.number(),
  protocols: z.number(),
  mttd: MetricPairSchema,
  mttr: MetricPairSchema,
  mtbf: MetricPairSchema,
  mttf: MetricPairSchema,
});
const ReliabilitySchema = z.object({
  scope: z.enum(["ALL", "OWNER"]),
  season_start: z.string(),
  as_of: z.string(),
  excluded: z.number(),
  consolidated: ReliabilityRowSchema,
  cards: z.array(
    ReliabilityRowSchema.extend({
      scenario_id: z.string().uuid(),
      code: z.string(),
      name: z.string(),
    }),
  ),
});

export type MetricPair = z.infer<typeof MetricPairSchema>;
export type ReliabilityRow = z.infer<typeof ReliabilityRowSchema>;

/** MTTD, MTTR, MTBF e MTTF da Safra corrente (D-117); o banco decide o escopo (D-88). */
export function useReliabilityMetrics(enabled: boolean, previewOwnerPrincipalId: string | null) {
  return useQuery({
    queryKey: ["safra-reliability-metrics", previewOwnerPrincipalId],
    enabled,
    queryFn: async () => {
      const { data, error } = await measured("safra_get_reliability_metrics", () =>
        supabase.rpc(
          "safra_get_reliability_metrics",
          previewOwnerPrincipalId ? { p_owner_principal_id: previewOwnerPrincipalId } : {},
        ),
      );
      if (error) throw error;
      return ReliabilitySchema.parse(data);
    },
  });
}

const SeasonSchema = z.object({
  open: z.boolean(),
  started_at: z.string().nullable(),
  ended_at: z.string().nullable(),
  can_manage: z.boolean(),
  undo_until: z.string().nullable(),
  server_time: z.string(),
});

const SEASON_KEY = ["safra-season"] as const;

/** Situação da Safra (D-59/D-118): aberta ou encerrada; só o Kaue pode marcar. */
export function useSeason() {
  return useQuery({
    queryKey: SEASON_KEY,
    queryFn: async () => {
      const { data, error } = await measured("safra_get_season", () =>
        supabase.rpc("safra_get_season"),
      );
      if (error) throw error;
      return SeasonSchema.parse(data);
    },
  });
}

function useSeasonMutation<TInput>(
  name: string,
  call: (input: TInput) => PromiseLike<{ data: unknown; error: unknown }>,
) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: TInput) => {
      const { data, error } = await measured(name, () => call(input));
      if (error) throw error;
      return SeasonSchema.parse(data);
    },
    onSettled: () => {
      void qc.invalidateQueries({ queryKey: SEASON_KEY });
      void qc.invalidateQueries({ queryKey: ["safra-reliability-metrics"] });
    },
  });
}

export function useEndSeason() {
  return useSeasonMutation<string>("safra_end_season", (confirm) =>
    supabase.rpc("safra_end_season", { p_confirm: confirm }),
  );
}

export function useUndoEndSeason() {
  return useSeasonMutation<void>("safra_undo_end_season", () =>
    supabase.rpc("safra_undo_end_season"),
  );
}

export function useStartSeason() {
  return useSeasonMutation<void>("safra_start_season", () => supabase.rpc("safra_start_season"));
}

const CardOverviewSchema = z.array(
  z.object({
    scenario_id: z.string().uuid(),
    code: z.string(),
    name: z.string(),
    version_no: z.number().nullable(),
    responsible_area: z.string().nullable(),
    owner_name: z.string().nullable(),
    owner_email: z.string().nullable(),
    owner_available: z.boolean(),
    owner_has_logged_in: z.boolean(),
    active_now: z.number(),
    season_protocols: z.number(),
  }),
);

/** Cards e donos (D-121): gestão e admins. */
export function useCardsOverview(enabled: boolean) {
  return useQuery({
    queryKey: ["safra-cards-overview"],
    enabled,
    queryFn: async () => {
      const { data, error } = await measured("safra_get_cards_overview", () =>
        supabase.rpc("safra_get_cards_overview"),
      );
      if (error) throw error;
      return CardOverviewSchema.parse(data);
    },
  });
}

const PeopleSchema = z.object({
  people: z.array(
    z.object({
      principal_id: z.string().uuid(),
      name: z.string().nullable(),
      email: z.string(),
      active: z.boolean(),
      has_logged_in: z.boolean(),
      last_sign_in_at: z.string().nullable(),
      roles: z.array(z.string()),
      cards: z.array(z.string()),
    }),
  ),
  logins_without_registration: z.number(),
});

/** Painel de cadastrados (D-123): só platform admins. */
export function useAdminPeople(enabled: boolean) {
  return useQuery({
    queryKey: ["safra-admin-people"],
    enabled,
    queryFn: async () => {
      const { data, error } = await measured("safra_admin_get_people", () =>
        supabase.rpc("safra_admin_get_people"),
      );
      if (error) throw error;
      return PeopleSchema.parse(data);
    },
  });
}

const RbacTrailSchema = z.array(
  z.object({
    occurred_at: z.string(),
    actor_email: z.string().nullable(),
    action: z.string(),
    resource: z.string().nullable(),
    target_principal_email: z.string().nullable(),
    target_role: z.string().nullable(),
    result: z.string().nullable(),
  }),
);

/** Trilha de papéis (D-123). */
export function useRbacTrail(enabled: boolean) {
  return useQuery({
    queryKey: ["safra-rbac-trail"],
    enabled,
    queryFn: async () => {
      const { data, error } = await measured("get_safra_rbac_audit_events", () =>
        supabase.rpc("get_safra_rbac_audit_events", { p_limit: 100 }),
      );
      if (error) throw error;
      return RbacTrailSchema.parse(data ?? []);
    },
  });
}

const ScreenUsageSchema = z.object({
  from: z.string(),
  routes: z.array(z.object({ route: z.string(), views: z.number(), today: z.number().nullable() })),
});

/** Uso das telas, anônimo (D-124). */
export function useScreenUsage(enabled: boolean) {
  return useQuery({
    queryKey: ["safra-screen-usage"],
    enabled,
    queryFn: async () => {
      const { data, error } = await measured("safra_admin_get_screen_usage", () =>
        supabase.rpc("safra_admin_get_screen_usage", { p_days: 30 }),
      );
      if (error) throw error;
      return ScreenUsageSchema.parse(data);
    },
  });
}

const ProposalSchema = z.object({
  proposal_id: z.string().uuid(),
  status: z.enum([
    "SUBMITTED",
    "OWNER_CONSULTATION",
    "OWNER_DEFINED",
    "CONTENT_SUBMITTED",
    "APPROVED",
    "PUBLISHED",
    "REJECTED",
  ]),
  title: z.string(),
  problem_description: z.string(),
  safra_impact_description: z.string(),
  proposer_name: z.string(),
  submitted_at: z.string(),
  mine: z.boolean(),
  owner_name: z.string().nullable(),
  owner_decision: z.string().nullable(),
  owner_note: z.string().nullable(),
  scenario_name: z.string().nullable(),
  trigger_description: z.string().nullable(),
  detection_description: z.string().nullable(),
  protocol_text: z.string().nullable(),
  expected_impact_summary: z.string().nullable(),
  impacted_area_ids: z.array(z.string()),
  responsible_area: z.string().nullable(),
  published_code: z.string().nullable(),
  rejection_reason: z.string().nullable().default(null),
  responses: z.array(
    z.object({
      name: z.string(),
      response: z.string(),
      note: z.string().nullable(),
      responded_at: z.string(),
    }),
  ),
  my_response: z.string().nullable(),
  events: z.array(
    z.object({
      event_type: z.string(),
      occurred_at: z.string(),
      actor_name: z.string(),
      note: z.string().nullable(),
    }),
  ),
  can_forward: z.boolean(),
  can_respond: z.boolean(),
  can_define_owner: z.boolean(),
  can_submit_content: z.boolean(),
  can_approve: z.boolean(),
  can_publish: z.boolean(),
  can_reject: z.boolean().default(false),
});

const ProposalsSchema = z.object({
  me: z.object({
    name: z.string().nullable(),
    email: z.string().nullable(),
    is_candidate: z.boolean(),
  }),
  candidates: z.array(z.object({ principal_id: z.string().uuid(), name: z.string() })),
  items: z.array(ProposalSchema),
});

export type Proposal = z.infer<typeof ProposalSchema>;
export type ProposalsData = z.infer<typeof ProposalsSchema>;

const PROPOSALS_KEY = ["safra-proposals"] as const;

/** Propostas de card novo (M10): o banco decide o que cada pessoa vê e pode fazer. */
export function useProposals() {
  return useQuery({
    queryKey: PROPOSALS_KEY,
    queryFn: async () => {
      const { data, error } = await measured("safra_get_proposals", () =>
        supabase.rpc("safra_get_proposals"),
      );
      if (error) throw error;
      return ProposalsSchema.parse(data);
    },
  });
}

const AreasSchema = z.array(
  z.object({ id: z.string().uuid(), code: z.string(), name: z.string() }),
);

export function useOperationalAreas(enabled: boolean) {
  return useQuery({
    queryKey: ["safra-operational-areas"],
    enabled,
    staleTime: 60 * 60 * 1000,
    queryFn: async () => {
      const { data, error } = await measured("safra_get_operational_areas", () =>
        supabase.rpc("safra_get_operational_areas"),
      );
      if (error) throw error;
      return AreasSchema.parse(data);
    },
  });
}

type ProposalCommand =
  | "safra_submit_proposal"
  | "safra_forward_proposal"
  | "safra_respond_proposal"
  | "safra_define_proposal_owner"
  | "safra_submit_proposal_content"
  | "safra_approve_proposal"
  | "safra_publish_proposal"
  | "safra_reject_proposal";

/** Comandos da M10; cada um é conferido de novo no banco (D-68). */
export function useProposalAction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: { name: string; args: Record<string, unknown> }) => {
      const name = input.name as ProposalCommand;
      const { error } = await measured(name, () =>
        (
          supabase.rpc as unknown as (
            fn: string,
            args: Record<string, unknown>,
          ) => PromiseLike<{ error: unknown }>
        )(name, input.args),
      );
      if (error) throw error;
    },
    onSettled: () => {
      void qc.invalidateQueries({ queryKey: PROPOSALS_KEY });
      void qc.invalidateQueries({ queryKey: KEYS.catalog });
      void qc.invalidateQueries({ queryKey: ["safra-cards-overview"] });
    },
  });
}

export function useSafraStartTreatment() {
  const invalidate = useInvalidateProtocols();

  return useMutation({
    mutationFn: async (input: {
      scenarioId: string;
      idempotencyKey: string;
      impactSummary: string;
      impactedAreaIds: string[];
      problemStartedAt: string | null;
    }): Promise<SafraStartResult> => {
      const { data, error } = await measured("safra_start_treatment", () =>
        supabase.rpc("safra_start_treatment", {
          p_scenario_id: input.scenarioId,
          p_idempotency_key: input.idempotencyKey,
          p_impact_summary: input.impactSummary,
          p_impacted_area_ids: input.impactedAreaIds,
          ...(input.problemStartedAt ? { p_problem_started_at: input.problemStartedAt } : {}),
        }),
      );

      if (error) throw error;
      return SafraStartResultSchema.parse(data);
    },
    onSuccess: invalidate,
  });
}

export function useCloseMyPart() {
  const invalidate = useInvalidateProtocols();

  return useMutation({
    mutationFn: async (treatmentId: string): Promise<SafraTreatment> => {
      const { data, error } = await measured("safra_close_my_part", () =>
        supabase.rpc("safra_close_my_part", {
          p_treatment_id: treatmentId,
        }),
      );
      if (error) throw error;
      return SafraTreatmentSchema.parse(data);
    },
    onSettled: invalidate,
  });
}

/** Desfazer o "Concluído" da própria parte em até 5 minutos (D-99). */
export function useUndoMyPart() {
  const invalidate = useInvalidateProtocols();

  return useMutation({
    mutationFn: async (treatmentId: string): Promise<SafraTreatment> => {
      const { data, error } = await measured("safra_undo_my_part", () =>
        supabase.rpc("safra_undo_my_part", {
          p_treatment_id: treatmentId,
        }),
      );
      if (error) throw error;
      return SafraTreatmentSchema.parse(data);
    },
    onSettled: invalidate,
  });
}

export function useCancelTreatment() {
  const invalidate = useInvalidateProtocols();

  return useMutation({
    mutationFn: async (input: { treatmentId: string; reason: string }): Promise<SafraTreatment> => {
      const { data, error } = await measured("safra_cancel_treatment", () =>
        supabase.rpc("safra_cancel_treatment", {
          p_treatment_id: input.treatmentId,
          p_reason: input.reason,
        }),
      );
      if (error) throw error;
      return SafraTreatmentSchema.parse(data);
    },
    onSettled: invalidate,
  });
}

export const OpsSummarySchema = z.object({
  since: z.string(),
  server_time: z.string(),
  events_by_kind: z.record(z.string(), z.number()),
  slow_p95_ms: z.number().nullable(),
  protocols: z.object({
    opened: z.number(),
    resolved: z.number(),
    cancelled: z.number(),
    auto_cancelled: z.number().default(0),
    auto_resolved: z.number().default(0),
    active_now: z.number(),
    oldest_active_opened_at: z.string().nullable(),
  }),
  notifications: z
    .object({ queued: z.number(), sent: z.number(), failed: z.number(), expired: z.number() })
    .default({ queued: 0, sent: 0, failed: 0, expired: 0 }),
  recent: z.array(
    z.object({
      occurred_at: z.string(),
      kind: z.string(),
      route: z.string().nullable(),
      code: z.string().nullable(),
      duration_ms: z.number().nullable(),
      actor_user_id: z.string().nullable(),
    }),
  ),
});

export type OpsSummary = z.infer<typeof OpsSummarySchema>;

/** Saúde do sistema (D-95): só admins da plataforma; o banco recusa os demais. */
export function useOpsSummary(enabled: boolean, hours = 24) {
  return useQuery({
    queryKey: ["safra-ops-summary", hours],
    enabled,
    queryFn: async (): Promise<OpsSummary> => {
      const { data, error } = await measured("safra_admin_get_ops_summary", () =>
        supabase.rpc("safra_admin_get_ops_summary", { p_hours: hours }),
      );
      if (error) throw error;
      return OpsSummarySchema.parse(data);
    },
  });
}
