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
import { logOpsEvent } from "@/lib/ops";

type AuthContextValue = {
  session: Session | null;
  user: User | null;
  loading: boolean;
  corporateAuthorized: boolean | null;
  authorizationError: string | null;
  signInWithMicrosoft: () => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

// SAFRA-C04: a autorização vem exclusivamente do banco
// (private.safra_principals + private.safra_role_grants).
// Nenhum metadado do usuário é fonte de autorização.

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [authorizationLoading, setAuthorizationLoading] = useState(false);
  const [corporateAuthorized, setCorporateAuthorized] = useState<boolean | null>(null);
  const [authorizationError, setAuthorizationError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;

    void supabase.auth.getSession().then(({ data }) => {
      if (!mounted) return;
      setSession(data.session);
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

  // Confere o acesso corporativo quando a pessoa logada muda. Voltar para a aba ou renovar o
  // token gera um objeto de sessão novo para a mesma pessoa: isso não pode desmontar o Painel
  // (o texto que a pessoa digitava sumia). O banco confere de novo em toda chamada.
  const sessionUserId = session?.user?.id ?? null;
  useEffect(() => {
    let cancelled = false;

    if (!sessionUserId) {
      setCorporateAuthorized(null);
      setAuthorizationError(null);
      setAuthorizationLoading(false);
      return () => {
        cancelled = true;
      };
    }

    setAuthorizationLoading(true);
    setCorporateAuthorized(null);
    setAuthorizationError(null);

    void (async () => {
      try {
        const { data, error } = await supabase.rpc("safra_is_corporate_user");
        if (cancelled) return;

        if (error) {
          logOpsEvent("ACTION_FAILED", "safra_is_corporate_user", {
            detail: { error: String(error.code ?? "UNKNOWN") },
          });
          setCorporateAuthorized(false);
          setAuthorizationError(
            "Não foi possível confirmar seu acesso agora. Verifique a conexão e tente novamente.",
          );
          return;
        }

        if (data !== true) {
          logOpsEvent("LOGIN_DENIED", "NOT_CORPORATE");
          setCorporateAuthorized(false);
          setAuthorizationError(
            "Acesso permitido somente para contas Microsoft corporativas da Editora do Brasil.",
          );
          return;
        }

        setCorporateAuthorized(true);
      } finally {
        if (!cancelled) setAuthorizationLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [sessionUserId]);

  const signInWithMicrosoft = useCallback(async () => {
    const result = await lovable.auth.signInWithOAuth("microsoft", {
      redirect_uri: window.location.origin,
    });

    if (result.error) throw result.error;
  }, []);

  // Encerramento global: remove a sessão em auth.sessions, para que o token
  // em cache no navegador deixe de ser aceito imediatamente (ID-002).
  const signOut = useCallback(async () => {
    await supabase.auth.signOut({ scope: "global" });
    window.location.replace("/auth");
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      user: session?.user ?? null,
      loading: loading || authorizationLoading,
      corporateAuthorized,
      authorizationError,
      signInWithMicrosoft,
      signOut,
    }),
    [
      authorizationError,
      authorizationLoading,
      corporateAuthorized,
      loading,
      session,
      signInWithMicrosoft,
      signOut,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// AuthProvider intentionally co-exports its hook; keep this exception local.
// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return value;
}
