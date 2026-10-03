import { createFileRoute } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useViewer } from "@/lib/chameleon";
import { formatDateTime } from "@/lib/metrics";
import {
  useReliabilityMetrics,
  type MetricPair,
  type ReliabilityRow,
  type Volume,
} from "@/lib/queries";
import { cardDisplayName, cardNumber } from "@/lib/safra";
import { CollapsibleSection } from "@/components/CollapsibleSection";

export const Route = createFileRoute("/analytics")({
  head: () => ({ meta: [{ title: "Indicadores | Painel Safra" }] }),
  component: Analytics,
});

/** Segundos em texto curto: "45 min", "2 h 15 min", "3 d 4 h". */
function formatDuration(seconds: number | null): string {
  if (seconds === null) return "—";
  const total = Math.max(0, Math.round(seconds / 60));
  const days = Math.floor(total / 1440);
  const hours = Math.floor((total % 1440) / 60);
  const minutes = total % 60;
  if (days > 0) return hours ? `${days} d ${hours} h` : `${days} d`;
  if (hours > 0) return minutes ? `${hours} h ${minutes} min` : `${hours} h`;
  return `${minutes} min`;
}

function Pair({ value }: { value: MetricPair }) {
  return (
    <>
      <span className="font-medium tabular-nums">{formatDuration(value.mean)}</span>
      <span className="block text-xs text-muted-foreground tabular-nums">
        mediana {formatDuration(value.median)}
      </span>
    </>
  );
}

function Row({ label, row, strong }: { label: string; row: ReliabilityRow; strong?: boolean }) {
  return (
    <tr className={strong ? "border-t-2 border-border bg-muted/40" : "border-t border-border"}>
      <th scope="row" className={`py-2 pr-3 text-left ${strong ? "font-semibold" : "font-normal"}`}>
        {label}
      </th>
      <td className="py-2 pr-3 tabular-nums">
        {row.failures}
        {row.protocols > row.failures ? (
          <span className="block text-xs text-muted-foreground">{row.protocols} protocolos</span>
        ) : null}
      </td>
      <td className="py-2 pr-3">
        <Pair value={row.mttd} />
      </td>
      <td className="py-2 pr-3">
        <Pair value={row.mttr} />
      </td>
      <td className="py-2 pr-3">
        <Pair value={row.mtbf} />
      </td>
      <td className="py-2">
        <Pair value={row.mttf} />
      </td>
    </tr>
  );
}

/** F04 (D-140): quantos protocolos e quanto tempo levaram, por card e no total. */
function VolumeSection({ volume, showTotal }: { volume: Volume; showTotal: boolean }) {
  const total = volume.consolidated;
  return (
    <CollapsibleSection
      id="volume-title"
      title={`Volume e tempos na Safra: ${total.opened} abertos · ${total.resolved} encerrados · ${total.cancelled} cancelados`}
      className="p-4"
      titleClassName="text-sm"
    >
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <VolumeTile label="Em andamento agora" value={String(total.active)} />
        <VolumeTile label="Tempo mediano para encerrar" value={formatDuration(total.median_secs)} />
        <VolumeTile
          label="Os 10% mais demorados passam de"
          value={formatDuration(total.p90_secs)}
        />
        <VolumeTile
          label="Pico de protocolos ao mesmo tempo"
          value={String(total.peak_simultaneous)}
        />
      </div>
      <div className="overflow-x-auto">
        <table className="w-full min-w-[640px] text-sm">
          <caption className="sr-only">Protocolos e tempos por card na Safra corrente</caption>
          <thead className="text-left text-xs text-muted-foreground">
            <tr>
              <th scope="col" className="py-2 pr-3 font-medium">
                Card
              </th>
              <th scope="col" className="py-2 pr-3 font-medium">
                Abertos
              </th>
              <th scope="col" className="py-2 pr-3 font-medium">
                Encerrados
              </th>
              <th scope="col" className="py-2 pr-3 font-medium">
                Cancelados
              </th>
              <th scope="col" className="py-2 pr-3 font-medium">
                Em andamento
              </th>
              <th scope="col" className="py-2 pr-3 font-medium">
                Tempo mediano
              </th>
              <th scope="col" className="py-2 font-medium">
                10% mais demorados
              </th>
            </tr>
          </thead>
          <tbody>
            {showTotal ? <VolumeRow label="Consolidado" row={total} strong /> : null}
            {volume.cards.map((card) => (
              <VolumeRow
                key={card.scenario_id}
                label={`${cardNumber(card.code)} · ${cardDisplayName(card.name)}`}
                row={card}
              />
            ))}
          </tbody>
        </table>
      </div>
      {volume.areas.length ? (
        <div>
          <h3 className="text-sm font-semibold">Áreas mais impactadas</h3>
          <ol aria-label="Áreas mais impactadas" className="mt-1 space-y-1 text-sm">
            {volume.areas.map((area, index) => (
              <li key={area.name} className="flex justify-between gap-3">
                <span>
                  {index + 1}º {area.name}
                </span>
                <span className="tabular-nums text-muted-foreground">
                  {area.protocols} {area.protocols === 1 ? "protocolo" : "protocolos"}
                </span>
              </li>
            ))}
          </ol>
        </div>
      ) : null}
      <p className="text-xs text-muted-foreground">
        Tempo = da abertura até a última parte concluir; só protocolos encerrados. Cancelados não
        contam no tempo.
      </p>
    </CollapsibleSection>
  );
}

function VolumeTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-border bg-background p-3">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 text-xl font-semibold tabular-nums">{value}</p>
    </div>
  );
}

function VolumeRow({
  label,
  row,
  strong,
}: {
  label: string;
  row: Volume["consolidated"] | Volume["cards"][number];
  strong?: boolean;
}) {
  return (
    <tr className={strong ? "border-t-2 border-border bg-muted/40" : "border-t border-border"}>
      <th scope="row" className={`py-2 pr-3 text-left ${strong ? "font-semibold" : "font-normal"}`}>
        {label}
      </th>
      <td className="py-2 pr-3 tabular-nums">{row.opened}</td>
      <td className="py-2 pr-3 tabular-nums">{row.resolved}</td>
      <td className="py-2 pr-3 tabular-nums">{row.cancelled}</td>
      <td className="py-2 pr-3 tabular-nums">{row.active}</td>
      <td className="py-2 pr-3 tabular-nums">{formatDuration(row.median_secs)}</td>
      <td className="py-2 tabular-nums">{formatDuration(row.p90_secs)}</td>
    </tr>
  );
}

const GLOSSARY = [
  ["MTTD", "tempo para perceber: do início do problema até a abertura do protocolo."],
  ["MTTR", "tempo para resolver: da abertura até a última parte concluir."],
  ["MTBF", "tempo entre falhas: do início de uma falha até o início da próxima no mesmo card."],
  ["MTTF", "tempo funcionando: do fim de uma falha até o início da próxima no mesmo card."],
] as const;

/** Cards que mais falham na Safra (D-122). */
function Ranking({
  cards,
}: {
  cards: Array<ReliabilityRow & { code: string; name: string; scenario_id: string }>;
}) {
  const top = [...cards]
    .filter((card) => card.failures > 0)
    .sort((a, b) => b.failures - a.failures || (b.mttr.mean ?? 0) - (a.mttr.mean ?? 0))
    .slice(0, 5);
  return (
    <CollapsibleSection
      id="ranking-title"
      title={
        top[0]
          ? `Cards que mais falham na Safra: 1º ${top[0].code} · ${top[0].name} (${top[0].failures})`
          : "Cards que mais falham na Safra"
      }
      className="p-4"
      titleClassName="text-sm"
    >
      {top.length === 0 ? (
        <p className="mt-2 text-sm text-muted-foreground">Nenhuma falha registrada ainda.</p>
      ) : (
        <ol aria-label="Ranking de falhas" className="mt-2 space-y-1 text-sm">
          {top.map((card, index) => (
            <li key={card.scenario_id} className="flex justify-between gap-3">
              <span>
                {index + 1}. {cardNumber(card.code)} · {cardDisplayName(card.name)}
              </span>
              <span className="tabular-nums text-muted-foreground">
                {card.failures} {card.failures === 1 ? "falha" : "falhas"} · MTTR{" "}
                {formatDuration(card.mttr.mean)}
              </span>
            </li>
          ))}
        </ol>
      )}
    </CollapsibleSection>
  );
}

