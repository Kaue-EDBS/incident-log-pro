import { createFileRoute, Link } from "@tanstack/react-router";
import { Construction } from "lucide-react";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Visão Geral | Painel Safra" },
      {
        name: "description",
        content: "Visão geral do Painel Safra em construção.",
      },
      { property: "og:title", content: "Visão Geral | Painel Safra" },
      {
        property: "og:description",
        content: "Visão geral do Painel Safra em construção.",
      },
    ],
  }),
  component: Overview,
});

function Overview() {
  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Visão Geral</h1>
        <p className="text-sm text-muted-foreground">Painel Safra — Editora do Brasil.</p>
      </header>

      <section className="flex flex-col items-center gap-3 rounded-xl border border-dashed border-border bg-card px-6 py-12 text-center">
        <Construction className="size-8 text-[color:var(--warning)]" aria-hidden="true" />
        <p className="text-base font-semibold">Em obras</p>
        <p className="max-w-md text-sm text-muted-foreground">
          Esta tela está sendo reconstruída para o Painel Safra. Enquanto isso, você já pode abrir
          protocolos.
        </p>
        <Link
          to="/abrir-protocolo"
          className="mt-2 rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground"
        >
          Abrir protocolo
        </Link>
      </section>
    </div>
  );
}
