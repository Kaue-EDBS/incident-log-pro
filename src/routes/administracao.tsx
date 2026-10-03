import { createFileRoute } from "@tanstack/react-router";
import { Activity, Loader2 } from "lucide-react";
import { SeasonPanel } from "@/components/SeasonPanel";
import { PeoplePanel, RbacTrailPanel, ScreenUsagePanel } from "@/components/AdminPanels";
import { NotificationsPanel } from "@/components/NotificationsPanel";
import { Button } from "@/components/ui/button";
import { CollapsibleSection } from "@/components/CollapsibleSection";
import { useViewer } from "@/lib/chameleon";
import { formatDateTime } from "@/lib/metrics";
import { useOpsSummary } from "@/lib/queries";

export const Route = createFileRoute("/administracao")({
  head: () => ({ meta: [{ title: "Administração | Painel Safra" }] }),
  component: Administration,
});

const KIND_LABEL: Record<string, string> = {
  CLIENT_ERROR: "Erros de tela",
  SLOW_RESPONSE: "Respostas lentas (≥ 2 s)",
  LOGIN_DENIED: "Logins recusados",
  ACTION_FAILED: "Falhas técnicas de ação",
};

function Stat({ label, value, hint }: { label: string; value: string | number; hint?: string }) {
  return (
    <div className="rounded-lg border border-border bg-background p-4">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 text-2xl font-semibold tabular-nums">{value}</p>
      {hint ? <p className="text-xs text-muted-foreground">{hint}</p> : null}
    </div>
  );
}

/** Saúde do sistema (D-95): o admin confere uma vez por dia na Safra até existirem alertas. */
function SystemHealth() {
  const { isPlatformAdmin } = useViewer();
  const { data, isLoading, isError, refetch } = useOpsSummary(isPlatformAdmin);

  if (!isPlatformAdmin) return null;

  return (
    <CollapsibleSection
      id="health-title"
      title="Saúde do sistema (últimas 24 h)"
      icon={<Activity className="size-5 text-primary" aria-hidden="true" />}
    >
      <div className="flex flex-wrap items-center justify-end gap-3">
        <Button variant="outline" onClick={() => void refetch()}>
          Atualizar
        </Button>
      </div>

      {isLoading ? (
        <p role="status" className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="size-4 animate-spin" aria-hidden="true" />
          Carregando...
        </p>
      ) : isError || !data ? (
        <p role="alert" className="text-sm text-destructive">
          Não foi possível carregar a saúde do sistema.
        </p>
      ) : (
        <>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Stat label="Protocolos abertos" value={data.protocols.opened} />
            <Stat
              label="Encerrados"
              value={data.protocols.resolved}
              hint={`${data.protocols.auto_resolved} automáticos em 72 h`}
            />
            <Stat
              label="Cancelados"
              value={data.protocols.cancelled}
              hint={`${data.protocols.auto_cancelled} automáticos em 72 h`}
            />
            <Stat label="Em andamento agora" value={data.protocols.active_now} />
          </div>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Stat label="Avisos na fila" value={data.notifications.queued} />
            <Stat label="Avisos enviados" value={data.notifications.sent} />
            <Stat label="Avisos com falha" value={data.notifications.failed} />
            <Stat label="Avisos expirados" value={data.notifications.expired} />
          </div>
          <p className="text-xs text-muted-foreground">
            Protocolo em andamento mais antigo:{" "}
            {data.protocols.oldest_active_opened_at
              ? formatDateTime(data.protocols.oldest_active_opened_at)
              : "nenhum"}
          </p>

          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {Object.entries(KIND_LABEL).map(([kind, label]) => (
              <Stat key={kind} label={label} value={data.events_by_kind[kind] ?? 0} />
            ))}
          </div>
          {data.slow_p95_ms !== null ? (
            <p className="text-xs text-muted-foreground">
              Entre as respostas lentas, 95% ficaram abaixo de {data.slow_p95_ms} ms.
            </p>
          ) : null}

          <div
            className="overflow-x-auto"
            tabIndex={0}
            role="region"
            aria-label="Tabela (role para os lados no celular)"
          >
            <table className="w-full min-w-[640px] text-left text-sm">
              <caption className="sr-only">Últimos registros técnicos</caption>
              <thead className="text-xs text-muted-foreground">
                <tr>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Quando
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Tipo
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Onde
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Código
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Tempo
                  </th>
                  <th scope="col" className="py-2 font-medium">
                    Usuário (código)
                  </th>
                </tr>
              </thead>
              <tbody>
                {data.recent.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-3 text-muted-foreground">
                      Nenhum registro técnico no período.
                    </td>
                  </tr>
                ) : (
                  data.recent.map((event) => (
                    <tr
                      key={`${event.occurred_at}-${event.code}`}
                      className="border-t border-border"
                    >
                      <td className="py-2 pr-3">{formatDateTime(event.occurred_at)}</td>
                      <td className="py-2 pr-3">{KIND_LABEL[event.kind] ?? event.kind}</td>
                      <td className="py-2 pr-3">{event.route ?? "—"}</td>
                      <td className="py-2 pr-3">{event.code ?? "—"}</td>
                      <td className="py-2 pr-3">
                        {event.duration_ms !== null ? `${event.duration_ms} ms` : "—"}
                      </td>
                      <td className="py-2 font-mono text-xs">
                        {event.actor_user_id ? event.actor_user_id.slice(0, 8) : "—"}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </>
      )}
    </CollapsibleSection>
  );
}

function Administration() {
  const viewer = useViewer();
  const summary = useOpsSummary(viewer.canSeeAdmin);
  const alerts = summary.data?.alerts ?? [];
  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Administração</h1>
        <p className="text-sm text-muted-foreground">
          Ferramentas para cuidar do Painel e melhorar o app.
        </p>
      </header>
      {!viewer.canSeeAdmin ? (
        <p className="rounded-xl border border-border bg-card p-6 text-sm text-muted-foreground">
          Você não tem acesso a esta área.
        </p>
      ) : (
        <>
          {alerts.length ? (
            <section
              role="alert"
              aria-labelledby="alerts-title"
              className="rounded-xl border-2 border-destructive bg-card p-5"
            >
              <h2 id="alerts-title" className="font-semibold text-destructive">
                Atenção: algo parou
              </h2>
              <ul className="mt-2 list-disc space-y-1 pl-5 text-sm">
                {alerts.map((alert) => (
                  <li key={alert.code}>{alert.text}</li>
                ))}
              </ul>
              <p className="mt-2 text-xs text-muted-foreground">
                O que fazer: docs/RUNBOOK_RECUPERACAO.md, seções 4.5 e 4.7.
              </p>
            </section>
          ) : null}
          <SeasonPanel />
          <NotificationsPanel />
          <SystemHealth />
          <PeoplePanel />
          <RbacTrailPanel />
          <ScreenUsagePanel />
        </>
      )}
    </div>
  );
}
