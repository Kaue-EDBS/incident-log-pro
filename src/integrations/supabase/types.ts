export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      governance_issues: {
        Row: {
          created_at: string
          description: string
          id: string
          issue_key: string
          opened_at: string
          resolution_text: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: string
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description: string
          id?: string
          issue_key: string
          opened_at?: string
          resolution_text?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status: string
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string
          id?: string
          issue_key?: string
          opened_at?: string
          resolution_text?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: string
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      notifications_log: {
        Row: {
          channel: string | null
          correlation_id: string
          created_at: string
          delivery_status: string
          failed_at: string | null
          failure_reason: string | null
          id: string
          idempotency_key: string
          notification_type: string
          proposal_id: string | null
          provider: string | null
          queued_at: string
          recipient_email: string
          recipient_principal_id: string | null
          sent_at: string | null
          treatment_id: string | null
        }
        Insert: {
          channel?: string | null
          correlation_id: string
          created_at?: string
          delivery_status: string
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          idempotency_key: string
          notification_type: string
          proposal_id?: string | null
          provider?: string | null
          queued_at?: string
          recipient_email: string
          recipient_principal_id?: string | null
          sent_at?: string | null
          treatment_id?: string | null
        }
        Update: {
          channel?: string | null
          correlation_id?: string
          created_at?: string
          delivery_status?: string
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          idempotency_key?: string
          notification_type?: string
          proposal_id?: string | null
          provider?: string | null
          queued_at?: string
          recipient_email?: string
          recipient_principal_id?: string | null
          sent_at?: string | null
          treatment_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notifications_log_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "scenario_proposals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_log_treatment_id_fkey"
            columns: ["treatment_id"]
            isOneToOne: false
            referencedRelation: "treatments"
            referencedColumns: ["id"]
          },
        ]
      }
      operational_areas: {
        Row: {
          code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      ops_events: {
        Row: {
          actor_user_id: string | null
          code: string | null
          detail: Json
          duration_ms: number | null
          id: string
          kind: string
          occurred_at: string
          route: string | null
        }
        Insert: {
          actor_user_id?: string | null
          code?: string | null
          detail?: Json
          duration_ms?: number | null
          id?: string
          kind: string
          occurred_at?: string
          route?: string | null
        }
        Update: {
          actor_user_id?: string | null
          code?: string | null
          detail?: Json
          duration_ms?: number | null
          id?: string
          kind?: string
          occurred_at?: string
          route?: string | null
        }
        Relationships: []
      }
      scenario_owners: {
        Row: {
          assigned_by: string | null
          assignment_reason: string | null
          created_at: string
          id: string
          owner_id: string
          scenario_id: string
          valid_from: string
          valid_to: string | null
        }
        Insert: {
          assigned_by?: string | null
          assignment_reason?: string | null
          created_at?: string
          id?: string
          owner_id: string
          scenario_id: string
          valid_from?: string
          valid_to?: string | null
        }
        Update: {
          assigned_by?: string | null
          assignment_reason?: string | null
          created_at?: string
          id?: string
          owner_id?: string
          scenario_id?: string
          valid_from?: string
          valid_to?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "scenario_owners_scenario_id_fkey"
            columns: ["scenario_id"]
            isOneToOne: false
            referencedRelation: "scenarios"
            referencedColumns: ["id"]
          },
        ]
      }
      scenario_proposal_owner_responses: {
        Row: {
          candidate_owner_id: string
          created_at: string
          id: string
          proposal_id: string
          responded_at: string
          response: string
          response_note: string | null
        }
        Insert: {
          candidate_owner_id: string
          created_at?: string
          id?: string
          proposal_id: string
          responded_at?: string
          response: string
          response_note?: string | null
        }
        Update: {
          candidate_owner_id?: string
          created_at?: string
          id?: string
          proposal_id?: string
          responded_at?: string
          response?: string
          response_note?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "scenario_proposal_owner_responses_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "scenario_proposals"
            referencedColumns: ["id"]
          },
        ]
      }
      scenario_proposals: {
        Row: {
          created_at: string
          id: string
          problem_description: string
          proposed_by: string
          proposer_email: string
          proposer_name: string
          safra_impact_description: string
          submitted_at: string
          title: string
        }
        Insert: {
          created_at?: string
          id?: string
          problem_description: string
          proposed_by: string
          proposer_email: string
          proposer_name: string
          safra_impact_description: string
          submitted_at?: string
          title: string
        }
        Update: {
          created_at?: string
          id?: string
          problem_description?: string
          proposed_by?: string
          proposer_email?: string
          proposer_name?: string
          safra_impact_description?: string
          submitted_at?: string
          title?: string
        }
        Relationships: []
      }
      scenario_version_impacted_areas: {
        Row: {
          created_at: string
          operational_area_id: string
          scenario_version_id: string
        }
        Insert: {
          created_at?: string
          operational_area_id: string
          scenario_version_id: string
        }
        Update: {
          created_at?: string
          operational_area_id?: string
          scenario_version_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "scenario_version_impacted_areas_operational_area_id_fkey"
            columns: ["operational_area_id"]
            isOneToOne: false
            referencedRelation: "operational_areas"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "scenario_version_impacted_areas_scenario_version_id_fkey"
            columns: ["scenario_version_id"]
            isOneToOne: false
            referencedRelation: "scenario_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      scenario_version_systems: {
        Row: {
          context: string | null
          created_at: string
          scenario_version_id: string
          system_id: string
        }
        Insert: {
          context?: string | null
          created_at?: string
          scenario_version_id: string
          system_id: string
        }
        Update: {
          context?: string | null
          created_at?: string
          scenario_version_id?: string
          system_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "scenario_version_systems_scenario_version_id_fkey"
            columns: ["scenario_version_id"]
            isOneToOne: false
            referencedRelation: "scenario_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "scenario_version_systems_system_id_fkey"
            columns: ["system_id"]
            isOneToOne: false
            referencedRelation: "systems"
            referencedColumns: ["id"]
          },
        ]
      }
      scenario_versions: {
        Row: {
          created_at: string
          created_by: string | null
          criticality: string | null
          detection_description: string | null
          expected_impact_summary: string | null
          id: string
          protocol_text: string | null
          published_at: string | null
          retired_at: string | null
          scenario_id: string
          source_reference: string | null
          status: string
          trigger_description: string | null
          updated_at: string
          version_no: number
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          criticality?: string | null
          detection_description?: string | null
          expected_impact_summary?: string | null
          id?: string
          protocol_text?: string | null
          published_at?: string | null
          retired_at?: string | null
          scenario_id: string
          source_reference?: string | null
          status: string
          trigger_description?: string | null
          updated_at?: string
          version_no: number
        }
        Update: {
          created_at?: string
          created_by?: string | null
          criticality?: string | null
          detection_description?: string | null
          expected_impact_summary?: string | null
          id?: string
          protocol_text?: string | null
          published_at?: string | null
          retired_at?: string | null
          scenario_id?: string
          source_reference?: string | null
          status?: string
          trigger_description?: string | null
          updated_at?: string
          version_no?: number
        }
        Relationships: [
          {
            foreignKeyName: "scenario_versions_scenario_id_fkey"
            columns: ["scenario_id"]
            isOneToOne: false
            referencedRelation: "scenarios"
            referencedColumns: ["id"]
          },
        ]
      }
      scenarios: {
        Row: {
          code: string
          created_at: string
          current_version_id: string | null
          id: string
          lifecycle_status: string
          name: string
          responsible_area_id: string | null
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          current_version_id?: string | null
          id?: string
          lifecycle_status: string
          name: string
          responsible_area_id?: string | null
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          current_version_id?: string | null
          id?: string
          lifecycle_status?: string
          name?: string
          responsible_area_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "scenarios_current_version_same_scenario_fk"
            columns: ["current_version_id", "id"]
            isOneToOne: false
            referencedRelation: "scenario_versions"
            referencedColumns: ["id", "scenario_id"]
          },
          {
            foreignKeyName: "scenarios_responsible_area_id_fkey"
            columns: ["responsible_area_id"]
            isOneToOne: false
            referencedRelation: "operational_areas"
            referencedColumns: ["id"]
          },
        ]
      }
      systems: {
        Row: {
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      treatment_events: {
        Row: {
          actor_user_id: string | null
          correlation_id: string
          created_at: string
          event_type: string
          id: string
          idempotency_key: string | null
          occurred_at: string
          payload: Json
          treatment_id: string
        }
        Insert: {
          actor_user_id?: string | null
          correlation_id: string
          created_at?: string
          event_type: string
          id?: string
          idempotency_key?: string | null
          occurred_at?: string
          payload?: Json
          treatment_id: string
        }
        Update: {
          actor_user_id?: string | null
          correlation_id?: string
          created_at?: string
          event_type?: string
          id?: string
          idempotency_key?: string | null
          occurred_at?: string
          payload?: Json
          treatment_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "treatment_events_treatment_id_fkey"
            columns: ["treatment_id"]
            isOneToOne: false
            referencedRelation: "treatments"
            referencedColumns: ["id"]
          },
        ]
      }
      treatment_impact_measurements: {
        Row: {
          created_at: string
          id: string
          measured_at: string
          metric_code: string
          metric_label: string
          recorded_by: string | null
          source_reference: string
          source_type: string
          treatment_id: string
          unit: string
          value_numeric: number
        }
        Insert: {
          created_at?: string
          id?: string
          measured_at: string
          metric_code: string
          metric_label: string
          recorded_by?: string | null
          source_reference: string
          source_type: string
          treatment_id: string
          unit: string
          value_numeric: number
        }
        Update: {
          created_at?: string
          id?: string
          measured_at?: string
          metric_code?: string
          metric_label?: string
          recorded_by?: string | null
          source_reference?: string
          source_type?: string
          treatment_id?: string
          unit?: string
          value_numeric?: number
        }
        Relationships: [
          {
            foreignKeyName: "treatment_impact_measurements_treatment_id_fkey"
            columns: ["treatment_id"]
            isOneToOne: false
            referencedRelation: "treatments"
            referencedColumns: ["id"]
          },
        ]
      }
      treatment_impacted_areas: {
        Row: {
          added_by: string | null
          created_at: string
          id: string
          operational_area_id: string
          removed_by: string | null
          treatment_id: string
          valid_from: string
          valid_to: string | null
        }
        Insert: {
          added_by?: string | null
          created_at?: string
          id?: string
          operational_area_id: string
          removed_by?: string | null
          treatment_id: string
          valid_from?: string
          valid_to?: string | null
        }
        Update: {
          added_by?: string | null
          created_at?: string
          id?: string
          operational_area_id?: string
          removed_by?: string | null
          treatment_id?: string
          valid_from?: string
          valid_to?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "treatment_impacted_areas_operational_area_id_fkey"
            columns: ["operational_area_id"]
            isOneToOne: false
            referencedRelation: "operational_areas"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "treatment_impacted_areas_treatment_id_fkey"
            columns: ["treatment_id"]
            isOneToOne: false
            referencedRelation: "treatments"
            referencedColumns: ["id"]
          },
        ]
      }
      treatments: {
        Row: {
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          closed_at: string | null
          closed_by: string | null
          created_at: string
          id: string
          impact_summary: string | null
          opened_at: string
          opened_by: string
          owner_closed_at: string | null
          owner_closed_by: string | null
          owner_id_at_start: string
          problem_started_at: string
          protocol_number: string
          protocol_seq: number
          requester_closed_at: string | null
          responsible_area_id_at_start: string
          scenario_id: string
          scenario_version_id: string
          start_correlation_id: string
          start_idempotency_key: string
          status: string
          updated_at: string
        }
        Insert: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          id?: string
          impact_summary?: string | null
          opened_at?: string
          opened_by: string
          owner_closed_at?: string | null
          owner_closed_by?: string | null
          owner_id_at_start: string
          problem_started_at: string
          protocol_number: string
          protocol_seq: number
          requester_closed_at?: string | null
          responsible_area_id_at_start: string
          scenario_id: string
          scenario_version_id: string
          start_correlation_id: string
          start_idempotency_key: string
          status: string
          updated_at?: string
        }
        Update: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          id?: string
          impact_summary?: string | null
          opened_at?: string
          opened_by?: string
          owner_closed_at?: string | null
          owner_closed_by?: string | null
          owner_id_at_start?: string
          problem_started_at?: string
          protocol_number?: string
          protocol_seq?: number
          requester_closed_at?: string | null
          responsible_area_id_at_start?: string
          scenario_id?: string
          scenario_version_id?: string
          start_correlation_id?: string
          start_idempotency_key?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "treatments_responsible_area_id_at_start_fkey"
            columns: ["responsible_area_id_at_start"]
            isOneToOne: false
            referencedRelation: "operational_areas"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "treatments_scenario_id_fkey"
            columns: ["scenario_id"]
            isOneToOne: false
            referencedRelation: "scenarios"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "treatments_version_same_scenario_fk"
            columns: ["scenario_version_id", "scenario_id"]
            isOneToOne: false
            referencedRelation: "scenario_versions"
            referencedColumns: ["id", "scenario_id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      get_my_safra_roles: { Args: never; Returns: string[] }
      get_safra_rbac_audit_events: {
        Args: { p_limit?: number }
        Returns: {
          action: string
          actor_email: string
          correlation_id: string
          occurred_at: string
          resource: string
          result: string
          target_principal_email: string
          target_role: string
        }[]
      }
      safra_admin_get_ops_summary: { Args: { p_hours?: number }; Returns: Json }
      safra_admin_get_owner_treatments: {
        Args: { p_owner_principal_id: string }
        Returns: Json
      }
      safra_can_use_chameleon: { Args: never; Returns: boolean }
      safra_undo_my_part: { Args: { p_treatment_id: string }; Returns: Json }
      safra_get_treatment_timeline: { Args: { p_treatment_id: string }; Returns: Json }
      safra_get_reliability_metrics: { Args: { p_owner_principal_id?: string }; Returns: Json }
      safra_get_season: { Args: never; Returns: Json }
      safra_end_season: { Args: { p_confirm: string }; Returns: Json }
      safra_undo_end_season: { Args: never; Returns: Json }
      safra_start_season: { Args: never; Returns: Json }
      safra_get_all_treatments: {
        Args: { p_limit?: number; p_scenario_id?: string; p_status?: string }
        Returns: Json
      }
      safra_cancel_treatment: {
        Args: { p_reason: string; p_treatment_id: string }
        Returns: Json
      }
      safra_close_my_part: { Args: { p_treatment_id: string }; Returns: Json }
      safra_get_my_treatments: { Args: never; Returns: Json }
      safra_get_owner_treatments: { Args: never; Returns: Json }
      safra_get_start_catalog: { Args: never; Returns: Json }
      safra_has_role: { Args: { requested_role: string }; Returns: boolean }
      safra_is_corporate_user: { Args: never; Returns: boolean }
      safra_log_ops_event: {
        Args: {
          p_code?: string
          p_detail?: Json
          p_duration_ms?: number
          p_kind: string
          p_route?: string
        }
        Returns: undefined
      }
      safra_session_is_live: { Args: never; Returns: boolean }
      safra_start_treatment: {
        Args: {
          p_idempotency_key: string
          p_impact_summary?: string
          p_impacted_area_ids?: string[]
          p_problem_started_at?: string
          p_scenario_id: string
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
