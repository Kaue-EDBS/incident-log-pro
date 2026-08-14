export type Application = {
  id: string;
  name: string;
  description: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

export type IncidentStatus = "active" | "resolved";

export type Incident = {
  id: string;
  application_id: string;
  status: IncidentStatus;
  failure_started_at: string | null;
  detected_at: string;
  response_started_at: string | null;
  recovered_at: string | null;
  type: string | null;
  category: string | null;
  responsible: string | null;
  cause: string | null;
  resolution: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export const INCIDENT_TYPES = [
  "Indisponibilidade",
  "Lentidão",
  "Erro de aplicação",
  "Banco de dados",
  "Infraestrutura",
  "Integração",
  "Outro",
] as const;

export type PeriodKey = "today" | "7d" | "30d" | "month" | "custom";

export const PERIOD_LABELS: Record<PeriodKey, string> = {
  today: "Hoje",
  "7d": "7 dias",
  "30d": "30 dias",
  month: "Este mês",
  custom: "Personalizado",
};
