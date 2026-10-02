import { useMemo, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { TreatmentList } from "@/components/TreatmentList";
import { useViewer } from "@/lib/chameleon";
import { useAllTreatments, useSafraStartCatalog, type NowSummary } from "@/lib/queries";
import { formatDateTime } from "@/lib/metrics";
import { cardDisplayName, cardNumber } from "@/lib/safra";
import { CollapsibleSection } from "@/components/CollapsibleSection";

export const Route = createFileRoute("/todos-os-protocolos")({
  head: () => ({
    meta: [
      { title: "Todos os protocolos | Painel Safra" },
      { name: "description", content: "Protocolos de todos os cards, para a gestão da Safra." },
    ],
  }),
  component: AllProtocols,
});

const STATUS_OPTIONS = [
  { value: "", label: "Todas as situações" },
  { value: "ACTIVE", label: "Abertos agora (todas as etapas)" },
  { value: "RESOLVED", label: "Encerrados" },
  { value: "CANCELLED", label: "Cancelados" },
] as const;

function NowTile({ label, value, hint }: { label: string; value: number | string; hint?: string }) {
  return (
    <div className="rounded-lg border border-border bg-background p-3">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 text-2xl font-semibold tabular-nums">{value}</p>
      {hint ? <p className="text-xs text-muted-foreground">{hint}</p> : null}
    </div>
  );
}

/** Números do momento, de todos os cards (D-120: no lugar da Torre de Controle). */
function NowStrip({ summary }: { summary: NowSummary }) {
  return (
    <CollapsibleSection
      id="now-title"
      title={`Agora, em todos os cards: ${summary.active} abertos agora · ${summary.closing_within_24h} fecham sozinhos em 24 h`}
      className="space-y-3 p-4"
      titleClassName="text-sm"
    >
      <div className="grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
        <NowTile label="Abertos agora" value={summary.active} />
        <NowTile label="Ninguém concluiu" value={summary.nobody_closed} />
        <NowTile label="Aguardando o dono" value={summary.waiting_owner} />
        <NowTile label="Aguardando quem abriu" value={summary.waiting_requester} />
        <NowTile label="Fecham sozinhos em 24 h" value={summary.closing_within_24h} />
        <NowTile
          label="Mais antigo"
          value={summary.oldest_protocol_number ?? "—"}
          {...(summary.oldest_opened_at
            ? { hint: `aberto em ${formatDateTime(summary.oldest_opened_at)}` }
            : {})}
        />
      </div>
      <p className="text-xs text-muted-foreground">
        Hoje: {summary.opened_today} {summary.opened_today === 1 ? "aberto" : "abertos"} e{" "}
        {summary.closed_today} {summary.closed_today === 1 ? "encerrado" : "encerrados"}.
      </p>
    </CollapsibleSection>
  );
}

/** Visão da gestão (D-104): todos os protocolos, só leitura, com o histórico de cada um. */
function AllProtocols() {
  const viewer = useViewer();
  const [status, setStatus] = useState("");
  const [scenarioId, setScenarioId] = useState("");
  const catalog = useSafraStartCatalog();
  const query = useAllTreatments(viewer.canSeeAllProtocols, {
    status: status || null,
    scenarioId: scenarioId || null,
  });

  const cards = useMemo(
    () =>
      (catalog.data ?? [])
        .map((card) => ({
          id: card.scenario_id,
          label: `${cardNumber(card.code)} · ${cardDisplayName(card.name)}`,
        }))
        .sort((a, b) => a.label.localeCompare(b.label)),
    [catalog.data],
  );

  if (!viewer.canSeeAllProtocols) {
    return (
      <div className="mx-auto max-w-5xl">
        <p className="rounded-xl border border-dashed border-border bg-card p-6 text-sm text-muted-foreground">
          Esta área é para a gestão da Safra e para os administradores.
        </p>
      </div>
    );
  }

  const items = query.data?.items ?? [];
  const total = query.data?.total ?? 0;

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Todos os protocolos</h1>
        <p className="text-sm text-muted-foreground">
          Protocolos de todos os cards. Abra "Ver histórico" para ver o que aconteceu em cada um. Só
          quem abriu e o dono do card concluem ou cancelam.
        </p>
      </header>

      {query.data?.summary ? <NowStrip summary={query.data.summary} /> : null}

      <div className="flex flex-wrap items-end gap-4 rounded-xl border border-border bg-card p-4">
        <label className="flex flex-col gap-1 text-sm">
          <span className="font-medium">Situação</span>
          <select
            className="min-h-10 rounded-md border border-input bg-background px-3"
            value={status}
            onChange={(event) => setStatus(event.target.value)}
          >
            {STATUS_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="font-medium">Card</span>
          <select
            className="min-h-10 rounded-md border border-input bg-background px-3"
            value={scenarioId}
            onChange={(event) => setScenarioId(event.target.value)}
          >
            <option value="">Todos os cards</option>
            {cards.map((card) => (
              <option key={card.id} value={card.id}>
                {card.label}
              </option>
            ))}
          </select>
        </label>
        {query.data ? (
          <p role="status" className="ml-auto text-sm text-muted-foreground">
            {items.length < total
              ? `Mostrando os ${items.length} mais recentes de ${total} protocolos.`
              : `${total} ${total === 1 ? "protocolo" : "protocolos"}.`}
          </p>
        ) : null}
      </div>

      <TreatmentList
        items={items}
        isLoading={query.isLoading}
        isError={query.isError}
        onRetry={() => void query.refetch()}
        emptyText="Nenhum protocolo com esses filtros."
        showRequester
      />
    </div>
  );
}
