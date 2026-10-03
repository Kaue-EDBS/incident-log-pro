import { useState } from "react";
import { ChevronDown, ChevronUp, History, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useViewer } from "@/lib/chameleon";
import { formatDateTime } from "@/lib/metrics";
import { useTreatmentTimeline } from "@/lib/queries";
import type { SafraTimelineEvent, SafraTimelineNotification } from "@/lib/safra";

const ROLE_LABEL: Record<SafraTimelineEvent["actor_role"], string> = {
  REQUESTER: "quem abriu",
  OWNER: "dono do card",
  SYSTEM: "automático",
};

function eventLabel(event: SafraTimelineEvent): string {
  switch (event.event_type) {
    case "TREATMENT_OPENED":
      return "Abriu o protocolo";
    case "REQUESTER_PART_CLOSED":
      return "Concluiu a parte de quem abriu";
    case "OWNER_PART_CLOSED":
      return "Concluiu a parte do dono do card";
    case "REQUESTER_PART_UNDONE":
    case "OWNER_PART_UNDONE":
      return "Desfez a conclusão";
    case "TREATMENT_RESOLVED":
      return event.actor_role === "SYSTEM"
        ? "Encerrado automaticamente (72 h, valeu a parte já concluída)"
        : "Protocolo encerrado (as duas partes concluíram)";
    case "TREATMENT_CANCELLED":
      return event.actor_role === "SYSTEM"
        ? "Cancelado automaticamente (72 h sem nenhuma conclusão)"
        : "Cancelou o protocolo";
  }
}

const NOTICE_LABEL: Record<string, string> = {
  TREATMENT_OPENED: "Aviso de abertura",
  TREATMENT_RESOLVED: "Aviso de encerramento",
  TREATMENT_CANCELLED: "Aviso de cancelamento",
  PART_UNDONE: "Aviso de conclusão desfeita",
  REMINDER_24H: "Lembrete: faltam 24 h",
  REMINDER_12H: "Lembrete: faltam 12 h",
  REMINDER_1H: "Lembrete: falta 1 h",
};

function noticeStatus(notice: SafraTimelineNotification): string {
  if (notice.delivery_status === "SENT") return `enviado em ${formatDateTime(notice.sent_at)}`;
  if (notice.delivery_status === "FAILED") return "não enviado";
  return "na fila de envio";
}

/** Histórico do protocolo (M02/M03): o que aconteceu, quando e quem fez. Só gestão e admins (D-108). */
export function TreatmentTimeline({ treatmentId }: { treatmentId: string }) {
  const { canSeeAllProtocols } = useViewer();
  const [open, setOpen] = useState(false);
  const { data, isLoading, isError, refetch } = useTreatmentTimeline(
    treatmentId,
    open && canSeeAllProtocols,
  );
  const panelId = `timeline-${treatmentId}`;

  if (!canSeeAllProtocols) return null;

  return (
    <div className="mt-3">
      <Button
        variant="ghost"
        size="sm"
        className="-ml-2 min-h-11"
        aria-expanded={open}
        aria-controls={panelId}
        onClick={() => setOpen((value) => !value)}
      >
        <History aria-hidden="true" />
        {open ? "Esconder histórico" : "Ver histórico"}
        {open ? <ChevronUp aria-hidden="true" /> : <ChevronDown aria-hidden="true" />}
      </Button>

      {open ? (
        <div id={panelId} className="mt-2 rounded-lg border border-border bg-background p-4">
          {isLoading ? (
            <p role="status" className="flex items-center gap-2 text-sm text-muted-foreground">
              <Loader2 className="size-4 animate-spin" aria-hidden="true" />
              Carregando histórico...
            </p>
          ) : isError || !data ? (
            <div role="alert" className="text-sm text-destructive">
              Não foi possível carregar o histórico.{" "}
              <button type="button" className="underline" onClick={() => void refetch()}>
                Tentar de novo
              </button>
            </div>
          ) : (
            <>
              <p className="text-xs text-muted-foreground">
                Aberto por{" "}
                <span className="font-medium text-foreground">{data.opened_by_name}</span>
                {data.scenario_version_no !== null
                  ? ` · versão ${data.scenario_version_no} do card`
                  : ""}
              </p>
              <ol aria-label="Histórico do protocolo" className="mt-3 space-y-2">
                {data.events.map((event) => (
                  <li key={event.event_id} className="flex flex-wrap gap-x-2 text-sm">
                    <time
                      dateTime={event.occurred_at}
                      className="min-w-32 tabular-nums text-muted-foreground"
                    >
                      {formatDateTime(event.occurred_at)}
                    </time>
                    <span>
                      <span className="font-medium">{event.actor_name}</span>
                      <span className="text-muted-foreground">
                        {" "}
                        ({ROLE_LABEL[event.actor_role]})
                      </span>
                      : {eventLabel(event)}
                    </span>
                  </li>
                ))}
              </ol>
              {data.notifications.length ? (
                <>
                  <p className="mt-4 text-xs font-medium text-muted-foreground">
                    Avisos por e-mail
                  </p>
                  <ul aria-label="Avisos do protocolo" className="mt-2 space-y-1">
                    {data.notifications.map((notice) => (
                      <li key={notice.notification_id} className="text-sm">
                        {NOTICE_LABEL[notice.notification_type] ?? notice.notification_type} para{" "}
                        <span className="font-medium">{notice.recipient_name ?? "—"}</span>:{" "}
                        <span className="text-muted-foreground">{noticeStatus(notice)}</span>
                      </li>
                    ))}
                  </ul>
                </>
              ) : null}
            </>
          )}
        </div>
      ) : null}
    </div>
  );
}
