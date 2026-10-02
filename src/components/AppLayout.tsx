import { Link, useRouterState } from "@tanstack/react-router";
import { Activity, ClipboardList, Inbox, LayoutGrid } from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/integrations/supabase/AuthProvider";
import { useMySafraRoles } from "@/lib/queries";

const BASE_NAV = [
  { to: "/", label: "Início", short: "Início", icon: LayoutGrid },
  { to: "/meus-protocolos", label: "Meus protocolos", short: "Meus", icon: ClipboardList },
] as const;

const OWNER_NAV = {
  to: "/protocolos-dos-meus-cards",
  label: "Protocolos dos meus cards",
  short: "Meus cards",
  icon: Inbox,
} as const;

function isActive(pathname: string, to: string) {
  return to === "/" ? pathname === "/" : pathname.startsWith(to);
}

export function AppLayout({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { user, signOut } = useAuth();
  const roles = useMySafraRoles();
  // Só define o que aparece no menu; a permissão é sempre conferida no banco.
  const nav = roles.data?.includes("scenario_owner") ? [...BASE_NAV, OWNER_NAV] : [...BASE_NAV];

  return (
    <div className="min-h-screen bg-background">
      <a
        href="#conteudo"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-card focus:px-4 focus:py-2 focus:shadow"
      >
        Pular para o conteúdo
      </a>
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 flex-col border-r border-sidebar-border bg-sidebar lg:flex">
        <div className="flex items-center gap-3 px-6 py-7">
          <span className="flex size-10 items-center justify-center rounded-xl bg-primary">
            <Activity className="size-5 text-primary-foreground" aria-hidden="true" />
          </span>
          <div className="leading-tight">
            <p className="text-sm font-semibold text-sidebar-foreground">Painel Safra</p>
            <p className="text-xs text-muted-foreground">Editora do Brasil</p>
          </div>
        </div>
        <nav aria-label="Principal" className="flex flex-1 flex-col gap-1 px-3">
          {nav.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              aria-current={isActive(pathname, item.to) ? "page" : undefined}
              className={cn(
                "flex min-h-11 items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
                isActive(pathname, item.to) && "bg-sidebar-accent text-sidebar-accent-foreground",
              )}
            >
              <item.icon className="size-4" aria-hidden="true" />
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="border-t border-sidebar-border px-4 py-4">
          <p className="truncate text-xs font-medium text-sidebar-foreground">
            {user?.email ?? "Usuário corporativo"}
          </p>
          <button
            type="button"
            className="mt-3 min-h-11 w-full rounded-lg border border-sidebar-border px-3 py-2 text-xs font-medium text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
            onClick={() => void signOut()}
          >
            Sair
          </button>
        </div>
      </aside>

      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-border bg-card px-4 py-3 lg:hidden">
        <div className="flex items-center gap-2">
          <span className="flex size-8 items-center justify-center rounded-lg bg-primary">
            <Activity className="size-4 text-primary-foreground" aria-hidden="true" />
          </span>
          <span className="text-sm font-semibold">Painel Safra</span>
        </div>
        <button
          type="button"
          className="min-h-11 rounded-lg border border-border px-3 text-xs font-medium"
          onClick={() => void signOut()}
        >
          Sair
        </button>
      </header>

      <main id="conteudo" className="px-4 pb-28 pt-6 lg:ml-64 lg:px-10 lg:pb-16 lg:pt-10">
        {children}
      </main>

      <nav
        aria-label="Principal"
        className={cn(
          "fixed inset-x-0 bottom-0 z-30 grid border-t border-border bg-card lg:hidden",
          nav.length === 3 ? "grid-cols-3" : "grid-cols-2",
        )}
      >
        {nav.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            aria-current={isActive(pathname, item.to) ? "page" : undefined}
            className={cn(
              "flex min-h-14 flex-col items-center justify-center gap-1 py-2 text-xs font-medium text-muted-foreground",
              isActive(pathname, item.to) && "text-primary",
            )}
          >
            <item.icon className="size-4" aria-hidden="true" />
            {item.short}
          </Link>
        ))}
      </nav>
    </div>
  );
}
