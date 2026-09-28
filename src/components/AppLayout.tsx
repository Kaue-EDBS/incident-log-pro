import { Link } from "@tanstack/react-router";
import { Activity, PlusCircle } from "lucide-react";
import type { ReactNode } from "react";
import { useAuth } from "@/integrations/supabase/AuthProvider";

export function AppLayout({ children }: { children: ReactNode }) {
  const { user, signOut } = useAuth();

  return (
    <div className="min-h-screen bg-background">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 flex-col border-r border-sidebar-border bg-sidebar lg:flex">
        <div className="flex items-center gap-3 px-6 py-7">
          <span className="flex size-10 items-center justify-center rounded-xl bg-primary">
            <Activity className="size-5 text-primary-foreground" />
          </span>
          <div className="leading-tight">
            <p className="text-sm font-semibold text-sidebar-foreground">Painel Safra</p>
            <p className="text-xs text-muted-foreground">Editora do Brasil</p>
          </div>
        </div>

        <nav className="flex flex-1 flex-col px-3">
          <p className="px-3 pb-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-muted-foreground">
            Operação Safra
          </p>
          <Link
            to="/tratativas/nova"
            className="flex items-center gap-3 rounded-lg bg-sidebar-accent px-3 py-2.5 text-sm font-medium text-sidebar-accent-foreground transition-colors hover:bg-sidebar-accent"
          >
            <PlusCircle className="size-4" />
            Abrir Protocolo
          </Link>
        </nav>

        <div className="border-t border-sidebar-border px-4 py-4">
          <p className="truncate text-xs font-medium text-sidebar-foreground">
            {user?.email ?? "Usuário corporativo"}
          </p>
          <button
            type="button"
            className="mt-3 w-full rounded-lg border border-sidebar-border px-3 py-2 text-xs font-medium text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
            onClick={() => void signOut()}
          >
            Sair
          </button>
        </div>
      </aside>

      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-border bg-card px-4 py-3 lg:hidden">
        <div className="flex items-center gap-2">
          <span className="flex size-8 items-center justify-center rounded-lg bg-primary">
            <Activity className="size-4 text-primary-foreground" />
          </span>
          <div className="leading-tight">
            <span className="block text-sm font-semibold">Painel Safra</span>
            <span className="block text-[10px] uppercase tracking-wide text-muted-foreground">
              Operação Safra
            </span>
          </div>
        </div>
        <Link
          to="/tratativas/nova"
          className="rounded-lg bg-destructive px-3 py-1.5 text-xs font-semibold text-destructive-foreground"
        >
          Abrir protocolo
        </Link>
      </header>

      <main className="px-4 pb-16 pt-6 lg:ml-64 lg:px-10 lg:pt-10">{children}</main>
    </div>
  );
}
