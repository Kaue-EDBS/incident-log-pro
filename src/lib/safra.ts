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

/** Situações do protocolo (D-72). */
export const SafraSituationSchema = z.enum([
  "EM_ANDAMENTO",
  "AGUARDANDO_DONO",
  "AGUARDANDO_SOLICITANTE",
  "ENCERRADO",
  "CANCELADO",
]);

export type SafraSituation = z.infer<typeof SafraSituationSchema>;

export const SafraTreatmentSchema = z.object({
  treatment_id: z.string().uuid(),
  protocol_number: z.string(),
  status: z.enum(["ACTIVE", "RESOLVED", "CANCELLED"]),
  situation: SafraSituationSchema,
  scenario: z.object({
    id: z.string().uuid(),
    code: z.string(),
    name: z.string(),
  }),
  owner: SafraOwnerSchema,
  requester_email: z.string(),
  // Só na lista geral (M03, D-105).
  requester_name: z.string().nullable().default(null),
  impact_summary: z.string().nullable(),
  impacted_areas: z.array(SafraAreaSchema),
  problem_started_at: z.string(),
  opened_at: z.string(),
  requester_closed_at: z.string().nullable(),
  owner_closed_at: z.string().nullable(),
  closed_at: z.string().nullable(),
  cancelled_at: z.string().nullable(),
  cancellation_reason: z.string().nullable(),
  // M01 (D-99, D-101); com padrão para funcionar antes da migration chegar ao banco.
  auto_cancelled: z.boolean().default(false),
  auto_cancel_at: z.string().nullable().default(null),
  // M05 (D-113).
  auto_resolved: z.boolean().default(false),
  auto_resolve_at: z.string().nullable().default(null),
  undo_until: z.string().nullable().default(null),
  can_undo_my_part: z.boolean().default(false),
  server_time: z.string(),
  my_role: z.enum(["REQUESTER", "OWNER"]).nullable(),
  can_close_my_part: z.boolean(),
  can_cancel: z.boolean(),
});

export type SafraTreatment = z.infer<typeof SafraTreatmentSchema>;

/** Histórico do protocolo (M02/M03). */
export const SafraTimelineEventSchema = z.object({
  event_id: z.string().uuid(),
  occurred_at: z.string(),
  event_type: z.enum([
    "TREATMENT_OPENED",
    "REQUESTER_PART_CLOSED",
    "OWNER_PART_CLOSED",
    "REQUESTER_PART_UNDONE",
    "OWNER_PART_UNDONE",
    "TREATMENT_RESOLVED",
    "TREATMENT_CANCELLED",
  ]),
  actor_role: z.enum(["REQUESTER", "OWNER", "SYSTEM"]),
  actor_name: z.string(),
});

export type SafraTimelineEvent = z.infer<typeof SafraTimelineEventSchema>;

export const SafraTimelineNotificationSchema = z.object({
  notification_id: z.string().uuid(),
  notification_type: z.string(),
  recipient_name: z.string().nullable(),
  delivery_status: z.enum(["QUEUED", "SENT", "FAILED"]),
  queued_at: z.string(),
  sent_at: z.string().nullable(),
  failed_at: z.string().nullable(),
});

export type SafraTimelineNotification = z.infer<typeof SafraTimelineNotificationSchema>;

export const SafraTimelineSchema = z.object({
  treatment: SafraTreatmentSchema,
  scenario_version_no: z.number().nullable(),
  opened_by_name: z.string(),
  events: z.array(SafraTimelineEventSchema),
  // M05: avisos do protocolo (só gestão e admins chegam ao histórico, D-108).
  notifications: z.array(SafraTimelineNotificationSchema).default([]),
});

export type SafraTimeline = z.infer<typeof SafraTimelineSchema>;

export const SafraTreatmentListSchema = z.array(SafraTreatmentSchema);

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
  is_my_card: z.boolean(),
  my_open_treatment: SafraTreatmentSchema.nullable(),
  potential_impacted_areas: z.array(SafraAreaSchema),
  active_treatment_count: z.number().int().nonnegative(),
});

export const SafraStartCatalogSchema = z.array(SafraStartCatalogItemSchema);

export type SafraStartCatalogItem = z.infer<typeof SafraStartCatalogItemSchema>;

export const SafraStartResultSchema = z.object({
  treatment_id: z.string().uuid(),
  status: z.enum(["ACTIVE", "RESOLVED", "CANCELLED"]),
  protocol_number: z.string(),
  opened_at: z.string(),
  problem_started_at: z.string(),
  server_time: z.string(),
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
});

export type SafraStartResult = z.infer<typeof SafraStartResultSchema>;

