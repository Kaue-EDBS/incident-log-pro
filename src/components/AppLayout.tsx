import { Link, useRouterState } from "@tanstack/react-router";
import { Activity, BarChart3, LayoutGrid, PlusCircle, Server, ShieldAlert } from "lucide-react";
import type { ReactNode } from "react";
import { useAuth } from "@/integrations/supabase/AuthProvider";
import { cn } from "@/lib/utils";

const SAFRA_NAV = [
  { to: "/tratativas/nova", label: "Abrir Protocolo", shortLabel: "Abrir", icon: PlusCircle },
] as const;

const LEGACY_TI_NAV = [
  { to: "/", label: "Visão Geral TI", shortLabel: "Visão TI", icon: LayoutGrid },
  { to: "/incidentes", label: "Incidentes TI", shortLabel: "Inc. TI", icon: ShieldAlert },
  { to: "/aplicacoes", label: "Aplicações TI", shortLabel: "Apps TI", icon: Server },
  { to: "/indicadores", label: "Indicadores TI", shortLabel: "Indic. TI", icon: BarChart3 },
] as const;

const MOBILE_NAV = [...SAFRA_NAV, ...LEGACY_TI_NAV] as const;

function isActive(pathname: string, to: string) {
  return to === "/" ? pathname === "/" : pathname.startsWith(to);
}

function NavLink({
  pathname,
  item,
}: {
  pathname: string;
  item: (typeof MOBILE_NAV)[number];
}) {
  return (
    <Link
      to={item.to}
      className={cn(
        "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
        isActive(pathname, item.to) && "bg-sidebar-accent text-sidebar-accent-foreground",
      )}
    >
      <item.icon className="size-4" />
      {item.label}
    </Link>
  );
}

export function AppLayout({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { user, signOut } = useAuth();
  const isLegacyTi = LEGACY_TI_NAV.some((item) => isActive(pathname, item.to));

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
          <div className="space-y-1">
            <p className="px-3 pb-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-muted-foreground">
              Safra
            </p>
            {SAFRA_NAV.map((item) => (
              <NavLink key={item.to} pathname={pathname} item={item} />
            ))}
          </div>

          <div className="my-4 border-t border-sidebar-border" />

          <div className="space-y-1">
            <div className="px-3 pb-1">
              <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-muted-foreground">
                Reliability / Legado TI
              </p>
              <p className="mt-1 text-[10px] leading-4 text-muted-foreground">
                Histórico técnico preservado até a migração das visões.
              </p>
            </div>
            {LEGACY_TI_NAV.map((item) => (
              <NavLink key={item.to} pathname={pathname} item={item} />
            ))}
          </div>
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
              {isLegacyTi ? "Reliability / Legado TI" : "Operação Safra"}
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

      <main className="px-4 pb-28 pt-6 lg:ml-64 lg:px-10 lg:pb-16 lg:pt-10">{children}</main>

      <nav className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-5 border-t border-border bg-card lg:hidden">
        {MOBILE_NAV.map((item) => {
          const isSafraItem = item.to === "/tratativas/nova";

          return (
            <Link
              key={item.to}
              to={item.to}
              className={cn(
                "flex flex-col items-center gap-1 py-2 text-[9px] font-medium text-muted-foreground",
                isSafraItem ? "bg-primary/5" : "bg-muted/30",
                isActive(pathname, item.to) && "text-primary",
              )}
            >
              <span className="text-[8px] font-semibold uppercase tracking-wide">
                {isSafraItem ? "Safra" : "TI"}
              </span>
              <item.icon className="size-4" />
              <span>{item.shortLabel}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
