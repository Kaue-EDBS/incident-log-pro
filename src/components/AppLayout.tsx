import { Link, useRouter, useRouterState } from "@tanstack/react-router";
import {
  ArrowLeft,
  BarChart3,
  ClipboardList,
  Eye,
  Inbox,
  Lightbulb,
  ListChecks,
  Table2,
  LayoutGrid,
  Settings,
} from "lucide-react";
import { useEffect, useMemo, type ReactNode } from "react";
import { cn } from "@/lib/utils";
import { BrandMark } from "@/components/BrandMark";
import { useAuth } from "@/integrations/supabase/AuthProvider";
import { useViewer, type ViewAs } from "@/lib/chameleon";
import { logScreenView } from "@/lib/ops";
import { useSafraStartCatalog } from "@/lib/queries";
import { deliverQueuedNotifications } from "@/lib/notifications.functions";

type NavItem = { to: string; label: string; short: string; icon: typeof LayoutGrid };

function isActive(pathname: string, to: string) {
  return to === "/" ? pathname === "/" : pathname.startsWith(to);
}

/** Seletor do Modo Camaleão (D-92), visível só para admins da plataforma. */
function ChameleonBar() {
  const viewer = useViewer();
  const catalog = useSafraStartCatalog();
  const owners = useMemo(() => {
    const seen = new Map<string, string>();
    for (const card of catalog.data ?? []) {
      seen.set(card.owner.principal_id, card.owner.display_name ?? card.owner.corporate_email);
    }
    return [...seen.entries()].sort((a, b) => a[1].localeCompare(b[1]));
  }, [catalog.data]);

  if (!viewer.canUseChameleon) return null;

  const current =
    viewer.viewAs.mode === "dono" ? `dono:${viewer.viewAs.ownerPrincipalId}` : viewer.viewAs.mode;

  const change = (value: string) => {
    let next: ViewAs = { mode: "real" };
    if (value.startsWith("dono:")) {
      const id = value.slice(5);
      next = {
        mode: "dono",
        ownerPrincipalId: id,
        ownerName: owners.find(([k]) => k === id)?.[1] ?? "",
      };
    } else if (value === "usuario" || value === "gestao" || value === "admin") {
      next = { mode: value };
    }
    viewer.setViewAs(next);
  };

  return (
    <div
      className={cn(
        "flex flex-wrap items-center gap-3 border-b px-4 py-2 text-sm lg:ml-64 lg:px-10",
        viewer.readOnly ? "border-secondary bg-accent" : "border-border bg-card",
      )}
    >
      <Eye className="size-4 text-primary" aria-hidden="true" />
      <label htmlFor="chameleon" className="font-semibold">
        Modo Camaleão
      </label>
      <select
        id="chameleon"
        value={current}
        onChange={(event) => change(event.target.value)}
        className="h-9 rounded-md border border-input bg-card px-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        <option value="real">Minha visão (real)</option>
        <option value="usuario">Ver como: usuário</option>
        {owners.map(([id, name]) => (
          <option key={id} value={`dono:${id}`}>
            Ver como: dono do card ({name})
          </option>
        ))}
        <option value="gestao">Ver como: Jair e Bruno</option>
        <option value="admin">Ver como: administração</option>
      </select>
      {viewer.readOnly ? (
        <span role="status" className="text-xs font-medium">
          Você está vendo como {viewer.label}. Só visualização: nada pode ser aberto, concluído ou
          cancelado neste modo.
        </span>
      ) : null}
    </div>
  );
}

