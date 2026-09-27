import { createFileRoute } from "@tanstack/react-router";
import { StatusBadge } from "@/components/StatusBadge";
import { useApplications, useIncidents } from "@/lib/queries";
import { computeMetrics, formatMinutes, resolveRange } from "@/lib/metrics";

export const Route = createFileRoute("/aplicacoes")({
  head: () => ({
    meta: [
      { title: "Aplicações | Reliability Monitor" },
      {
        name: "description",
        content: "Resumo de status, incidentes e indicadores por aplicação monitorada.",
      },
      { property: "og:title", content: "Aplicações | Reliability Monitor" },
      {
        property: "og:description",
        content: "Status e confiabilidade de cada aplicação da Editora do Brasil.",
      },
    ],
  }),
  component: ApplicationsPage,
});

function ApplicationsPage() {
  const { data: applications = [] } = useApplications();
  const { data: incidents = [] } = useIncidents();
  const range = resolveRange("30d");

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Aplicações</h1>
        <p className="text-sm text-muted-foreground">
          Indicadores consolidados dos últimos 30 dias. Cadastro e edição serão liberados em breve.
        </p>
      </header>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {applications.map((app) => {
          const list = incidents.filter(
            (i) =>
              i.application_id === app.id &&
              new Date(i.detected_at).getTime() >= range.from.getTime(),
          );
          const m = computeMetrics(list, range);
          const active = list.some((i) => i.status === "active");
          return (
            <div key={app.id} className="rounded-xl border border-border bg-card p-5">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <p className="text-base font-semibold">{app.name}</p>
                  <p className="text-xs text-muted-foreground">{app.description}</p>
                </div>
                <StatusBadge active={active} />
              </div>
              <dl className="mt-5 grid grid-cols-2 gap-4 text-sm">
                {[
                  ["Incidentes", String(m.count)],
                  ["Disponibilidade", `${m.availability.toFixed(2)}%`],
                  ["MTTD", formatMinutes(m.mttd)],
                  ["MTTR", formatMinutes(m.mttr)],
                  ["MTBF", formatMinutes(m.mtbf)],
                  ["Downtime", formatMinutes(m.downtime)],
                ].map(([label, value]) => (
                  <div key={label}>
                    <dt className="text-xs text-muted-foreground">{label}</dt>
                    <dd className="font-semibold">{value}</dd>
                  </div>
                ))}
              </dl>
              <p className="mt-4 text-xs text-muted-foreground">
                {app.is_active ? "Aplicação ativa" : "Aplicação inativa"}
              </p>
            </div>
          );
        })}
      </div>
    </div>
  );
}