/** Texto e tom de cada situação: nunca só cor (WCAG 1.4.1). */
export const SITUATION_LABEL: Record<SafraSituation, string> = {
  EM_ANDAMENTO: "Em andamento",
  AGUARDANDO_DONO: "Aguardando o dono do card",
  AGUARDANDO_SOLICITANTE: "Aguardando quem abriu",
  ENCERRADO: "Encerrado",
  CANCELADO: "Cancelado",
};

/** Mensagens de erro do banco em linguagem simples. */
export function safraErrorMessage(error: unknown, fallback: string): string {
  const message =
    error && typeof error === "object" && "message" in error
      ? String((error as { message: unknown }).message)
      : "";
  const known: Array<[string, string]> = [
    [
      "SAFRA_START_FORBIDDEN",
      "Sua sessão não está autorizada. Entre de novo com a conta Microsoft da Editora.",
    ],
    [
      "SAFRA_READ_FORBIDDEN",
      "Sua sessão não está autorizada. Entre de novo com a conta Microsoft da Editora.",
    ],
    ["SAFRA_SCENARIO_NOT_STARTABLE", "Este card não está disponível para abertura."],
    [
      "SAFRA_SCENARIO_OWNER_UNAVAILABLE",
      "Este card está bloqueado temporariamente até a definição de um novo dono.",
    ],
    ["SAFRA_INVALID_IMPACTED_AREA", "Uma das áreas escolhidas não pertence a este card."],
    [
      "SAFRA_START_OWNER_OWN_CARD",
      "Você é o dono deste card. Donos não abrem protocolo do próprio card.",
    ],
    [
      "SAFRA_START_ACTIVE_EXISTS",
      "Você já tem um protocolo aberto neste card. Conclua a sua parte antes de abrir outro.",
    ],
    [
      "SAFRA_IMPACT_SUMMARY_REQUIRED",
      "Explique o problema em pelo menos 10 caracteres para orientar o dono do card.",
    ],
    ["SAFRA_IMPACT_SUMMARY_TOO_LONG", "A explicação passou de 2.000 caracteres. Resuma um pouco."],
    ["SAFRA_PROBLEM_START_IN_FUTURE", "O início do problema não pode estar no futuro."],
    [
      "SAFRA_START_IDEMPOTENCY_CONFLICT",
      "Os dados mudaram desde a tentativa anterior. Confira e tente de novo.",
    ],
    ["SAFRA_CLOSE_FORBIDDEN", "Só quem abriu o protocolo ou o dono do card pode concluir."],
    ["SAFRA_CANCEL_FORBIDDEN", "Só quem abriu o protocolo ou o dono do card pode cancelar."],
    ["SAFRA_TREATMENT_NOT_ACTIVE", "Este protocolo já foi encerrado ou cancelado."],
    [
      "SAFRA_CANCEL_REASON_REQUIRED",
      "Explique o motivo do cancelamento em pelo menos 10 caracteres.",
    ],
    ["SAFRA_CANCEL_REASON_TOO_LONG", "O motivo passou de 1.000 caracteres. Resuma um pouco."],
    ["SAFRA_UNDO_FORBIDDEN", "Só quem concluiu a parte pode desfazer."],
    ["SAFRA_TIMELINE_FORBIDDEN", "Você não tem acesso ao histórico deste protocolo."],
    ["SAFRA_INVALID_FILTER", "Filtro inválido. Recarregue a página e tente de novo."],
    ["SAFRA_UNDO_NOTHING_TO_UNDO", "Não há conclusão sua para desfazer neste protocolo."],
    ["SAFRA_UNDO_WINDOW_EXPIRED", "Passaram os 5 minutos para desfazer."],
    [
      "SAFRA_UNDO_BLOCKED_BY_NEW_PROTOCOL",
      "Você já abriu outro protocolo neste card. Conclua ou cancele o novo antes de desfazer.",
    ],
  ];
  const hit = known.find(([code]) => message.includes(code));
  return hit ? hit[1] : fallback;
}

/** "SAFRA-08" -> "08"; usado no número do protocolo (D-82). */
export function cardNumber(code: string): string {
  const match = /^SAFRA-(\d+)$/.exec(code);
  return match?.[1] ?? code;
}

/**
 * Nome do card para a tela (D-91): o banco guarda o texto literal da Matriz v3 (D-74);
 * a tela tira o que está entre parênteses e junta as linhas.
 */
export function cardDisplayName(name: string): string {
  return name
    .replace(/\s*\([^)]*\)/g, "")
    .replace(/\s+/g, " ")
    .trim();
}
