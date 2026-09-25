import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Activity, Loader2 } from "lucide-react";
import { useEffect, useState } from "react";

import { useAuth } from "@/integrations/supabase/AuthProvider";

export const Route = createFileRoute("/auth")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Entrar | Reliability Monitor" },
      {
        name: "description",
        content: "Acesso ao painel de confiabilidade das aplicações da Editora do Brasil.",
      },
      { property: "og:title", content: "Entrar | Reliability Monitor" },
      {
        property: "og:description",
        content: "Acesso ao painel de confiabilidade das aplicações da Editora do Brasil.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex, nofollow" },
    ],
  }),
  component: AuthPage,
});

function AuthPage() {
  const navigate = useNavigate();
  const { session, loading, signInWithMicrosoft } = useAuth();
  const [signingIn, setSigningIn] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && session) void navigate({ to: "/", replace: true });
  }, [loading, session, navigate]);

  const entrar = async () => {
    setErro(null);
    setSigningIn(true);
    try {
      await signInWithMicrosoft();
    } catch (error) {
      console.error("[Auth] Microsoft sign-in failed", error);
      setSigningIn(false);
      setErro("Não foi possível iniciar o acesso. Tente novamente.");
    }
  };

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="w-full max-w-md rounded-2xl border border-border bg-card p-8 shadow-sm">
        <div className="flex items-center gap-3">
          <span className="flex size-10 items-center justify-center rounded-xl bg-primary">
            <Activity className="size-5 text-primary-foreground" />
          </span>
          <div className="leading-tight">
            <p className="text-sm font-semibold text-foreground">Reliability Monitor</p>
            <p className="text-xs text-muted-foreground">Editora do Brasil</p>
          </div>
        </div>

        <h1 className="mt-8 text-2xl font-semibold tracking-tight text-foreground">
          Acesse o painel
        </h1>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          Entre com sua conta Microsoft para acompanhar incidentes e indicadores de confiabilidade.
        </p>

        {erro ? (
          <div
            role="alert"
            className="mt-6 rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive"
          >
            {erro}
          </div>
        ) : null}

        <button
          type="button"
          disabled={loading || signingIn}
          onClick={() => void entrar()}
          className="mt-8 inline-flex w-full items-center justify-center gap-2 rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:opacity-60"
        >
          {loading || signingIn ? <Loader2 className="size-4 animate-spin" /> : null}
          Entrar com Microsoft
        </button>
      </div>
    </main>
  );
}
