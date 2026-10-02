import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { LiveTimer } from "@/components/LiveTimer";
import { SituationBadge, TreatmentActions } from "@/components/TreatmentActions";
import { TreatmentTimeline } from "@/components/TreatmentTimeline";
import { formatDateTime } from "@/lib/metrics";
import { cardDisplayName } from "@/lib/safra";
import type { SafraTreatment } from "@/lib/safra";

/** Lista de protocolos; o contador só aparece aqui (D-86). */
export function TreatmentList({
  items,
  isLoading,
  isError,
  onRetry,
  emptyText,
  showRequester,
}: {
  items: SafraTreatment[];
  isLoading: boolean;
  isError: boolean;
  onRetry: () => void;
  emptyText: string;
  showRequester?: boolean;
}) {
  if (isLoading) {
    return (
      <div
        role="status"
        className="flex items-center gap-3 rounded-xl border border-border bg-card p-6 text-sm text-muted-foreground"
      >
        <Loader2 className="size-4 animate-spin" aria-hidden="true" />
        Carregando protocolos...
      </div>
    );
  }

  if (isError) {
    return (
      <div role="alert" className="rounded-xl border border-destructive/30 bg-destructive/10 p-5">
        <p className="font-medium text-destructive">Não foi possível carregar os protocolos.</p>
        <Button variant="outline" className="mt-3" onClick={onRetry}>
          Tentar de novo
        </Button>
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <p className="rounded-xl border border-dashed border-border bg-card p-6 text-sm text-muted-foreground">
        {emptyText}
      </p>
    );
  }

  return (
    <ul className="space-y-3">
      {items.map((item) => (
        <li key={item.treatment_id}>
          <article
            aria-labelledby={`protocol-${item.treatment_id}`}
            className="rounded-xl border border-border bg-card p-5"
          >
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h3 id={`protocol-${item.treatment_id}`} className="text-base font-semibold">
                  Protocolo {item.protocol_number}
                </h3>
                <p className="text-sm text-muted-foreground">
                  {cardDisplayName(item.scenario.name)}
                </p>
              </div>
              <SituationBadge situation={item.situation} />
            </div>

            {item.impact_summary ? <p className="mt-3 text-sm">{item.impact_summary}</p> : null}

            <dl className="mt-3 grid gap-x-6 gap-y-1 text-xs text-muted-foreground sm:grid-cols-2 lg:grid-cols-4">
              {showRequester ? (
                <div>
                  <dt className="inline">Aberto por: </dt>
                  <dd className="inline">{item.requester_name ?? item.requester_email}</dd>
                </div>
              ) : (
                <div>
                  <dt className="inline">Dono do card: </dt>
                  <dd className="inline">
                    {item.owner.display_name ?? item.owner.corporate_email}
                  </dd>
                </div>
              )}
              {item.impacted_areas.length ? (
                <div className="sm:col-span-2 lg:col-span-4">
                  <dt className="inline">Áreas impactadas: </dt>
                  <dd className="inline">
                    {item.impacted_areas.map((area) => area.name).join(", ")}
                  </dd>
                </div>
              ) : null}
              <div>
                <dt className="inline">Problema começou: </dt>
                <dd className="inline">{formatDateTime(item.problem_started_at)}</dd>
              </div>
              <div>
                <dt className="inline">Aberto: </dt>
                <dd className="inline">{formatDateTime(item.opened_at)}</dd>
              </div>
              {item.status === "ACTIVE" ? (
                <div>
                  <dt className="inline">Tempo desde a abertura: </dt>
                  <dd className="inline font-medium text-foreground">
                    <LiveTimer since={item.opened_at} serverNow={item.server_time} />
                  </dd>
                </div>
              ) : (
                <div>
                  <dt className="inline">
                    {item.status === "RESOLVED" ? "Encerrado: " : "Cancelado: "}
                  </dt>
                  <dd className="inline">
                    {formatDateTime(
                      item.status === "RESOLVED" ? item.closed_at : item.cancelled_at,
                    )}
                  </dd>
                </div>
              )}
            </dl>

            {item.cancellation_reason ? (
              <p className="mt-2 text-xs text-muted-foreground">
                Motivo do cancelamento: {item.cancellation_reason}
              </p>
            ) : null}

            {item.auto_cancel_at ? (
              <p className="mt-2 text-xs text-muted-foreground">
                Se ninguém concluir, será cancelado automaticamente em{" "}
                {formatDateTime(item.auto_cancel_at)} (72 h depois da abertura).
              </p>
            ) : null}

            {item.status === "ACTIVE" ? (
              <div className="mt-4">
                <TreatmentActions treatment={item} />
              </div>
            ) : null}

            <TreatmentTimeline treatmentId={item.treatment_id} />
          </article>
        </li>
      ))}
    </ul>
  );
}
