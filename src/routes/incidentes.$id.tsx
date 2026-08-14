import { createFileRoute, Link, useRouter } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { CheckCircle2, ChevronLeft, Clock3 } from "lucide-react";
import { toast } from "sonner";
import { LiveTimer } from "@/components/LiveTimer";
import { StatusBadge } from "@/components/StatusBadge";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { useApplications, useIncident, useUpdateIncident } from "@/lib/queries";
import {
  formatDateTime,
  formatMinutes,
  incidentDowntime,
  incidentMttd,
  incidentMttr,
  toLocalInput,
} from "@/lib/metrics";
import { INCIDENT_TYPES } from "@/lib/types";

export const Route = createFileRoute("/incidentes/$id")({
  head: () => ({
    meta: [
      { title: "Detalhes do Incidente | Reliability Monitor" },
      {
        name: "description",
        content: "Cronômetro, linha do tempo e indicadores detalhados do incidente registrado.",
      },
      { property: "og:title", content: "Detalhes do Incidente | Reliability Monitor" },
      { property: "og:description", content: "Acompanhe e finalize o incidente com todos os timestamps." },
    ],
  }),
  component: IncidentDetail,
});

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block space-y-1.5">
      <span className="text-xs font-medium text-muted-foreground">{label}</span>
      {children}
    </label>
  );
}

