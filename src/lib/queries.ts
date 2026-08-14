import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import type { Application, Incident } from "./types";

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

export function useStartIncident() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (input: { application_id: string; type: string }) => {
      const { data, error } = await supabase
        .from("incidents")
        .insert({
          application_id: input.application_id,
          type: input.type,
          category: input.type,
          status: "active",
          detected_at: new Date().toISOString(),
        })
        .select("*")
        .single();
      if (error) throw error;
      return data as Incident;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["incidents"] });
    },
  });
}

export function useUpdateIncident() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, values }: { id: string; values: Partial<Incident> }) => {
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
