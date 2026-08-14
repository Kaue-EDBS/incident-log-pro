import { createFileRoute, Link } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { CheckCircle2, Clock, Gauge, Radar, Wrench } from "lucide-react";
import { Filters, type FilterState } from "@/components/Filters";
import { LiveTimer } from "@/components/LiveTimer";
import { MetricCard } from "@/components/MetricCard";
import { StatusBadge } from "@/components/StatusBadge";
import { useApplications, useIncidents } from "@/lib/queries";
import { computeMetrics, formatDateTime, formatMinutes, resolveRange } from "@/lib/metrics";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Visão Geral | Reliability Monitor — Editora do Brasil" },
      {
        name: "description",
        content:
          "Painel de confiabilidade das aplicações da Editora do Brasil com MTTD, MTTR, MTBF, downtime e disponibilidade.",
      },
      { property: "og:title", content: "Visão Geral | Reliability Monitor" },
      {
        property: "og:description",
        content: "Acompanhe incidentes e indicadores de disponibilidade em tempo real.",
      },
    ],
  }),
  component: Overview,
});

function Overview() {
  const [filters, setFilters] = useState<FilterState>({ period: "30d", applicationId: "all" });
  const { data: applications = [] } = useApplications();
  const { data: incidents = [], isLoading } = useIncidents();

  const range = useMemo(
    () => resolveRange(filters.period, { from: filters.from, to: filters.to }),
    [filters],
  );

  const filtered = useMemo(
    () =>
      incidents.filter((i) => {
        const t = new Date(i.detected_at).getTime();
        if (t < range.from.getTime() || t > range.to.getTime()) return false;
        if (filters.applicationId !== "all" && i.application_id !== filters.applicationId)
          return false;
        return true;
      }),
    [incidents, range, filters.applicationId],
  );

  const metrics = useMemo(() => computeMetrics(filtered, range), [filtered, range]);
  const activeIncidents = incidents.filter((i) => i.status === "active");

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Visão Geral</h1>
        <p className="text-sm text-muted-foreground">
          Confiabilidade das aplicações da Editora do Brasil.
        </p>
      </header>

      <Filters value={filters} onChange={setFilters} applications={applications} />

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          label="MTTD"
          icon={<Radar className="size-4" />}
          value={formatMinutes(metrics.mttd)}
          hint="Tempo médio para detecção: detecção menos o início da falha. Só entram incidentes com início da falha informado."
          helper="Tempo médio para detectar"
        />
        <MetricCard
          label="MTTR"
          icon={<Wrench className="size-4" />}
          value={formatMinutes(metrics.mttr)}
          hint="Tempo médio para recuperação: recuperação menos detecção. Considera apenas incidentes encerrados."
          helper="Tempo médio para recuperar"
        />
        <MetricCard
          label="MTBF"
          icon={<Clock className="size-4" />}
          value={formatMinutes(metrics.mtbf)}
          hint="Tempo médio entre falhas, calculado por aplicação: início da próxima falha menos a recuperação anterior."
          helper="Intervalo médio entre falhas"
        />
        <MetricCard
          label="Disponibilidade"
          icon={<Gauge className="size-4" />}
          value={`${metrics.availability.toFixed(2)}%`}
          hint="(Tempo total do período - downtime) / tempo total do período. Cálculo 24x7."
          helper={`${metrics.count} incidente(s) · downtime ${formatMinutes(metrics.downtime)}${metrics.downtimeEstimated ? " (estimado)" : ""}`}
        />
      </section>

      <section className="space-y-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
          Aplicações
        </h2>
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {applications.map((app) => {
            const appIncidents = filtered.filter((i) => i.application_id === app.id);
            const appMetrics = computeMetrics(appIncidents, range);
            const active = activeIncidents.find((i) => i.application_id === app.id);
            const last = incidents.find((i) => i.application_id === app.id);
            return (
              <div
                key={app.id}
                className="rounded-xl border border-border bg-card p-5 transition-shadow hover:shadow-sm"
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-base font-semibold">{app.name}</p>
                    <p className="text-xs text-muted-foreground">{app.description}</p>
                  </div>
                  <StatusBadge active={Boolean(active)} />
                </div>

                {active ? (
                  <Link
                    to="/incidentes/$id"
                    params={{ id: active.id }}
                    className="pulse-incident mt-4 flex items-center justify-between rounded-lg bg-destructive/10 px-4 py-3"
                  >
                    <span className="text-xs font-medium text-destructive">Em andamento</span>
                    <LiveTimer
                      since={active.detected_at}
                      className="text-lg font-semibold text-destructive"
                    />
                  </Link>
                ) : (
                  <div className="mt-4 space-y-1 text-xs text-muted-foreground">
                    <p>Último incidente: {last ? formatDateTime(last.detected_at) : "—"}</p>
                  </div>
                )}

                <div className="mt-4 grid grid-cols-2 gap-3 border-t border-border pt-4 text-sm">
                  <div>
                    <p className="text-xs text-muted-foreground">Disponibilidade</p>
                    <p className="font-semibold">{appMetrics.availability.toFixed(2)}%</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">Incidentes</p>
                    <p className="font-semibold">{appMetrics.count}</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {!isLoading && activeIncidents.length === 0 ? (
        <div className="flex flex-col items-center gap-2 rounded-xl border border-dashed border-border bg-card px-6 py-10 text-center">
          <CheckCircle2 className="size-6 text-[color:var(--turquoise)]" />
          <p className="text-sm font-medium">Todas as aplicações estão operacionais</p>
          <p className="text-xs text-muted-foreground">
            Nenhum incidente em andamento neste momento.
          </p>
        </div>
      ) : null}
    </div>
  );
}
