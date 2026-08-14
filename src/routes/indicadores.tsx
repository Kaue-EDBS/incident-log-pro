import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip as ReTooltip,
  XAxis,
  YAxis,
} from "recharts";
import { useApplications, useIncidents } from "@/lib/queries";
import { computeMetrics, formatMinutes, resolveRange } from "@/lib/metrics";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/indicadores")({
  head: () => ({
    meta: [
      { title: "Indicadores | Reliability Monitor" },
      {
        name: "description",
        content: "Gráficos de incidentes, MTTR, MTTD e tabela comparativa de disponibilidade por aplicação.",
      },
      { property: "og:title", content: "Indicadores | Reliability Monitor" },
      { property: "og:description", content: "Compare a confiabilidade das aplicações monitoradas." },
    ],
  }),
  component: IndicatorsPage,
});

type SortKey = "name" | "count" | "mttd" | "mttr" | "mtbf" | "availability";

function IndicatorsPage() {
  const { data: applications = [] } = useApplications();
  const { data: incidents = [] } = useIncidents();
  const [sortKey, setSortKey] = useState<SortKey>("count");
  const [asc, setAsc] = useState(false);
  const range = useMemo(() => resolveRange("30d"), []);

  const rows = useMemo(
    () =>
      applications.map((app) => {
        const list = incidents.filter(
          (i) =>
            i.application_id === app.id &&
            new Date(i.detected_at).getTime() >= range.from.getTime(),
        );
        const m = computeMetrics(list, range);
        return { name: app.name, ...m };
      }),
    [applications, incidents, range],
  );

  const sorted = useMemo(() => {
    const copy = [...rows];
    copy.sort((a, b) => {
      const av = sortKey === "name" ? a.name : (a[sortKey] ?? -1);
      const bv = sortKey === "name" ? b.name : (b[sortKey] ?? -1);
      if (typeof av === "string" && typeof bv === "string") {
        return asc ? av.localeCompare(bv) : bv.localeCompare(av);
      }
      return asc ? Number(av) - Number(bv) : Number(bv) - Number(av);
    });
    return copy;
  }, [rows, sortKey, asc]);

  const overTime = useMemo(() => {
    const buckets = new Map<string, number>();
    for (let d = 29; d >= 0; d--) {
      const day = new Date(Date.now() - d * 864e5);
      buckets.set(day.toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit" }), 0);
    }
    for (const i of incidents) {
      const key = new Date(i.detected_at).toLocaleDateString("pt-BR", {
        day: "2-digit",
        month: "2-digit",
      });
      if (buckets.has(key)) buckets.set(key, (buckets.get(key) ?? 0) + 1);
    }
    return [...buckets.entries()].map(([date, total]) => ({ date, total }));
  }, [incidents]);

  const chartData = rows.map((r) => ({
    name: r.name,
    incidentes: r.count,
    mttr: r.mttr ? Math.round(r.mttr) : 0,
    mttd: r.mttd ? Math.round(r.mttd) : 0,
  }));

  const headers: { key: SortKey; label: string }[] = [
    { key: "name", label: "Aplicação" },
    { key: "count", label: "Incidentes" },
    { key: "mttd", label: "MTTD" },
    { key: "mttr", label: "MTTR" },
    { key: "mtbf", label: "MTBF" },
    { key: "availability", label: "Disponibilidade" },
  ];

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Indicadores</h1>
        <p className="text-sm text-muted-foreground">Comparativo dos últimos 30 dias.</p>
      </header>

      <div className="grid gap-4 lg:grid-cols-2">
        {[
          { title: "Incidentes por aplicação", key: "incidentes", color: "var(--primary)" },
          { title: "MTTR por aplicação (min)", key: "mttr", color: "var(--turquoise)" },
          { title: "MTTD por aplicação (min)", key: "mttd", color: "var(--accent)" },
        ].map((chart) => (
          <div key={chart.key} className="rounded-xl border border-border bg-card p-5">
            <p className="mb-4 text-sm font-semibold">{chart.title}</p>
            <div className="h-56">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
                  <XAxis dataKey="name" tickLine={false} axisLine={false} fontSize={12} />
                  <YAxis tickLine={false} axisLine={false} fontSize={12} width={36} />
                  <ReTooltip cursor={{ fill: "var(--muted)" }} />
                  <Bar dataKey={chart.key} fill={chart.color} radius={[6, 6, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        ))}

        <div className="rounded-xl border border-border bg-card p-5">
          <p className="mb-4 text-sm font-semibold">Incidentes ao longo do tempo</p>
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={overTime}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
                <XAxis dataKey="date" tickLine={false} axisLine={false} fontSize={11} interval={5} />
                <YAxis tickLine={false} axisLine={false} fontSize={12} width={36} allowDecimals={false} />
                <ReTooltip />
                <Line
                  type="monotone"
                  dataKey="total"
                  stroke="var(--primary)"
                  strokeWidth={2}
                  dot={false}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border bg-card">
        <table className="w-full min-w-[640px] text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs uppercase tracking-wide text-muted-foreground">
              {headers.map((h) => (
                <th key={h.key} className="px-4 py-3 font-medium">
                  <button
                    type="button"
                    onClick={() => {
                      if (sortKey === h.key) setAsc(!asc);
                      else {
                        setSortKey(h.key);
                        setAsc(false);
                      }
                    }}
                    className={cn("hover:text-foreground", sortKey === h.key && "text-foreground")}
                  >
                    {h.label} {sortKey === h.key ? (asc ? "↑" : "↓") : ""}
                  </button>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {sorted.map((r) => (
              <tr key={r.name} className="border-b border-border last:border-0">
                <td className="px-4 py-3 font-medium">{r.name}</td>
                <td className="px-4 py-3">{r.count}</td>
                <td className="px-4 py-3">{formatMinutes(r.mttd)}</td>
                <td className="px-4 py-3">{formatMinutes(r.mttr)}</td>
                <td className="px-4 py-3">{formatMinutes(r.mtbf)}</td>
                <td className="px-4 py-3">{r.availability.toFixed(2)}%</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
