import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { ChevronLeft, ChevronRight, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { CollapsibleSection } from "@/components/CollapsibleSection";
import { ConfirmButton } from "@/components/ConfirmButton";
import { Button } from "@/components/ui/button";
import { useViewer } from "@/lib/chameleon";
import { formatDateTime, formatSeconds } from "@/lib/metrics";
import {
  GOVERNANCE_ACTION_TYPES,
  useRegisterGovernanceAction,
  useWeeklyGovernance,
  type GovernanceActionType,
  type WeeklyGovernance,
} from "@/lib/queries";
import { SITUATION_LABEL, cardDisplayName, cardNumber, safraErrorMessage } from "@/lib/safra";

export const Route = createFileRoute("/governanca-semanal")({
  head: () => ({
    meta: [
      { title: "Governança semanal | Painel Safra" },
      { name: "description", content: "Resumo da semana e ações decididas pela governança." },
    ],
  }),
  component: WeeklyGovernancePage,
});

const ACTION_LABEL: Record<GovernanceActionType, string> = {
  PROCESS_CHANGE: "Mudar processo",
  MASTER_DATA_FIX: "Corrigir cadastro",
  CAPACITY_CHANGE: "Mudar capacidade",
  PARTNER_ACTION: "Ação com parceiro",
  SYSTEM_CHANGE: "Mudar sistema",
  TRAINING: "Treinamento",
  NO_ACTION_JUSTIFIED: "Sem ação (justificada)",
};

const fieldClass = "min-h-11 w-full rounded-md border border-input bg-background px-3 text-sm";

/** "2026-10-05" -> "05/10" */
function shortDate(day: string) {
  const [, month, date] = day.split("-");
  return `${date}/${month}`;
}

/** Soma dias a uma data "AAAA-MM-DD" sem depender do fuso do computador. */
function addDays(day: string, days: number) {
  const [y, m, d] = day.split("-").map(Number);
  const next = new Date(Date.UTC(y!, m! - 1, d! + days));
  return next.toISOString().slice(0, 10);
}

/** F05 (D-140): resumo da semana e ações decididas na reunião (que acontece fora do Painel). */
function WeeklyGovernancePage() {
  const viewer = useViewer();
  const [weekStart, setWeekStart] = useState<string | null>(null);
  const query = useWeeklyGovernance(viewer.canSeeAllProtocols, weekStart);

  if (!viewer.canSeeAllProtocols) {
    return (
      <div className="mx-auto max-w-5xl">
        <p className="rounded-xl border border-dashed border-border bg-card p-6 text-sm text-muted-foreground">
          Esta área é para a gestão da Safra e para os administradores.
        </p>
      </div>
    );
  }

  const data = query.data;

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Governança semanal</h1>
        <p className="text-sm text-muted-foreground">
          O que aconteceu na semana (segunda a domingo) e as ações decididas na reunião. A reunião
          continua fora do Painel; aqui fica o registro.
        </p>
      </header>

      {data ? (
        <nav aria-label="Escolher a semana" className="flex flex-wrap items-center gap-3">
          <Button
            variant="outline"
            className="min-h-11"
            disabled={query.isPlaceholderData}
            onClick={() => setWeekStart(addDays(data.week_start, -7))}
          >
            <ChevronLeft className="size-4" aria-hidden="true" />
            Semana anterior
          </Button>
          <p className="text-sm font-medium" aria-live="polite">
            Semana de {shortDate(data.week_start)} a {shortDate(data.week_end)}
          </p>
          <Button
            variant="outline"
            className="min-h-11"
            disabled={query.isPlaceholderData}
            onClick={() => setWeekStart(addDays(data.week_start, 7))}
          >
            Próxima semana
            <ChevronRight className="size-4" aria-hidden="true" />
          </Button>
          {weekStart ? (
            <Button variant="ghost" className="min-h-11" onClick={() => setWeekStart(null)}>
              Voltar para esta semana
            </Button>
          ) : null}
        </nav>
      ) : null}

      {query.isLoading ? (
        <p role="status" className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="size-4 animate-spin" aria-hidden="true" />
          Carregando...
        </p>
      ) : query.isError || !data ? (
        <div role="alert" className="rounded-xl border border-destructive/30 bg-destructive/10 p-5">
          <p className="font-medium text-destructive">
            Não foi possível carregar a governança semanal.
          </p>
          <Button variant="outline" className="mt-3 min-h-11" onClick={() => void query.refetch()}>
            Tentar de novo
          </Button>
        </div>
      ) : (
        <>
          <WeekSummary data={data} />
          <Longest data={data} />
          <StillActive data={data} />
          <Actions
            key={data.week_start}
            data={data}
            readOnly={viewer.readOnly || query.isPlaceholderData}
          />
        </>
      )}
    </div>
  );
}

