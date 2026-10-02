import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
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
      const { data, error } = await supabase.rpc("safra_get_start_catalog");
      if (error) throw error;
      return SafraStartCatalogSchema.parse(data ?? []);
    },
  });
}

export function useMyTreatments() {
  return useQuery({
    queryKey: KEYS.mine,
    queryFn: async (): Promise<SafraTreatment[]> => {
      const { data, error } = await supabase.rpc("safra_get_my_treatments");
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
      const { data, error } = await supabase.rpc("safra_get_owner_treatments");
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
      const { data, error } = await supabase.rpc("get_my_safra_roles");
      if (error) throw error;
      return Array.isArray(data) ? data.map(String) : [];
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
      const { data, error } = await supabase.rpc("safra_start_treatment", {
        p_scenario_id: input.scenarioId,
        p_idempotency_key: input.idempotencyKey,
        p_impact_summary: input.impactSummary,
        p_impacted_area_ids: input.impactedAreaIds,
        ...(input.problemStartedAt ? { p_problem_started_at: input.problemStartedAt } : {}),
      });

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
      const { data, error } = await supabase.rpc("safra_close_my_part", {
        p_treatment_id: treatmentId,
      });
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
      const { data, error } = await supabase.rpc("safra_cancel_treatment", {
        p_treatment_id: input.treatmentId,
        p_reason: input.reason,
      });
      if (error) throw error;
      return SafraTreatmentSchema.parse(data);
    },
    onSettled: invalidate,
  });
}
