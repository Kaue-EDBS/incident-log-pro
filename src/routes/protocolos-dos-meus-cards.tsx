import { createFileRoute } from "@tanstack/react-router";
import { TreatmentList } from "@/components/TreatmentList";
import { useViewer } from "@/lib/chameleon";
import { useAdminOwnerTreatments, useOwnerTreatments } from "@/lib/queries";

export const Route = createFileRoute("/protocolos-dos-meus-cards")({
  head: () => ({
    meta: [
      { title: "Protocolos dos meus cards | Painel Safra" },
      { name: "description", content: "Protocolos abertos nos cards de que você é dono." },
    ],
  }),
  component: OwnerProtocols,
});

function OwnerProtocols() {
  const viewer = useViewer();
  const preview = viewer.previewOwnerPrincipalId;
  const real = useOwnerTreatments(viewer.isOwner && preview === null);
  const previewed = useAdminOwnerTreatments(preview);
  const query = preview !== null ? previewed : real;

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Protocolos dos meus cards</h1>
        <p className="text-sm text-muted-foreground">
          Protocolos abertos por outras pessoas nos cards de que você é dono. Conclua a sua parte
          quando o problema estiver resolvido.
        </p>
      </header>
      {viewer.isOwner ? (
        <TreatmentList
          items={query.data ?? []}
          isLoading={query.isLoading}
          isError={query.isError}
          onRetry={() => void query.refetch()}
          emptyText="Nenhum protocolo aberto nos seus cards."
          showRequester
        />
      ) : (
        <p className="rounded-xl border border-dashed border-border bg-card p-6 text-sm text-muted-foreground">
          Esta área é para donos de card. Você não é dono de nenhum card.
        </p>
      )}
    </div>
  );
}
