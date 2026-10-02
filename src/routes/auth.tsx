import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";
import { BrandMark } from "@/components/BrandMark";
import { useEffect, useState } from "react";

import { useAuth } from "@/integrations/supabase/AuthProvider";

export const Route = createFileRoute("/auth")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Entrar | Painel Safra" },
      {
        name: "description",
        content: "Acesso ao Painel Safra da Editora do Brasil.",
      },
      { property: "og:title", content: "Entrar | Painel Safra" },
      {
        property: "og:description",
        content: "Acesso ao Painel Safra da Editora do Brasil.",
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
  const {
    session,
    loading,
    corporateAuthorized,
    authorizationError,
    signInWithMicrosoft,
    signOut,
  } = useAuth();
  const [signingIn, setSigningIn] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && session && corporateAuthorized === true) {
      void navigate({ to: "/", replace: true });
    }
  }, [corporateAuthorized, loading, session, navigate]);

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
          <BrandMark className="h-10" />
          <div className="leading-tight">
            <p className="text-sm font-semibold text-foreground">Painel Safra</p>
            <p className="text-xs text-muted-foreground">Editora do Brasil</p>
          </div>
        </div>

        <h1 className="mt-8 text-2xl font-semibold tracking-tight text-foreground">
          Acesse o painel
        </h1>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          Entre com sua conta Microsoft para abrir e acompanhar protocolos operacionais da Safra.
        </p>

        {erro || authorizationError ? (
          <div
            role="alert"
            className="mt-6 rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive"
          >
            {erro ?? authorizationError}
          </div>
        ) : null}

        {session && corporateAuthorized === false ? (
          <button
            type="button"
            disabled={loading}
            onClick={() => void signOut()}
            className="mt-8 inline-flex w-full items-center justify-center gap-2 rounded-lg border border-border bg-background px-4 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-muted focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:opacity-60"
          >
            Sair e usar outra conta
          </button>
        ) : (
          <button
            type="button"
            disabled={loading || signingIn}
            onClick={() => void entrar()}
            className="mt-8 inline-flex w-full items-center justify-center gap-2 rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:opacity-60"
          >
            {loading || signingIn ? <Loader2 className="size-4 animate-spin" /> : null}
            Entrar com Microsoft
          </button>
        )}
      </div>
    </main>
  );
}