/** Indicadores da Safra corrente (D-88, D-117). */
function Analytics() {
  const viewer = useViewer();
  const query = useReliabilityMetrics(viewer.canSeeAnalytics, viewer.previewOwnerPrincipalId);

  if (!viewer.canSeeAnalytics) {
    return (
      <div className="mx-auto max-w-5xl">
        <p className="rounded-xl border border-dashed border-border bg-card p-6 text-sm text-muted-foreground">
          Esta área é para donos de card, para a gestão da Safra e para os administradores.
        </p>
      </div>
    );
  }

  const data = query.data;

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Indicadores</h1>
        <p className="text-sm text-muted-foreground">
          {data?.scope === "ALL" ? "Todos os cards" : "Os seus cards"} na Safra corrente
          {data ? `, desde ${formatDateTime(data.season_start)}` : ""}. Conta só protocolo
          encerrado; protocolos do mesmo card abertos ao mesmo tempo contam como uma falha.
        </p>
      </header>

      {query.isLoading ? (
        <p role="status" className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="size-4 animate-spin" aria-hidden="true" />
          Calculando...
        </p>
      ) : query.isError || !data ? (
        <div role="alert" className="rounded-xl border border-destructive/30 bg-destructive/10 p-5">
          <p className="font-medium text-destructive">Não foi possível carregar os indicadores.</p>
          <Button variant="outline" className="mt-3" onClick={() => void query.refetch()}>
            Tentar de novo
          </Button>
        </div>
      ) : (
        <>
          <Ranking cards={data.cards} />
          {data.volume ? (
            <VolumeSection volume={data.volume} showTotal={data.scope === "ALL"} />
          ) : null}

          <div className="overflow-x-auto rounded-xl border border-border bg-card p-4">
            <table className="w-full min-w-[720px] text-sm">
              <caption className="sr-only">Indicadores por card: média e mediana</caption>
              <thead className="text-left text-xs text-muted-foreground">
                <tr>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Card
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Falhas
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Tempo para perceber (MTTD)
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Tempo para resolver (MTTR)
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Tempo entre falhas (MTBF)
                  </th>
                  <th scope="col" className="py-2 font-medium">
                    Tempo funcionando (MTTF)
                  </th>
                </tr>
              </thead>
              <tbody>
                {data.scope === "ALL" ? (
                  <Row label="Consolidado" row={data.consolidated} strong />
                ) : null}
                {data.cards.map((card) => (
                  <Row
                    key={card.scenario_id}
                    label={`${cardNumber(card.code)} · ${cardDisplayName(card.name)}`}
                    row={card}
                  />
                ))}
              </tbody>
            </table>
          </div>

          <dl className="grid gap-2 text-xs text-muted-foreground sm:grid-cols-2">
            {GLOSSARY.map(([term, text]) => (
              <div key={term}>
                <dt className="inline font-semibold text-foreground">{term}: </dt>
                <dd className="inline">{text}</dd>
              </div>
            ))}
          </dl>
          <p className="text-xs text-muted-foreground">
            Cada valor mostra a média e, embaixo, a mediana (o valor do meio, que não se deixa levar
            por um caso fora da curva). "—" quando ainda não há falhas suficientes.
            {data.excluded > 0
              ? ` ${data.excluded} ${data.excluded === 1 ? "protocolo de demonstração ficou" : "protocolos de demonstração ficaram"} fora da conta.`
              : ""}
          </p>
        </>
      )}
    </div>
  );
}
