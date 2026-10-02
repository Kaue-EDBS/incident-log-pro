import { Loader2, ScrollText, Users, Eye } from "lucide-react";
import { useViewer } from "@/lib/chameleon";
import { formatDateTime } from "@/lib/metrics";
import { useAdminPeople, useRbacTrail, useScreenUsage } from "@/lib/queries";
import { CollapsibleSection } from "@/components/CollapsibleSection";

const ROLE_LABEL: Record<string, string> = {
  safra_platform_admin: "Admin da plataforma",
  safra_governance_admin: "Governança",
  safra_executive_admin: "Diretoria",
  scenario_owner: "Dono de card",
};

const ACTION_LABEL: Record<string, string> = {
  ROLE_GRANTED: "Papel dado",
  ROLE_REVOKED: "Papel retirado",
  ROLE_CHANGED: "Papel alterado",
};

const SCREEN_LABEL: Record<string, string> = {
  "/": "Início",
  "/meus-protocolos": "Meus protocolos",
  "/protocolos-dos-meus-cards": "Protocolos dos meus cards",
  "/todos-os-protocolos": "Todos os protocolos",
  "/cards-e-donos": "Cards e donos",
  "/analytics": "Analytics",
  "/administracao": "Administração",
  "/propostas": "Novo card",
};

function Loading() {
  return (
    <p role="status" className="flex items-center gap-2 text-sm text-muted-foreground">
      <Loader2 className="size-4 animate-spin" aria-hidden="true" />
      Carregando...
    </p>
  );
}

function Failed({ what }: { what: string }) {
  return (
    <p role="alert" className="text-sm text-destructive">
      Não foi possível carregar {what}.
    </p>
  );
}

/** Painel de cadastrados (D-123): só platform admins. */
export function PeoplePanel() {
  const { isPlatformAdmin } = useViewer();
  const query = useAdminPeople(isPlatformAdmin);
  if (!isPlatformAdmin) return null;

  return (
    <CollapsibleSection
      id="people-title"
      title="Painel de cadastrados"
      icon={<Users className="size-5 text-primary" aria-hidden="true" />}
      className="space-y-3"
      titleClassName="text-lg"
    >
      {query.isLoading ? (
        <Loading />
      ) : query.isError || !query.data ? (
        <Failed what="o painel de cadastrados" />
      ) : (
        <>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-left text-sm">
              <caption className="sr-only">Pessoas cadastradas, papéis e acesso</caption>
              <thead className="text-xs text-muted-foreground">
                <tr>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Pessoa
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Papéis
                  </th>
                  <th scope="col" className="py-2 pr-3 font-medium">
                    Cards
                  </th>
                  <th scope="col" className="py-2 font-medium">
                    Último acesso
                  </th>
                </tr>
              </thead>
              <tbody>
                {query.data.people.map((person) => (
                  <tr key={person.principal_id} className="border-t border-border">
                    <th scope="row" className="py-2 pr-3 font-normal">
                      {person.name ?? person.email}
                      <span className="block text-xs text-muted-foreground">{person.email}</span>
                      {!person.active ? (
                        <span className="block text-xs text-destructive">desativado</span>
                      ) : null}
                    </th>
                    <td className="py-2 pr-3">
                      {person.roles.map((role) => ROLE_LABEL[role] ?? role).join(", ") || "—"}
                    </td>
                    <td className="py-2 pr-3">{person.cards.join(", ") || "—"}</td>
                    <td className="py-2">
                      {person.has_logged_in
                        ? formatDateTime(person.last_sign_in_at)
                        : "ainda não entrou"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="text-xs text-muted-foreground">
            Outras {query.data.logins_without_registration} pessoas já entraram no Painel sem
            cadastro (usuários comuns que abrem protocolo).
          </p>
        </>
      )}
    </CollapsibleSection>
  );
}

/** Trilha de papéis (D-123): quem mudou qual papel e quando. */
export function RbacTrailPanel() {
  const { isPlatformAdmin } = useViewer();
  const query = useRbacTrail(isPlatformAdmin);
  if (!isPlatformAdmin) return null;

  return (
    <CollapsibleSection
      id="trail-title"
      title="Trilha de papéis"
      icon={<ScrollText className="size-5 text-primary" aria-hidden="true" />}
      className="space-y-3"
      titleClassName="text-lg"
    >
      {query.isLoading ? (
        <Loading />
      ) : query.isError || !query.data ? (
        <Failed what="a trilha de papéis" />
      ) : query.data.length === 0 ? (
        <p className="text-sm text-muted-foreground">Nenhuma mudança de papel registrada.</p>
      ) : (
        <ul aria-label="Mudanças de papéis" className="space-y-1 text-sm">
          {query.data.map((item, index) => (
            <li key={`${item.occurred_at}-${index}`}>
              <span className="tabular-nums text-muted-foreground">
                {formatDateTime(item.occurred_at)}
              </span>{" "}
              · {ACTION_LABEL[item.action] ?? item.action}
              {item.target_principal_email ? ` · ${item.target_principal_email}` : ""}
              {item.target_role ? ` · ${ROLE_LABEL[item.target_role] ?? item.target_role}` : ""}
              {item.actor_email ? ` · por ${item.actor_email}` : ""}
            </li>
          ))}
        </ul>
      )}
    </CollapsibleSection>
  );
}

/** Uso das telas, anônimo (D-124, D-90). */
export function ScreenUsagePanel() {
  const { isPlatformAdmin } = useViewer();
  const query = useScreenUsage(isPlatformAdmin);
  if (!isPlatformAdmin) return null;

  return (
    <CollapsibleSection
      id="usage-title"
      title="Uso das telas (últimos 30 dias, anônimo)"
      icon={<Eye className="size-5 text-primary" aria-hidden="true" />}
      className="space-y-3"
      titleClassName="text-lg"
    >
      {query.isLoading ? (
        <Loading />
      ) : query.isError || !query.data ? (
        <Failed what="o uso das telas" />
      ) : query.data.routes.length === 0 ? (
        <p className="text-sm text-muted-foreground">Nenhuma tela aberta no período.</p>
      ) : (
        <ul aria-label="Aberturas por tela" className="grid gap-2 text-sm sm:grid-cols-2">
          {query.data.routes.map((item) => (
            <li
              key={item.route}
              className="flex justify-between rounded-lg border border-border px-3 py-2"
            >
              <span>{SCREEN_LABEL[item.route] ?? item.route}</span>
              <span className="tabular-nums">
                {item.views}
                <span className="text-muted-foreground"> (hoje {item.today ?? 0})</span>
              </span>
            </li>
          ))}
        </ul>
      )}
      <p className="text-xs text-muted-foreground">
        Conta só quantas vezes cada tela foi aberta por dia; não guarda quem abriu.
      </p>
    </CollapsibleSection>
  );
}
