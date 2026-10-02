import { createFileRoute } from "@tanstack/react-router";
import { ComingSoon } from "@/components/ComingSoon";
import { useViewer } from "@/lib/chameleon";

export const Route = createFileRoute("/administracao")({
  head: () => ({ meta: [{ title: "Administração | Painel Safra" }] }),
  component: Administration,
});

function Administration() {
  const viewer = useViewer();
  return (
    <ComingSoon
      title="Administração"
      intro="Ferramentas para cuidar do Painel e melhorar o app (D-88)."
      allowed={viewer.canSeeAdmin}
      items={[
        "Painel de cadastrados: pessoas, papéis e quem já entrou",
        "Trilha de auditoria de papéis e cadastros",
        "Onde as pessoas param nas telas, de forma anônima (D-90)",
        "Saúde do sistema: avisos enviados, erros e backups",
      ]}
    />
  );
}