export function AppLayout({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const router = useRouter();
  const { user, signOut } = useAuth();
  const viewer = useViewer();

  const goBack = () => {
    if (router.history.canGoBack()) router.history.back();
    else void router.navigate({ to: "/" });
  };

  // Clicar no item do menu da tela atual leva de volta ao topo da página.
  const onNavClick = (to: string) => {
    if (pathname === to) window.scrollTo({ top: 0, behavior: "smooth" });
  };

  // D-124: conta cada tela aberta, sem identificar a pessoa.
  useEffect(() => {
    logScreenView(pathname);
  }, [pathname]);

  // M05: enquanto o Painel estiver aberto, entrega os avisos da fila (inclui lembretes).
  useEffect(() => {
    if (!user) return;
    const run = () => void deliverQueuedNotifications().catch(() => undefined);
    run();
    const id = window.setInterval(run, 2 * 60 * 1000);
    return () => window.clearInterval(id);
  }, [user]);

  // Só define o que aparece no menu; a permissão é sempre conferida no banco.
  const nav: NavItem[] = [
    { to: "/", label: "Início", short: "Início", icon: LayoutGrid },
    { to: "/meus-protocolos", label: "Meus protocolos", short: "Meus", icon: ClipboardList },
    { to: "/propostas", label: "Novo card", short: "Novo card", icon: Lightbulb },
    ...(viewer.isOwner
      ? [
          {
            to: "/protocolos-dos-meus-cards",
            label: "Protocolos dos meus cards",
            short: "Meus cards",
            icon: Inbox,
          },
        ]
      : []),
    ...(viewer.canSeeAllProtocols
      ? [
          {
            to: "/todos-os-protocolos",
            label: "Todos os protocolos",
            short: "Todos",
            icon: ListChecks,
          },
        ]
      : []),
    ...(viewer.canSeeAllProtocols
      ? [{ to: "/cards-e-donos", label: "Cards e donos", short: "Cards", icon: Table2 }]
      : []),
    ...(viewer.canSeeAnalytics
      ? [{ to: "/analytics", label: "Analytics", short: "Analytics", icon: BarChart3 }]
      : []),
    ...(viewer.canSeeAdmin
      ? [{ to: "/administracao", label: "Administração", short: "Admin", icon: Settings }]
      : []),
  ];

  return (
    <div className="min-h-screen bg-background">
      <a
        href="#conteudo"
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-card focus:px-4 focus:py-2 focus:shadow"
      >
        Pular para o conteúdo
      </a>
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 flex-col bg-sidebar text-sidebar-foreground lg:flex">
        <div className="flex items-center gap-3 px-6 py-7">
          <BrandMark />
          <div className="leading-tight">
            <p className="text-sm font-semibold">Painel Safra</p>
            <p className="text-xs text-white/80">Editora do Brasil</p>
          </div>
        </div>
        <nav aria-label="Principal" className="flex flex-1 flex-col gap-1 px-3">
          {nav.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              onClick={() => onNavClick(item.to)}
              aria-current={isActive(pathname, item.to) ? "page" : undefined}
              className={cn(
                "flex min-h-11 items-center gap-3 rounded-lg border-l-4 border-transparent px-3 py-2.5 text-sm font-medium text-white/85 transition-colors hover:bg-sidebar-accent hover:text-white",
                isActive(pathname, item.to) &&
                  "border-sidebar-primary bg-sidebar-accent text-white",
              )}
            >
              <item.icon className="size-4" aria-hidden="true" />
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="border-t border-sidebar-border px-4 py-4">
          <p className="truncate text-xs font-medium text-white/85">
            {user?.email ?? "Usuário corporativo"}
          </p>
          <div className="mt-3 flex gap-2">
            <button
              type="button"
              className="inline-flex min-h-11 flex-1 items-center justify-center gap-1 rounded-lg border border-white/30 px-3 py-2 text-xs font-medium text-white transition-colors hover:bg-sidebar-accent"
              onClick={goBack}
            >
              <ArrowLeft className="size-4" aria-hidden="true" />
              Voltar
            </button>
            <button
              type="button"
              className="min-h-11 flex-1 rounded-lg border border-white/30 px-3 py-2 text-xs font-medium text-white transition-colors hover:bg-sidebar-accent"
              onClick={() => void signOut()}
            >
              Sair
            </button>
          </div>
        </div>
      </aside>

      <header className="sticky top-0 z-20 flex items-center justify-between bg-sidebar px-4 py-3 text-white lg:hidden">
        <div className="flex items-center gap-2">
          <BrandMark className="h-7" />
          <span className="text-sm font-semibold">Painel Safra</span>
        </div>
        <div className="flex gap-2">
          <button
            type="button"
            className="inline-flex min-h-11 items-center gap-1 rounded-lg border border-white/30 px-3 text-xs font-medium"
            onClick={goBack}
          >
            <ArrowLeft className="size-4" aria-hidden="true" />
            Voltar
          </button>
          <button
            type="button"
            className="min-h-11 rounded-lg border border-white/30 px-3 text-xs font-medium"
            onClick={() => void signOut()}
          >
            Sair
          </button>
        </div>
      </header>

      <ChameleonBar />

      <main id="conteudo" className="px-4 pb-28 pt-6 lg:ml-64 lg:px-10 lg:pb-16 lg:pt-10">
        {children}
      </main>

      <nav
        aria-label="Principal"
        className="fixed inset-x-0 bottom-0 z-30 flex border-t border-border bg-card lg:hidden"
      >
        {nav.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            onClick={() => onNavClick(item.to)}
            aria-current={isActive(pathname, item.to) ? "page" : undefined}
            className={cn(
              "flex min-h-14 flex-1 flex-col items-center justify-center gap-1 py-2 text-xs font-medium text-muted-foreground",
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
