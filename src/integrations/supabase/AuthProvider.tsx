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
import { ensureSafraAccess } from "@/lib/safra-access.functions";

type AuthContextValue = {
  session: Session | null;
  user: User | null;
  loading: boolean;
  signInWithMicrosoft: () => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

function hasSafraClaim(session: Session | null) {
  return (
    (session?.user?.app_metadata as Record<string, unknown> | undefined)?.["safra_access"] === true
  );
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

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

  // Libera a permissão corporativa de leitura assim que a conta Microsoft entra.
  useEffect(() => {
    if (!session || hasSafraClaim(session)) return;
    let cancelled = false;

    void (async () => {
      try {
        const result = await ensureSafraAccess({ data: undefined });
        if (cancelled || !result.refreshed) return;
        await supabase.auth.refreshSession();
      } catch (error) {
        console.error("[Auth] Não foi possível liberar o acesso corporativo", error);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [session]);

  const signInWithMicrosoft = useCallback(async () => {
    const result = await lovable.auth.signInWithOAuth("microsoft", {
      redirect_uri: window.location.origin,
    });

    if (result.error) throw result.error;
  }, []);

  const signOut = useCallback(async () => {
    await supabase.auth.signOut({ scope: "local" });
    window.location.replace("/auth");
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