function WeekSummary({ data }: { data: WeeklyGovernance }) {
  const t = data.totals;
  return (
    <CollapsibleSection
      id="week-summary-title"
      title={`Resumo da semana: ${t.opened} abertos (${t.opened_previous_week} na anterior) · ${t.resolved} encerrados · ${t.cancelled} cancelados`}
    >
      {data.cards.length === 0 ? (
        <p className="text-sm text-muted-foreground">Nenhum protocolo nesta semana.</p>
      ) : (
        <div
          className="overflow-x-auto"
          tabIndex={0}
          role="region"
          aria-label="Tabela (role para os lados no celular)"
        >
          <table className="w-full min-w-[640px] text-left text-sm">
            <caption className="sr-only">Protocolos da semana por card</caption>
            <thead className="text-xs text-muted-foreground">
              <tr>
                <th scope="col" className="py-2 pr-3 font-medium">
                  Card
                </th>
                <th scope="col" className="py-2 pr-3 font-medium">
                  Abertos
                </th>
                <th scope="col" className="py-2 pr-3 font-medium">
                  Semana anterior
                </th>
                <th scope="col" className="py-2 pr-3 font-medium">
                  Encerrados
                </th>
                <th scope="col" className="py-2 pr-3 font-medium">
                  Cancelados
                </th>
                <th scope="col" className="py-2 font-medium">
                  Tempo mediano
                </th>
              </tr>
            </thead>
            <tbody>
              {data.cards.map((card) => (
                <tr key={card.scenario_id} className="border-t border-border">
                  <th scope="row" className="py-2 pr-3 font-normal">
                    {cardNumber(card.code)} · {cardDisplayName(card.name)}
                  </th>
                  <td className="py-2 pr-3 tabular-nums">{card.opened}</td>
                  <td className="py-2 pr-3 tabular-nums">{card.opened_previous_week}</td>
                  <td className="py-2 pr-3 tabular-nums">{card.resolved}</td>
                  <td className="py-2 pr-3 tabular-nums">{card.cancelled}</td>
                  <td className="py-2 tabular-nums">{formatSeconds(card.median_secs)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </CollapsibleSection>
  );
}

function Longest({ data }: { data: WeeklyGovernance }) {
  const first = data.longest[0];
  return (
    <CollapsibleSection
      id="longest-title"
      title={
        first
          ? `Mais demorados da semana: 1º ${first.protocol_number} (${formatSeconds(first.duration_secs)})`
          : "Mais demorados da semana"
      }
    >
      {data.longest.length === 0 ? (
        <p className="text-sm text-muted-foreground">Nenhum protocolo encerrado nesta semana.</p>
      ) : (
        <ol aria-label="Protocolos mais demorados" className="space-y-1 text-sm">
          {data.longest.map((item) => (
            <li key={item.protocol_number} className="flex justify-between gap-3">
              <span>
                Protocolo {item.protocol_number} · {cardNumber(item.code)}{" "}
                {cardDisplayName(item.name)}
              </span>
              <span className="tabular-nums text-muted-foreground">
                {formatSeconds(item.duration_secs)}
              </span>
            </li>
          ))}
        </ol>
      )}
    </CollapsibleSection>
  );
}

function StillActive({ data }: { data: WeeklyGovernance }) {
  return (
    <CollapsibleSection id="active-title" title={`Abertos agora: ${data.totals.active_now}`}>
      {data.active.length === 0 ? (
        <p className="text-sm text-muted-foreground">Nenhum protocolo em andamento agora.</p>
      ) : (
        <ul aria-label="Protocolos em andamento" className="space-y-1 text-sm">
          {data.active.map((item) => (
            <li key={item.protocol_number} className="flex flex-wrap justify-between gap-2">
              <span>
                Protocolo {item.protocol_number} · {cardNumber(item.code)}{" "}
                {cardDisplayName(item.name)}
              </span>
              <span className="text-muted-foreground">
                {SITUATION_LABEL[item.situation]} · aberto em {formatDateTime(item.opened_at)}
              </span>
            </li>
          ))}
        </ul>
      )}
    </CollapsibleSection>
  );
}

function Actions({ data, readOnly }: { data: WeeklyGovernance; readOnly: boolean }) {
  const register = useRegisterGovernanceAction();
  const [card, setCard] = useState("");
  const [type, setType] = useState<GovernanceActionType | "">("");
  const [text, setText] = useState("");
  const ready = type !== "" && text.trim().length >= 10;

  const save = async () => {
    if (type === "") return;
    try {
      await register.mutateAsync({
        weekStart: data.week_start,
        scenarioId: card || null,
        actionType: type,
        description: text.trim(),
      });
      toast.success("Ação registrada.");
      setCard("");
      setType("");
      setText("");
    } catch (error) {
      toast.error(safraErrorMessage(error, "Não foi possível registrar agora. Tente de novo."));
    }
  };

  return (
    <CollapsibleSection id="actions-title" title={`Ações da semana: ${data.actions.length}`}>
      {data.actions.length === 0 ? (
        <p className="text-sm text-muted-foreground">Nenhuma ação registrada nesta semana.</p>
      ) : (
        <ul aria-label="Ações registradas" className="space-y-2 text-sm">
          {data.actions.map((action) => (
            <li key={action.id} className="rounded-lg border border-border p-3">
              <p className="font-medium">
                {ACTION_LABEL[action.action_type]}
                {action.code
                  ? ` · ${cardNumber(action.code)} ${cardDisplayName(action.name ?? "")}`
                  : " · Geral"}
              </p>
              <p>{action.description}</p>
              <p className="text-xs text-muted-foreground">
                {action.created_by_name ?? "—"} · {formatDateTime(action.created_at)}
              </p>
            </li>
          ))}
        </ul>
      )}

      {readOnly ? null : (
        <div className="space-y-3 border-t border-border pt-3">
          <h3 className="text-sm font-semibold">Registrar uma ação decidida</h3>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="block space-y-1 text-sm">
              <span className="font-medium">Card (opcional)</span>
              <select className={fieldClass} value={card} onChange={(e) => setCard(e.target.value)}>
                <option value="">Geral (vale para todos)</option>
                {data.card_options.map((option) => (
                  <option key={option.scenario_id} value={option.scenario_id}>
                    {cardNumber(option.code)} · {cardDisplayName(option.name)}
                  </option>
                ))}
              </select>
            </label>
            <label className="block space-y-1 text-sm">
              <span className="font-medium">Tipo da ação</span>
              <select
                className={fieldClass}
                value={type}
                onChange={(e) => setType(e.target.value as GovernanceActionType | "")}
              >
                <option value="">Escolha</option>
                {GOVERNANCE_ACTION_TYPES.map((value) => (
                  <option key={value} value={value}>
                    {ACTION_LABEL[value]}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <label className="block space-y-1 text-sm">
            <span className="font-medium">O que foi decidido</span>
            <span className="block text-xs text-muted-foreground">Pelo menos 10 caracteres.</span>
            <textarea
              className="min-h-24 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
              value={text}
              maxLength={1000}
              onChange={(e) => setText(e.target.value)}
            />
          </label>
          <ConfirmButton
            label="Registrar ação"
            title={`Registrar na semana de ${shortDate(data.week_start)} a ${shortDate(data.week_end)}?`}
            description="O registro fica guardado e não pode ser alterado nem apagado depois."
            confirmLabel="Sim, registrar"
            disabled={!ready || register.isPending}
            onConfirm={() => void save()}
          />
        </div>
      )}
    </CollapsibleSection>
  );
}
