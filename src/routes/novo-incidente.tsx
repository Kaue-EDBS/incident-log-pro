import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { AlertTriangle, Siren } from "lucide-react";
import { toast } from "sonner";
import { StatusBadge } from "@/components/StatusBadge";
import { useApplications, useIncidents, useStartIncident } from "@/lib/queries";
import { INCIDENT_TYPES } from "@/lib/types";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/novo-incidente")({
  head: () => ({
    meta: [
      { title: "Novo Incidente | Reliability Monitor" },
      {
        name: "description",
        content: "Registre em segundos um novo incidente de indisponibilidade e inicie o cronômetro.",
      },
      { property: "og:title", content: "Novo Incidente | Reliability Monitor" },
      { property: "og:description", content: "Abertura rápida de incidentes com cronômetro persistente." },
    ],
  }),
  component: NewIncident,
});

function NewIncident() {
  const navigate = useNavigate();
  const { data: applications = [] } = useApplications();
  const { data: incidents = [] } = useIncidents();
  const startIncident = useStartIncident();

  const [applicationId, setApplicationId] = useState<string>("");
  const [type, setType] = useState<string>(INCIDENT_TYPES[0]);

  const existingActive = incidents.find(
    (i) => i.status === "active" && i.application_id === applicationId,
  );

  const handleStart = async () => {
    if (!applicationId) {
      toast.error("Selecione uma aplicação.");
      return;
    }
    try {
      const incident = await startIncident.mutateAsync({ application_id: applicationId, type });
      toast.success("Incidente iniciado. Cronômetro em andamento.");
      navigate({ to: "/incidentes/$id", params: { id: incident.id } });
    } catch {
      toast.error("Não foi possível iniciar o incidente.");
    }
  };

  return (
    <div className="mx-auto max-w-2xl space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Novo Incidente</h1>
        <p className="text-sm text-muted-foreground">
          Selecione a aplicação e o tipo para iniciar o registro imediatamente.
        </p>
      </header>

      <section className="space-y-3">
        <p className="text-sm font-medium">Aplicação</p>
        <div className="grid gap-3 sm:grid-cols-3">
          {applications.map((app) => {
            const active = incidents.some(
              (i) => i.status === "active" && i.application_id === app.id,
            );
            return (
              <button
                key={app.id}
                type="button"
                onClick={() => setApplicationId(app.id)}
                className={cn(
                  "rounded-xl border border-border bg-card p-4 text-left transition-all hover:border-[color:var(--turquoise)]",
                  applicationId === app.id && "border-primary ring-1 ring-primary",
                )}
              >
                <p className="font-semibold">{app.name}</p>
                <div className="mt-2">
                  <StatusBadge active={active} />
                </div>
              </button>
            );
          })}
        </div>
      </section>

      <section className="space-y-3">
        <p className="text-sm font-medium">Tipo de incidente</p>
        <div className="flex flex-wrap gap-2">
          {INCIDENT_TYPES.map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setType(t)}
              className={cn(
                "rounded-lg border border-border px-3 py-2 text-sm text-muted-foreground transition-colors hover:bg-muted",
                type === t && "border-primary bg-primary/5 text-foreground",
              )}
            >
              {t}
            </button>
          ))}
        </div>
      </section>

      {existingActive ? (
        <div className="flex flex-col gap-3 rounded-xl border border-[color:var(--warning)]/40 bg-[color:var(--warning)]/10 p-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-start gap-2">
            <AlertTriangle className="mt-0.5 size-4 text-[color:var(--warning)]" />
            <p className="text-sm">
              Esta aplicação já possui um incidente em andamento.
            </p>
          </div>
          <Link
            to="/incidentes/$id"
            params={{ id: existingActive.id }}
            className="rounded-lg bg-primary px-4 py-2 text-center text-sm font-semibold text-primary-foreground"
          >
            Abrir incidente existente
          </Link>
        </div>
      ) : (
        <button
          type="button"
          onClick={handleStart}
          disabled={startIncident.isPending}
          className="flex w-full items-center justify-center gap-3 rounded-xl bg-destructive px-6 py-6 text-lg font-bold uppercase tracking-wide text-destructive-foreground transition-transform hover:brightness-95 active:scale-[0.99] disabled:opacity-60"
        >
          <Siren className="size-6" />
          Iniciar incidente
        </button>
      )}
    </div>
  );
}
