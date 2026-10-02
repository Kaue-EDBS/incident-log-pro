import { createFileRoute, redirect } from "@tanstack/react-router";

// D-81: a abertura acontece no próprio card, na página inicial. A rota antiga
// continua existindo só para não quebrar links já compartilhados.
export const Route = createFileRoute("/abrir-protocolo")({
  beforeLoad: () => {
    throw redirect({ to: "/", replace: true });
  },
});
