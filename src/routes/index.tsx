import { createFileRoute, Link } from "@tanstack/react-router";
import { ScenarioCatalog } from "@/components/ScenarioCatalog";
import { SeasonClosedNotice } from "@/components/SeasonPanel";
import { SituationBadge } from "@/components/TreatmentActions";
import { useViewer } from "@/lib/chameleon";
import { useMyTreatments } from "@/lib/queries";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Início | Painel Safra" },
      {
        name: "description",
        content: "Abra e acompanhe os protocolos da Safra da Editora do Brasil.",
      },
      { property: "og:title", content: "Início | Painel Safra" },
      {
        property: "og:description",
        content: "Abra e acompanhe os protocolos da Safra da Editora do Brasil.",
      },
    ],
  }),
  component: Home,
});

function MyOpenProtocols() {
  const { data = [] } = useMyTreatments();
  const { readOnly } = useViewer();
  const open = data.filter((item) => item.status === "ACTIVE");

  if (readOnly || open.length === 0) return null;

  return (
    <section
      aria-labelledby="my-open-title"
      className="rounded-xl border border-primary/30 bg-primary/5 p-4"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 id="my-open-title" className="text-sm font-semibold">
          Seus protocolos abertos ({open.length})
        </h2>
        <Link to="/meus-protocolos" className="text-sm font-medium text-primary underline">
          Ver todos
        </Link>
      </div>
      <ul className="mt-3 flex flex-wrap gap-2">
        {open.slice(0, 6).map((item) => (
          <li key={item.treatment_id}>
            <Link
              to="/meus-protocolos"
              className="inline-flex min-h-11 items-center gap-2 rounded-lg border border-border bg-card px-3 py-2 text-sm hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <span className="font-semibold">{item.protocol_number}</span>
              <SituationBadge situation={item.situation} />
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}

function Home() {
  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Painel Safra</h1>
        <p className="text-sm text-muted-foreground">
          Algo deu errado na operação? Escolha o card, explique o problema e abra o protocolo.
        </p>
      </header>
      <SeasonClosedNotice />
      <MyOpenProtocols />
      <ScenarioCatalog />
    </div>
  );
}
