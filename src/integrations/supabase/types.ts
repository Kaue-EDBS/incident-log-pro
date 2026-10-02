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
          attempts: number
          body: string | null
          channel: string | null
          claimed_by: string | null
          correlation_id: string
          created_at: string
          delivery_status: string
          event_id: string | null
          failed_at: string | null
          failure_reason: string | null
          id: string
          idempotency_key: string
          last_error: string | null
          locked_until: string | null
          next_attempt_at: string
          notification_type: string
          proposal_id: string | null
          provider: string | null
          queued_at: string
          recipient_email: string
          recipient_name: string | null
          recipient_principal_id: string | null
          recipient_role: string | null
          sent_at: string | null
          subject: string | null
          template_version: number | null
          treatment_id: string | null
          triggered_by: string | null
        }
        Insert: {
          attempts?: number
          body?: string | null
          channel?: string | null
          claimed_by?: string | null
          correlation_id: string
          created_at?: string
          delivery_status: string
          event_id?: string | null
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          idempotency_key: string
          last_error?: string | null
          locked_until?: string | null
          next_attempt_at?: string
          notification_type: string
          proposal_id?: string | null
          provider?: string | null
          queued_at?: string
          recipient_email: string
          recipient_name?: string | null
          recipient_principal_id?: string | null
          recipient_role?: string | null
          sent_at?: string | null
          subject?: string | null
          template_version?: number | null
          treatment_id?: string | null
          triggered_by?: string | null
        }
        Update: {
          attempts?: number
          body?: string | null
          channel?: string | null
          claimed_by?: string | null
          correlation_id?: string
          created_at?: string
          delivery_status?: string
          event_id?: string | null
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          idempotency_key?: string
          last_error?: string | null
          locked_until?: string | null
          next_attempt_at?: string
          notification_type?: string
          proposal_id?: string | null
          provider?: string | null
          queued_at?: string
          recipient_email?: string
          recipient_name?: string | null
          recipient_principal_id?: string | null
          recipient_role?: string | null
          sent_at?: string | null
          subject?: string | null
          template_version?: number | null
          treatment_id?: string | null
          triggered_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notifications_log_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "treatment_events"
            referencedColumns: ["id"]
          },
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
      safra_season_events: {
        Row: {
          actor_user_id: string | null
          event_type: string
          id: string
          note: string | null
          occurred_at: string
          season_id: string
        }
        Insert: {
          actor_user_id?: string | null
          event_type: string
          id?: string
          note?: string | null
          occurred_at?: string
          season_id: string
        }
        Update: {
          actor_user_id?: string | null
          event_type?: string
          id?: string
          note?: string | null
          occurred_at?: string
          season_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "safra_season_events_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "safra_seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      safra_seasons: {
        Row: {
          created_at: string
          ended_at: string | null
          ended_by: string | null
          id: string
          started_at: string
          started_by: string | null
        }
        Insert: {
          created_at?: string
          ended_at?: string | null
          ended_by?: string | null
          id?: string
          started_at: string
          started_by?: string | null
        }
        Update: {
          created_at?: string
          ended_at?: string | null
          ended_by?: string | null
          id?: string
          started_at?: string
          started_by?: string | null
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
      scenario_proposal_events: {
        Row: {
          actor_user_id: string | null
          event_type: string
          id: string
          note: string | null
          occurred_at: string
          proposal_id: string
        }
        Insert: {
          actor_user_id?: string | null
          event_type: string
          id?: string
          note?: string | null
          occurred_at?: string
          proposal_id: string
        }
        Update: {
          actor_user_id?: string | null
          event_type?: string
          id?: string
          note?: string | null
          occurred_at?: string
          proposal_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "scenario_proposal_events_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "scenario_proposals"
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
          approved_at: string | null
          approved_by: string | null
          content_submitted_at: string | null
          created_at: string
          detection_description: string | null
          expected_impact_summary: string | null
          forwarded_at: string | null
          forwarded_by: string | null
          id: string
          impacted_area_ids: string[]
          owner_decision: string | null
          owner_defined_at: string | null
          owner_defined_by: string | null
          owner_note: string | null
          owner_principal_id: string | null
          problem_description: string
          proposed_by: string
          proposer_email: string
          proposer_name: string
          protocol_text: string | null
          published_at: string | null
          published_by: string | null
          rejected_at: string | null
          rejected_by: string | null
          rejection_reason: string | null
          responsible_area_id: string | null
          safra_impact_description: string
          scenario_id: string | null
          scenario_name: string | null
          status: string
          submitted_at: string
          title: string
          trigger_description: string | null
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          content_submitted_at?: string | null
          created_at?: string
          detection_description?: string | null
          expected_impact_summary?: string | null
          forwarded_at?: string | null
          forwarded_by?: string | null
          id?: string
          impacted_area_ids?: string[]
          owner_decision?: string | null
          owner_defined_at?: string | null
          owner_defined_by?: string | null
          owner_note?: string | null
          owner_principal_id?: string | null
          problem_description: string
          proposed_by: string
          proposer_email: string
          proposer_name: string
          protocol_text?: string | null
          published_at?: string | null
          published_by?: string | null
          rejected_at?: string | null
          rejected_by?: string | null
          rejection_reason?: string | null
          responsible_area_id?: string | null
          safra_impact_description: string
          scenario_id?: string | null
          scenario_name?: string | null
          status?: string
          submitted_at?: string
          title: string
          trigger_description?: string | null
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          content_submitted_at?: string | null
          created_at?: string
          detection_description?: string | null
          expected_impact_summary?: string | null
          forwarded_at?: string | null
          forwarded_by?: string | null
          id?: string
          impacted_area_ids?: string[]
          owner_decision?: string | null
          owner_defined_at?: string | null
          owner_defined_by?: string | null
          owner_note?: string | null
          owner_principal_id?: string | null
          problem_description?: string
          proposed_by?: string
          proposer_email?: string
          proposer_name?: string
          protocol_text?: string | null
          published_at?: string | null
          published_by?: string | null
          rejected_at?: string | null
          rejected_by?: string | null
          rejection_reason?: string | null
          responsible_area_id?: string | null
          safra_impact_description?: string
          scenario_id?: string | null
          scenario_name?: string | null
          status?: string
          submitted_at?: string
          title?: string
          trigger_description?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "scenario_proposals_responsible_area_id_fkey"
            columns: ["responsible_area_id"]
            isOneToOne: false
            referencedRelation: "operational_areas"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "scenario_proposals_scenario_id_fkey"
            columns: ["scenario_id"]
            isOneToOne: false
            referencedRelation: "scenarios"
            referencedColumns: ["id"]
          },
        ]
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
      screen_views_daily: {
        Row: {
          day: string
          route: string
          views: number
        }
        Insert: {
          day: string
          route: string
          views?: number
        }
        Update: {
          day?: string
          route?: string
          views?: number
        }
        Relationships: []
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
      treatment_analytics_exclusions: {
        Row: {
          excluded_at: string
          excluded_by: string | null
          reason: string
          treatment_id: string
        }
        Insert: {
          excluded_at?: string
          excluded_by?: string | null
          reason: string
          treatment_id: string
        }
        Update: {
          excluded_at?: string
          excluded_by?: string | null
          reason?: string
          treatment_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "treatment_analytics_exclusions_treatment_id_fkey"
            columns: ["treatment_id"]
            isOneToOne: true
            referencedRelation: "treatments"
            referencedColumns: ["id"]
          },
        ]
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
          auto_cancelled: boolean
          auto_resolved: boolean
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
          auto_cancelled?: boolean
          auto_resolved?: boolean
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
          auto_cancelled?: boolean
          auto_resolved?: boolean
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
      safra_admin_get_people: { Args: never; Returns: Json }
      safra_admin_get_screen_usage: { Args: { p_days?: number }; Returns: Json }
      safra_approve_proposal: {
        Args: { p_proposal_id: string; p_responsible_area_id: string }
        Returns: undefined
      }
      safra_can_use_chameleon: { Args: never; Returns: boolean }
      safra_cancel_treatment: {
        Args: { p_reason: string; p_treatment_id: string }
        Returns: Json
      }
      safra_close_my_part: { Args: { p_treatment_id: string }; Returns: Json }
      safra_define_proposal_owner: {
        Args: {
          p_note: string
          p_owner_principal_id: string
          p_proposal_id: string
        }
        Returns: undefined
      }
      safra_end_season: { Args: { p_confirm: string }; Returns: Json }
      safra_forward_proposal: {
        Args: { p_proposal_id: string }
        Returns: undefined
      }
      safra_get_all_treatments: {
        Args: { p_limit?: number; p_scenario_id?: string; p_status?: string }
        Returns: Json
      }
      safra_get_cards_overview: { Args: never; Returns: Json }
      safra_get_my_treatments: { Args: never; Returns: Json }
      safra_get_operational_areas: { Args: never; Returns: Json }
      safra_get_owner_treatments: { Args: never; Returns: Json }
      safra_get_proposals: { Args: never; Returns: Json }
      safra_get_reliability_metrics: {
        Args: { p_owner_principal_id?: string }
        Returns: Json
      }
      safra_get_season: { Args: never; Returns: Json }
      safra_get_start_catalog: { Args: never; Returns: Json }
      safra_get_treatment_timeline: {
        Args: { p_treatment_id: string }
        Returns: Json
      }
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
      safra_log_screen_view: { Args: { p_route: string }; Returns: undefined }
      safra_notifications_claim: { Args: { p_limit?: number }; Returns: Json }
      safra_notifications_claim_for_session: {
        Args: { p_limit?: number }
        Returns: Json
      }
      safra_notifications_report: {
        Args: { p_error?: string; p_id: string; p_ok: boolean }
        Returns: undefined
      }
      safra_notifications_report_for_session: {
        Args: { p_error?: string; p_id: string; p_ok: boolean }
        Returns: undefined
      }
      safra_publish_proposal: { Args: { p_proposal_id: string }; Returns: Json }
      safra_reject_proposal: {
        Args: { p_proposal_id: string; p_reason: string }
        Returns: undefined
      }
      safra_respond_proposal: {
        Args: { p_accept: boolean; p_note?: string; p_proposal_id: string }
        Returns: undefined
      }
      safra_session_is_live: { Args: never; Returns: boolean }
      safra_start_season: { Args: never; Returns: Json }
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
      safra_submit_proposal: {
        Args: { p_impact: string; p_problem: string; p_title: string }
        Returns: string
      }
      safra_submit_proposal_content: {
        Args: {
          p_detection: string
          p_expected_impact: string
          p_impacted_area_ids: string[]
          p_proposal_id: string
          p_protocol: string
          p_scenario_name: string
          p_trigger: string
        }
        Returns: undefined
      }
      safra_undo_end_season: { Args: never; Returns: Json }
      safra_undo_my_part: { Args: { p_treatment_id: string }; Returns: Json }
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
