import { createFileRoute, Link } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { Filters, type FilterState } from "@/components/Filters";
import { StatusBadge } from "@/components/StatusBadge";
import { useApplications, useIncidents } from "@/lib/queries";
import {
  formatDateTime,
  formatMinutes,
  incidentDowntime,
  incidentMttd,
  incidentMttr,
  resolveRange,
} from "@/lib/metrics";
import { INCIDENT_TYPES } from "@/lib/types";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/incidentes/")({
  head: () => ({
    meta: [
      { title: "Histórico de Incidentes | Reliability Monitor" },
      {
        name: "description",
        content: "Histórico completo de incidentes com downtime, MTTD, MTTR e filtros por período.",
      },
      { property: "og:title", content: "Histórico de Incidentes | Reliability Monitor" },
      {
        property: "og:description",
        content: "Consulte todos os incidentes registrados e seus indicadores.",
      },
    ],
  }),
  component: IncidentsPage,
});

function IncidentsPage() {
  const [filters, setFilters] = useState<FilterState>({ period: "30d", applicationId: "all" });
  const [category, setCategory] = useState<string>("all");
  const [status, setStatus] = useState<string>("all");
  const { data: applications = [] } = useApplications();
  const { data: incidents = [] } = useIncidents();

  const appName = (id: string) => applications.find((a) => a.id === id)?.name ?? "—";

  const range = useMemo(
    () => resolveRange(filters.period, { from: filters.from, to: filters.to }),
    [filters],
  );

  const rows = useMemo(
    () =>
      incidents.filter((i) => {
        const t = new Date(i.detected_at).getTime();
        if (t < range.from.getTime() || t > range.to.getTime()) return false;
        if (filters.applicationId !== "all" && i.application_id !== filters.applicationId)
          return false;
        if (category !== "all" && i.category !== category) return false;
        if (status !== "all" && i.status !== status) return false;
        return true;
      }),
    [incidents, range, filters.applicationId, category, status],
  );

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Incidentes</h1>
        <p className="text-sm text-muted-foreground">Histórico completo de registros.</p>
      </header>

      <Filters value={filters} onChange={setFilters} applications={applications} />

      <div className="flex flex-wrap gap-3">
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          className="h-9 rounded-lg border border-border bg-card px-3 text-sm"
        >
          <option value="all">Todas as categorias</option>
          {INCIDENT_TYPES.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          className="h-9 rounded-lg border border-border bg-card px-3 text-sm"
        >
          <option value="all">Todos os status</option>
          <option value="active">Em andamento</option>
          <option value="resolved">Encerrado</option>
        </select>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border bg-card">
        <table className="w-full min-w-[720px] text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase tracking-wide text-muted-foreground">
              <th className="px-4 py-3 font-medium">Data</th>
              <th className="px-4 py-3 font-medium">Aplicação</th>
              <th className="px-4 py-3 font-medium">Categoria</th>
              <th className="px-4 py-3 font-medium">Downtime</th>
              <th className="px-4 py-3 font-medium">MTTD</th>
              <th className="px-4 py-3 font-medium">MTTR</th>
              <th className="px-4 py-3 font-medium">Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((i) => {
              const down = incidentDowntime(i);
              return (
                <tr key={i.id} className="border-b border-border last:border-0 hover:bg-muted/60">
                  <td className="px-4 py-3">
                    <Link to="/incidentes/$id" params={{ id: i.id }} className="block font-medium">
                      {formatDateTime(i.detected_at)}
                    </Link>
                  </td>
                  <td className="px-4 py-3">{appName(i.application_id)}</td>
                  <td className="px-4 py-3 text-muted-foreground">{i.category ?? "—"}</td>
                  <td className={cn("px-4 py-3", down.estimated && "text-[color:var(--warning)]")}>
                    {formatMinutes(down.minutes)}
                    {down.estimated && down.minutes !== null ? " *" : ""}
                  </td>
                  <td className="px-4 py-3">{formatMinutes(incidentMttd(i))}</td>
                  <td className="px-4 py-3">{formatMinutes(incidentMttr(i))}</td>
                  <td className="px-4 py-3">
                    <StatusBadge active={i.status === "active"} />
                  </td>
                </tr>
              );
            })}
            {rows.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-sm text-muted-foreground">
                  Nenhum incidente encontrado para os filtros selecionados.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-muted-foreground">* Downtime estimado a partir da detecção.</p>
    </div>
  );
}
