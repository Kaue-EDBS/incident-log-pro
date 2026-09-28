import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { SafraStartCatalogSchema, SafraStartResultSchema } from "./safra";
import type { SafraStartCatalogItem, SafraStartResult } from "./safra";

export function useSafraStartCatalog() {
  return useQuery({
    queryKey: ["safra-start-catalog"],
    queryFn: async (): Promise<SafraStartCatalogItem[]> => {
      const { data, error } = await supabase.rpc("safra_get_start_catalog");
      if (error) throw error;
      return SafraStartCatalogSchema.parse(data ?? []);
    },
  });
}

export function useSafraStartTreatment() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (input: {
      scenarioId: string;
      idempotencyKey: string;
      impactSummary: string | null;
      impactedAreaIds: string[];
    }): Promise<SafraStartResult> => {
      const { data, error } = await supabase.rpc("safra_start_treatment", {
        p_scenario_id: input.scenarioId,
        p_idempotency_key: input.idempotencyKey,
        p_impact_summary: input.impactSummary,
        p_impacted_area_ids: input.impactedAreaIds,
      });

      if (error) throw error;
      return SafraStartResultSchema.parse(data);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["safra-start-catalog"] });
    },
  });
}
