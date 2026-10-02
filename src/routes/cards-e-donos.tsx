import { createFileRoute } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useViewer } from "@/lib/chameleon";
import { useCardsOverview } from "@/lib/queries";
import { cardDisplayName, cardNumber } from "@/lib/safra";

export const Route = createFileRoute("/cards-e-donos")({
  head: () => ({
    meta: [
      { title: "Cards e donos | Painel Safra" },
      { name: "description", content: "Quem é dono de cada card da Safra." },
    ],
  }),
  component: CardsAndOwners,
});

/** Cards e donos (D-121): só leitura, para Jair, Bruno e admins. */
function CardsAndOwners() {
  const viewer = useViewer();
  const query = useCardsOverview(viewer.canSeeAllProtocols);

  if (!viewer.canSeeAllProtocols) {
    return (
      <div className="mx-auto max-w-5xl">
        <p className="rounded-xl border border-dashed border-border bg-card p-6 text-sm text-muted-foreground">
          Esta área é para a gestão da Safra e para os administradores.
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Cards e donos</h1>
        <p className="text-sm text-muted-foreground">
          Quem é dono de cada card, a área responsável e os protocolos da Safra corrente.
        </p>
      </header>

      {query.isLoading ? (
        <p role="status" className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="size-4 animate-spin" aria-hidden="true" />
          Carregando...
        </p>
      ) : query.isError || !query.data ? (
        <div role="alert" className="rounded-xl border border-destructive/30 bg-destructive/10 p-5">
          <p className="font-medium text-destructive">Não foi possível carregar os cards.</p>
          <Button variant="outline" className="mt-3" onClick={() => void query.refetch()}>
            Tentar de novo
          </Button>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border bg-card p-4">
          <table className="w-full min-w-[720px] text-left text-sm">
            <caption className="sr-only">Cards, donos e protocolos da Safra</caption>
            <thead className="text-xs text-muted-foreground">
              <tr>
                <th scope="col" className="py-2 pr-3 font-medium">
                  Card
                </th>
                <th scope="col" className="py-2 pr-3 font-medium">
                  Dono
                </th>
                <th scope="col" className="py-2 pr-3 font-medium">
                  Área responsável
                </th>
                <th scope="col" className="py-2 pr-3 font-medium">
                  Em andamento
                </th>
                <th scope="col" className="py-2 font-medium">
                  Protocolos na Safra
                </th>
              </tr>
            </thead>
            <tbody>
              {query.data.map((card) => (
                <tr key={card.scenario_id} className="border-t border-border">
                  <th scope="row" className="py-2 pr-3 font-normal">
                    {cardNumber(card.code)} · {cardDisplayName(card.name)}
                    {card.version_no !== null ? (
                      <span className="block text-xs text-muted-foreground">
                        versão {card.version_no}
                      </span>
                    ) : null}
                  </th>
                  <td className="py-2 pr-3">
                    {card.owner_name ?? "—"}
                    {!card.owner_available ? (
                      <span className="block text-xs text-destructive">
                        indisponível: ninguém abre protocolo neste card até um novo dono ser
                        definido
                      </span>
                    ) : !card.owner_has_logged_in ? (
                      <span className="block text-xs text-muted-foreground">
                        ainda não entrou no Painel
                      </span>
                    ) : null}
                  </td>
                  <td className="py-2 pr-3">{card.responsible_area ?? "—"}</td>
                  <td className="py-2 pr-3 tabular-nums">{card.active_now}</td>
                  <td className="py-2 tabular-nums">{card.season_protocols}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
