import { createContext, useContext, useMemo, useState, type ReactNode } from "react";
import { useCanUseChameleon, useMySafraRoles } from "@/lib/queries";

/**
 * Modo Camaleão (D-92, D-96): Kaue e Vinicius escolhem "ver como" outra audiência
 * (D-88) para conferir as telas. Só muda o que a tela mostra; tudo fica só leitura e as
 * permissões continuam sendo decididas no banco.
 */
export type ViewAs =
  | { mode: "real" }
  | { mode: "usuario" }
  | { mode: "dono"; ownerPrincipalId: string; ownerName: string }
  | { mode: "gestao" }
  | { mode: "admin" };

type Viewer = {
  roles: string[];
  isPlatformAdmin: boolean;
  canUseChameleon: boolean;
  viewAs: ViewAs;
  setViewAs: (next: ViewAs) => void;
  readOnly: boolean;
  isOwner: boolean;
  previewOwnerPrincipalId: string | null;
  canSeeAnalytics: boolean;
  canSeeAdmin: boolean;
  label: string;
};

const STORAGE_KEY = "safra-chameleon";

function readStored(): ViewAs {
  try {
    const raw = typeof window !== "undefined" ? window.sessionStorage.getItem(STORAGE_KEY) : null;
    return raw ? (JSON.parse(raw) as ViewAs) : { mode: "real" };
  } catch {
    return { mode: "real" };
  }
}

const ViewerContext = createContext<Viewer | null>(null);

export function ChameleonProvider({ children }: { children: ReactNode }) {
  const rolesQuery = useMySafraRoles();
  const [stored, setStored] = useState<ViewAs>(readStored);
  const roles = useMemo(() => rolesQuery.data ?? [], [rolesQuery.data]);
  const isPlatformAdmin = roles.includes("safra_platform_admin");
  const canUseChameleon = useCanUseChameleon(isPlatformAdmin).data === true;
  const viewAs = useMemo<ViewAs>(
    () => (canUseChameleon ? stored : { mode: "real" }),
    [canUseChameleon, stored],
  );

  const value = useMemo<Viewer>(() => {
    const setViewAs = (next: ViewAs) => {
      setStored(next);
      try {
        window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      } catch {
        // sem armazenamento: o modo vale só até recarregar a página
      }
    };
    const governance =
      roles.includes("safra_governance_admin") || roles.includes("safra_executive_admin");

    switch (viewAs.mode) {
      case "usuario":
        return {
          roles,
          isPlatformAdmin,
          canUseChameleon,
          viewAs,
          setViewAs,
          readOnly: true,
          isOwner: false,
          previewOwnerPrincipalId: null,
          canSeeAnalytics: false,
          canSeeAdmin: false,
          label: "Usuário",
        };
      case "dono":
        return {
          roles,
          isPlatformAdmin,
          canUseChameleon,
          viewAs,
          setViewAs,
          readOnly: true,
          isOwner: true,
          previewOwnerPrincipalId: viewAs.ownerPrincipalId,
          canSeeAnalytics: true,
          canSeeAdmin: false,
          label: `Dono do card: ${viewAs.ownerName}`,
        };
      case "gestao":
        return {
          roles,
          isPlatformAdmin,
          canUseChameleon,
          viewAs,
          setViewAs,
          readOnly: true,
          isOwner: false,
          previewOwnerPrincipalId: null,
          canSeeAnalytics: true,
          canSeeAdmin: false,
          label: "Governança e diretoria (Jair e Bruno)",
        };
      case "admin":
        return {
          roles,
          isPlatformAdmin,
          canUseChameleon,
          viewAs,
          setViewAs,
          readOnly: true,
          isOwner: false,
          previewOwnerPrincipalId: null,
          canSeeAnalytics: true,
          canSeeAdmin: true,
          label: "Administração",
        };
      default:
        return {
          roles,
          isPlatformAdmin,
          canUseChameleon,
          viewAs,
          setViewAs,
          readOnly: false,
          isOwner: roles.includes("scenario_owner"),
          previewOwnerPrincipalId: null,
          canSeeAnalytics: governance || isPlatformAdmin || roles.includes("scenario_owner"),
          canSeeAdmin: isPlatformAdmin,
          label: "Minha visão",
        };
    }
  }, [roles, isPlatformAdmin, canUseChameleon, viewAs]);

  return <ViewerContext.Provider value={value}>{children}</ViewerContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useViewer() {
  const value = useContext(ViewerContext);
  if (!value) throw new Error("useViewer must be used inside ChameleonProvider");
  return value;
}