function IncidentDetail() {
  const { id } = Route.useParams();
  const router = useRouter();
  const { data: incident, isLoading } = useIncident(id);
  const { data: applications = [] } = useApplications();
  const update = useUpdateIncident();

  const [failureStartedAt, setFailureStartedAt] = useState("");
  const [responseStartedAt, setResponseStartedAt] = useState("");
  const [responsible, setResponsible] = useState("");
  const [notes, setNotes] = useState("");
  const [category, setCategory] = useState("");
  const [cause, setCause] = useState("");
  const [resolution, setResolution] = useState("");

  useEffect(() => {
    if (!incident) return;
    setFailureStartedAt(toLocalInput(incident.failure_started_at));
    setResponseStartedAt(toLocalInput(incident.response_started_at));
    setResponsible(incident.responsible ?? "");
    setNotes(incident.notes ?? "");
    setCategory(incident.category ?? incident.type ?? "");
    setCause(incident.cause ?? "");
    setResolution(incident.resolution ?? "");
  }, [incident]);

  if (isLoading || !incident) {
    return <p className="text-sm text-muted-foreground">Carregando incidente...</p>;
  }

  const app = applications.find((a) => a.id === incident.application_id);
  const isActive = incident.status === "active";
  const downtime = incidentDowntime(incident);

  const toIso = (local: string) => (local ? new Date(local).toISOString() : null);

  const handleRecover = async () => {
    try {
      await update.mutateAsync({
        id: incident.id,
        values: {
          failure_started_at: toIso(failureStartedAt),
          response_started_at: toIso(responseStartedAt),
          responsible: responsible || null,
          notes: notes || null,
          recovered_at: new Date().toISOString(),
          status: "resolved",
        },
      });
      toast.success("Aplicação recuperada. Complete a finalização.");
      router.invalidate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Não foi possível encerrar o incidente.");
    }
  };

  const handleSaveProgress = async () => {
    try {
      await update.mutateAsync({
        id: incident.id,
        values: {
          failure_started_at: toIso(failureStartedAt),
          response_started_at: toIso(responseStartedAt),
          responsible: responsible || null,
          notes: notes || null,
        },
      });
      toast.success("Dados atualizados.");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Não foi possível salvar.");
    }
  };

  const handleSaveFinal = async () => {
    try {
      await update.mutateAsync({
        id: incident.id,
        values: {
          failure_started_at: toIso(failureStartedAt),
          response_started_at: toIso(responseStartedAt),
          responsible: responsible || null,
          category: category || null,
          cause: cause || null,
          resolution: resolution || null,
          notes: notes || null,
        },
      });
      toast.success("Incidente salvo.");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Não foi possível salvar.");
    }
  };

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <Link to="/incidentes" className="inline-flex items-center gap-1 text-sm text-muted-foreground">
        <ChevronLeft className="size-4" /> Voltar ao histórico
      </Link>

      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">{app?.name ?? "Incidente"}</h1>
          <p className="text-sm text-muted-foreground">{incident.type ?? "Incidente"}</p>
        </div>
        <StatusBadge active={isActive} />
      </header>

      {isActive ? (
        <div className="pulse-incident rounded-2xl border border-destructive/30 bg-destructive/5 px-6 py-8 text-center">
          <p className="text-xs font-semibold uppercase tracking-widest text-destructive">
            Tempo desde a detecção
          </p>
          <LiveTimer
            since={incident.detected_at}
            className="mt-2 block text-5xl font-bold text-destructive sm:text-6xl"
          />
          <p className="mt-2 text-xs text-muted-foreground">
            Detectado em {formatDateTime(incident.detected_at)}
          </p>
        </div>
      ) : null}

      <section className="grid gap-4 rounded-xl border border-border bg-card p-5 sm:grid-cols-2">
        <Field label="Início da falha (failure_started_at)">
          <Input
            type="datetime-local"
            value={failureStartedAt}
            onChange={(e) => setFailureStartedAt(e.target.value)}
          />
        </Field>
        <Field label="Início da atuação (response_started_at)">
          <div className="flex gap-2">
            <Input
              type="datetime-local"
              value={responseStartedAt}
              onChange={(e) => setResponseStartedAt(e.target.value)}
            />
            <button
              type="button"
              onClick={() => setResponseStartedAt(toLocalInput(new Date().toISOString()))}
              className="shrink-0 rounded-lg border border-border px-3 text-xs font-medium text-muted-foreground hover:bg-muted"
            >
              Usar horário atual
            </button>
          </div>
        </Field>
        <Field label="Responsável">
          <Input value={responsible} onChange={(e) => setResponsible(e.target.value)} placeholder="Nome do responsável" />
        </Field>
        <Field label="Observações">
          <Textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={2} />
        </Field>
      </section>

      {isActive ? (
        <div className="space-y-3">
          <button
            type="button"
            onClick={handleRecover}
            disabled={update.isPending}
            className="flex w-full items-center justify-center gap-3 rounded-xl bg-[color:var(--success)] px-6 py-6 text-lg font-bold uppercase tracking-wide text-[color:var(--success-foreground)] transition-transform hover:brightness-95 active:scale-[0.99] disabled:opacity-60"
          >
            <CheckCircle2 className="size-6" />
            Aplicação recuperada
          </button>
          <button
            type="button"
            onClick={handleSaveProgress}
            className="w-full rounded-lg border border-border py-2.5 text-sm font-medium text-muted-foreground hover:bg-muted"
          >
            Salvar dados parciais
          </button>
        </div>
      ) : (
        <>
          <section className="rounded-xl border border-border bg-card p-5">
            <h2 className="text-sm font-semibold">Resumo</h2>
            <dl className="mt-4 grid gap-4 sm:grid-cols-3">
              {[
                ["Início da falha", formatDateTime(incident.failure_started_at)],
                ["Detecção", formatDateTime(incident.detected_at)],
                ["Recuperação", formatDateTime(incident.recovered_at)],
                [
                  "Downtime",
                  `${formatMinutes(downtime.minutes)}${downtime.estimated ? " (estimado)" : ""}`,
                ],
                ["Tempo para detecção (MTTD)", formatMinutes(incidentMttd(incident))],
                ["Tempo para recuperação (MTTR)", formatMinutes(incidentMttr(incident))],
              ].map(([label, value]) => (
                <div key={label}>
                  <dt className="text-xs text-muted-foreground">{label}</dt>
                  <dd className="text-sm font-semibold">{value}</dd>
                </div>
              ))}
            </dl>
          </section>

          <section className="space-y-4 rounded-xl border border-border bg-card p-5">
            <h2 className="text-sm font-semibold">Finalização</h2>
            <Field label="Categoria">
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="h-10 w-full rounded-lg border border-border bg-background px-3 text-sm"
              >
                <option value="">Selecione</option>
                {INCIDENT_TYPES.map((t) => (
                  <option key={t} value={t}>
                    {t}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Causa">
              <Textarea value={cause} onChange={(e) => setCause(e.target.value)} rows={2} />
            </Field>
            <Field label="Solução aplicada">
              <Textarea value={resolution} onChange={(e) => setResolution(e.target.value)} rows={2} />
            </Field>
            <button
              type="button"
              onClick={handleSaveFinal}
              disabled={update.isPending}
              className="w-full rounded-lg bg-primary py-3 text-sm font-semibold text-primary-foreground hover:brightness-110 disabled:opacity-60"
            >
              Salvar incidente
            </button>
          </section>

          <section className="rounded-xl border border-border bg-card p-5">
            <h2 className="mb-4 text-sm font-semibold">Linha do tempo</h2>
            <ol className="space-y-4">
              {[
                { label: "Falha iniciada", value: incident.failure_started_at, extra: null },
                {
                  label: "Falha detectada",
                  value: incident.detected_at,
                  extra: `MTTD ${formatMinutes(incidentMttd(incident))}`,
                },
                { label: "Atuação iniciada", value: incident.response_started_at, extra: null },
                {
                  label: "Aplicação recuperada",
                  value: incident.recovered_at,
                  extra: `MTTR ${formatMinutes(incidentMttr(incident))}`,
                },
              ].map((step) => (
                <li key={step.label} className="flex gap-3">
                  <span className="mt-1 flex size-6 shrink-0 items-center justify-center rounded-full bg-secondary/20">
                    <Clock3 className="size-3.5 text-primary" />
                  </span>
                  <div>
                    <p className="text-sm font-medium">{step.label}</p>
                    <p className="text-xs text-muted-foreground">
                      {formatDateTime(step.value)}
                      {step.extra ? ` · ${step.extra}` : ""}
                    </p>
                  </div>
                </li>
              ))}
            </ol>
            <dl className="mt-6 grid gap-4 border-t border-border pt-4 sm:grid-cols-2">
              {[
                ["Responsável", incident.responsible ?? "—"],
                ["Categoria", incident.category ?? "—"],
                ["Causa", incident.cause ?? "—"],
                ["Solução", incident.resolution ?? "—"],
                ["Observações", incident.notes ?? "—"],
              ].map(([label, value]) => (
                <div key={label}>
                  <dt className="text-xs text-muted-foreground">{label}</dt>
                  <dd className="text-sm">{value}</dd>
                </div>
              ))}
            </dl>
          </section>
        </>
      )}
    </div>
  );
}
