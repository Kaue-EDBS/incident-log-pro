import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import type { Application, Incident } from "./types";
import { SafraStartCatalogSchema, SafraStartResultSchema } from "./safra";
import type { SafraStartCatalogItem, SafraStartResult } from "./safra";

type LegacyIncidentUpdate = Partial<
  Pick<
    Incident,
    | "failure_started_at"
    | "response_started_at"
    | "recovered_at"
    | "status"
    | "type"
    | "category"
    | "responsible"
    | "cause"
    | "resolution"
    | "notes"
  >
>;

export function useApplications() {
  return useQuery({
    queryKey: ["applications"],
    queryFn: async (): Promise<Application[]> => {
      const { data, error } = await supabase
        .from("applications")
        .select("*")
        .order("name", { ascending: true });
      if (error) throw error;
      return (data ?? []) as Application[];
    },
  });
}

export function useIncidents() {
  return useQuery({
    queryKey: ["incidents"],
    queryFn: async (): Promise<Incident[]> => {
      const { data, error } = await supabase
        .from("incidents")
        .select("*")
        .order("detected_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as Incident[];
    },
    refetchInterval: 60000,
  });
}

export function useIncident(id: string) {
  return useQuery({
    queryKey: ["incidents", id],
    queryFn: async (): Promise<Incident> => {
      const { data, error } = await supabase.from("incidents").select("*").eq("id", id).single();
      if (error) throw error;
      return data as Incident;
    },
  });
}

export function useUpdateIncident() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, values }: { id: string; values: LegacyIncidentUpdate }) => {
      const { data, error } = await supabase
        .from("incidents")
        .update(values)
        .eq("id", id)
        .select("*")
        .single();
      if (error) throw error;
      return data as Incident;
    },
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ["incidents"] });
      qc.invalidateQueries({ queryKey: ["incidents", data.id] });
    },
  });
}

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
  const qc = useQueryClient();

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
        p_impact_summary: input.impactSummary ?? undefined,
        p_impacted_area_ids: input.impactedAreaIds,
      });

      if (error) throw error;
      return SafraStartResultSchema.parse(data);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["safra-start-catalog"] });
    },
  });
}
