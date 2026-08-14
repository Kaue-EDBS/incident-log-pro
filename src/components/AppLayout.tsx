import { Link, useRouterState } from "@tanstack/react-router";
import { Activity, BarChart3, LayoutGrid, PlusCircle, Server, ShieldAlert } from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

const NAV = [
  { to: "/", label: "Visão Geral", icon: LayoutGrid },
  { to: "/novo-incidente", label: "Novo Incidente", icon: PlusCircle },
  { to: "/incidentes", label: "Incidentes", icon: ShieldAlert },
  { to: "/aplicacoes", label: "Aplicações", icon: Server },
  { to: "/indicadores", label: "Indicadores", icon: BarChart3 },
] as const;

function isActive(pathname: string, to: string) {
  return to === "/" ? pathname === "/" : pathname.startsWith(to);
}

export function AppLayout({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <div className="min-h-screen bg-background">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 flex-col border-r border-sidebar-border bg-sidebar lg:flex">
        <div className="flex items-center gap-3 px-6 py-7">
          <span className="flex size-10 items-center justify-center rounded-xl bg-primary">
            <Activity className="size-5 text-primary-foreground" />
          </span>
          <div className="leading-tight">
            <p className="text-sm font-semibold text-sidebar-foreground">Reliability Monitor</p>
            <p className="text-xs text-muted-foreground">Editora do Brasil</p>
          </div>
        </div>
        <nav className="flex flex-1 flex-col gap-1 px-3">
          {NAV.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              className={cn(
                "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-muted-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
                isActive(pathname, item.to) && "bg-sidebar-accent text-sidebar-accent-foreground",
              )}
            >
              <item.icon className="size-4" />
              {item.label}
            </Link>
          ))}
        </nav>
        <p className="px-6 py-6 text-xs text-muted-foreground">
          Confiabilidade e disponibilidade de aplicações
        </p>
      </aside>

      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-border bg-card px-4 py-3 lg:hidden">
        <div className="flex items-center gap-2">
          <span className="flex size-8 items-center justify-center rounded-lg bg-primary">
            <Activity className="size-4 text-primary-foreground" />
          </span>
          <span className="text-sm font-semibold">Reliability Monitor</span>
        </div>
        <Link
          to="/novo-incidente"
          className="rounded-lg bg-destructive px-3 py-1.5 text-xs font-semibold text-destructive-foreground"
        >
          Novo incidente
        </Link>
      </header>

      <main className="px-4 pb-28 pt-6 lg:ml-64 lg:px-10 lg:pb-16 lg:pt-10">{children}</main>

      <nav className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-5 border-t border-border bg-card lg:hidden">
        {NAV.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            className={cn(
              "flex flex-col items-center gap-1 py-2.5 text-[10px] font-medium text-muted-foreground",
              isActive(pathname, item.to) && "text-primary",
            )}
          >
            <item.icon className="size-4" />
            {item.label.replace("Novo Incidente", "Novo")}
          </Link>
        ))}
      </nav>
    </div>
  );
}
