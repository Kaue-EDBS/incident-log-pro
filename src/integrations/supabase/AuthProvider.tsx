import type { Session, User } from "@supabase/supabase-js";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import { supabase } from "./client";
import { lovable } from "@/integrations/lovable/index";

type AccessState = "unknown" | "checking" | "granted" | "denied";

type AuthContextValue = {
  session: Session | null;
  user: User | null;
  loading: boolean;
  access: AccessState;
  accessReason: string | null;
  signInWithMicrosoft: () => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

function resolveAuthRedirectUrl() {
  const configured = import.meta.env["VITE_AUTH_REDIRECT_URL"];
  if (configured) return configured;

  if (typeof window !== "undefined") {
    return window.location.origin;
  }

  return undefined;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;

    void supabase.auth.getSession().then(({ data, error }) => {
      if (!mounted) return;

      if (error) {
        console.error("[Auth] Failed to restore Supabase session", error);
        setSession(null);
      } else {
        setSession(data.session);
      }
      setLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (!mounted) return;
      setSession(nextSession);
      setLoading(false);
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  const signInWithMicrosoft = useCallback(async () => {
    const redirectTo = resolveAuthRedirectUrl() ?? window.location.origin;

    const result = await lovable.auth.signInWithOAuth("microsoft", {
      redirect_uri: redirectTo,
    });

    if (result.error) throw result.error;
    if (result.redirected) return;
  }, []);

  const signOut = useCallback(async () => {
    const { error } = await supabase.auth.signOut({ scope: "local" });
    if (error) throw error;
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      user: session?.user ?? null,
      loading,
      signInWithMicrosoft,
      signOut,
    }),
    [loading, session, signInWithMicrosoft, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return value;
}

export function AuthGate({ children }: { children: ReactNode }) {
  const { loading, session, signInWithMicrosoft } = useAuth();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background px-4">
        <div className="text-center">
          <div className="mx-auto size-8 animate-spin rounded-full border-2 border-muted border-t-primary" />
          <p className="mt-4 text-sm text-muted-foreground">Validando sessão corporativa...</p>
        </div>
      </div>
    );
  }

  if (!session) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background px-4">
        <div className="w-full max-w-md rounded-2xl border border-border bg-card p-8 shadow-sm">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">
              Editora do Brasil
            </p>
            <h1 className="mt-3 text-2xl font-semibold tracking-tight text-foreground">
              Painel Safra
            </h1>
            <p className="mt-2 text-sm leading-6 text-muted-foreground">
              O acesso é exclusivo por identidade corporativa Microsoft. Não existe login local
              por senha neste produto.
            </p>
          </div>

          {errorMessage ? (
            <div
              role="alert"
              className="mt-6 rounded-lg border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive"
            >
              {errorMessage}
            </div>
          ) : null}

          <button
            type="button"
            className="mt-6 inline-flex w-full items-center justify-center rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
            onClick={() => {
              setErrorMessage(null);
              void signInWithMicrosoft().catch((error: unknown) => {
                console.error("[Auth] Microsoft sign-in failed", error);
                setErrorMessage(
                  "Não foi possível iniciar o login Microsoft. Confirme a configuração do Entra ID e do provider Azure no Auth.",
                );
              });
            }}
          >
            Entrar com Microsoft
          </button>

          <p className="mt-4 text-center text-xs text-muted-foreground">
            Autenticação: Microsoft Entra ID → Supabase/Lovable Auth.
          </p>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
