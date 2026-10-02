import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { z } from "zod";
import { supabase } from "@/integrations/supabase/client";
import { measured } from "./ops";
import {
  SafraStartCatalogSchema,
  SafraStartResultSchema,
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
    active_now: z.number(),
    oldest_active_opened_at: z.string().nullable(),
  }),
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
