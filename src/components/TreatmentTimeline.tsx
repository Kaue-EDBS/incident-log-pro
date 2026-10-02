import { useState } from "react";
import { ChevronDown, ChevronUp, History, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { formatDateTime } from "@/lib/metrics";
import { useTreatmentTimeline } from "@/lib/queries";
import type { SafraTimelineEvent } from "@/lib/safra";

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
      return "Protocolo encerrado (as duas partes concluíram)";
    case "TREATMENT_CANCELLED":
      return event.actor_role === "SYSTEM"
        ? "Cancelado automaticamente (72 h sem nenhuma conclusão)"
        : "Cancelou o protocolo";
  }
}

/** Histórico do protocolo (M02/M03): o que aconteceu, quando e quem fez (D-104/D-105). */
export function TreatmentTimeline({ treatmentId }: { treatmentId: string }) {
  const [open, setOpen] = useState(false);
  const { data, isLoading, isError, refetch } = useTreatmentTimeline(treatmentId, open);
  const panelId = `timeline-${treatmentId}`;

  return (
    <div className="mt-3">
      <Button
        variant="ghost"
        size="sm"
        className="-ml-2 min-h-9"
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
            </>
          )}
        </div>
      ) : null}
    </div>
  );
}
