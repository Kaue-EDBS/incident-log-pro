import { createFileRoute } from "@tanstack/react-router";
import { TreatmentList } from "@/components/TreatmentList";
import { useMyTreatments } from "@/lib/queries";

export const Route = createFileRoute("/meus-protocolos")({
  head: () => ({
    meta: [
      { title: "Meus protocolos | Painel Safra" },
      { name: "description", content: "Protocolos que você abriu na Safra." },
    ],
  }),
  component: MyProtocols,
});

function MyProtocols() {
  const { data = [], isLoading, isError, refetch } = useMyTreatments();

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Meus protocolos</h1>
        <p className="text-sm text-muted-foreground">
          Os protocolos que você abriu. Quando o problema estiver resolvido do seu lado, toque em
          Concluído; o dono do card confirma a parte dele.
        </p>
      </header>
      <TreatmentList
        items={data}
        isLoading={isLoading}
        isError={isError}
        onRetry={() => void refetch()}
        emptyText="Você ainda não abriu nenhum protocolo."
      />
    </div>
  );
}
