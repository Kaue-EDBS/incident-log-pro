import { createFileRoute } from "@tanstack/react-router";
import { ComingSoon } from "@/components/ComingSoon";
import { useViewer } from "@/lib/chameleon";

export const Route = createFileRoute("/analytics")({
  head: () => ({ meta: [{ title: "Analytics | Painel Safra" }] }),
  component: Analytics,
});

function Analytics() {
  const viewer = useViewer();
  const scope = viewer.isOwner && !viewer.canSeeAdmin ? "dos seus cards" : "de todos os cards";
  return (
    <ComingSoon
      title="Analytics"
      intro={`Números ${scope} na Safra corrente (D-88).`}
      allowed={viewer.canSeeAnalytics}
      items={[
        "Protocolos abertos, encerrados e cancelados por card",
        "Tempo do solicitante, do dono e consolidado (D-77)",
        "Tempo para perceber o problema: abertura menos o início informado (MTTD, D-89)",
        "Recorrência por card e por área",
        "Visão consolidada para Jair e Bruno",
      ]}
    />
  );
}
