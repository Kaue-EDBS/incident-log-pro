import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link } from "@tanstack/react-router";
import { Loader2, PlayCircle, Search, UserRound, X } from "lucide-react";
import { toast } from "sonner";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { SituationBadge, TreatmentActions } from "@/components/TreatmentActions";
import { analyticsLocalInputToIso, formatDateTime, toLocalInput } from "@/lib/metrics";
import { useSafraStartCatalog, useSafraStartTreatment } from "@/lib/queries";
import { useViewer } from "@/lib/chameleon";
import { cardDisplayName, safraErrorMessage } from "@/lib/safra";
import type { SafraStartCatalogItem } from "@/lib/safra";
import { cn } from "@/lib/utils";

const MIN_SUMMARY = 10;

function ownerName(card: SafraStartCatalogItem) {
  return card.owner.display_name ?? card.owner.corporate_email;
}

function protocolSteps(text: string | null): string[] {
  if (!text) return [];
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => line.replace(/^\d+\)\s*/, ""));
}

function normalize(value: string) {
  return value.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

/** Catálogo com card que se expande (D-81): tocou, os outros somem; o X traz todos de volta. */
export function ScenarioCatalog() {
  const { data: rawCards = [], isLoading, isError, refetch } = useSafraStartCatalog();
  const viewer = useViewer();
  // Modo Camaleão (D-92): a tela mostra o catálogo como a audiência escolhida o veria.
  const cards = useMemo(
    () =>
      viewer.readOnly
        ? rawCards.map((card) => ({
            ...card,
            is_my_card:
              viewer.previewOwnerPrincipalId !== null &&
              card.owner.principal_id === viewer.previewOwnerPrincipalId,
            my_open_treatment: null,
          }))
        : rawCards,
    [rawCards, viewer.readOnly, viewer.previewOwnerPrincipalId],
  );
  const [query, setQuery] = useState("");
  const [openId, setOpenId] = useState<string | null>(null);
  const cardButtons = useRef(new Map<string, HTMLButtonElement>());
  const lastOpened = useRef<string | null>(null);

  const visible = useMemo(() => {
    const q = normalize(query.trim());
    if (!q) return cards;
    return cards.filter((card) =>
      normalize(
        [card.code, card.name, card.responsible_area.name, card.trigger_description ?? ""].join(
          " ",
        ),
      ).includes(q),
    );
  }, [cards, query]);

  const open = cards.find((card) => card.scenario_id === openId) ?? null;

  const close = useCallback(() => {
    setOpenId(null);
  }, []);

  useEffect(() => {
    if (openId === null && lastOpened.current) {
      cardButtons.current.get(lastOpened.current)?.focus();
    }
  }, [openId]);

  if (isLoading) {
    return (
      <div
        role="status"
        className="flex items-center gap-3 rounded-xl border border-border bg-card p-6 text-sm text-muted-foreground"
      >
        <Loader2 className="size-4 animate-spin" aria-hidden="true" />
        Carregando os cards...
      </div>
    );
  }

  if (isError) {
    return (
      <div role="alert" className="rounded-xl border border-destructive/30 bg-destructive/10 p-5">
        <p className="font-medium text-destructive">Não foi possível carregar os cards.</p>
        <Button variant="outline" className="mt-3" onClick={() => void refetch()}>
          Tentar de novo
        </Button>
      </div>
    );
  }

  if (open) {
    return <ExpandedCard card={open} onClose={close} />;
  }

  return (
    <section aria-labelledby="catalog-title" className="space-y-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h2 id="catalog-title" className="text-lg font-semibold">
            Qual é o problema?
          </h2>
          <p className="text-sm text-muted-foreground">
            Escolha o card que descreve o que está acontecendo.
          </p>
        </div>
        <label className="relative block w-full sm:w-80">
          <span className="sr-only">Buscar card</span>
          <Search
            className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
            aria-hidden="true"
          />
          <input
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Buscar: NF-e, transportadora, estoque..."
            className="h-11 w-full rounded-lg border border-input bg-card pl-9 pr-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          />
        </label>
      </div>

      {visible.length === 0 ? (
        <p role="status" className="rounded-xl border border-dashed border-border p-6 text-sm">
          Nenhum card encontrado para “{query}”. Tente outra palavra.
        </p>
      ) : (
        <ul aria-label="Cards disponíveis" className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {visible.map((card) => (
            <li key={card.scenario_id}>
              <button
                ref={(element) => {
                  if (element) cardButtons.current.set(card.scenario_id, element);
                }}
                type="button"
                aria-expanded={false}
                onClick={() => {
                  lastOpened.current = card.scenario_id;
                  setOpenId(card.scenario_id);
                }}
                className="flex h-full w-full flex-col gap-3 rounded-xl border border-border bg-card p-4 text-left transition-colors hover:border-primary/60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                <div className="flex items-start justify-between gap-3">
                  <p className="font-semibold leading-snug">{cardDisplayName(card.name)}</p>
                  {card.my_open_treatment ? (
                    <SituationBadge situation={card.my_open_treatment.situation} />
                  ) : null}
                </div>
                <div className="mt-auto space-y-1 text-xs text-muted-foreground">
                  <p>Área: {card.responsible_area.name}</p>
                  <p>Dono do card: {ownerName(card)}</p>
                  {card.is_my_card ? (
                    <p className="font-medium text-foreground">Você é o dono deste card.</p>
                  ) : null}
                  {card.my_open_treatment ? (
                    <p className="font-medium text-foreground">
                      Seu protocolo: {card.my_open_treatment.protocol_number}
                    </p>
                  ) : null}
                </div>
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function ExpandedCard({ card, onClose }: { card: SafraStartCatalogItem; onClose: () => void }) {
  const heading = useRef<HTMLHeadingElement>(null);
  const steps = protocolSteps(card.protocol_text);

  // Foco no título só ao abrir o card, para não roubar o cursor de quem digita.
  useEffect(() => {
    heading.current?.focus();
  }, []);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      const typing = target?.closest("input, textarea, select") !== null;
      if (event.key === "Escape" && !typing && !document.querySelector("[role='alertdialog']")) {
        onClose();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <section
      aria-labelledby="card-title"
      className="relative rounded-2xl border border-primary/40 bg-card p-5 shadow-sm lg:p-8"
    >
      <Button
        variant="ghost"
        size="icon"
        className="absolute right-3 top-3 size-11"
        onClick={onClose}
        aria-label="Fechar e voltar a todos os cards"
      >
        <X className="size-5" aria-hidden="true" />
      </Button>

      <header className="pr-12">
        <h2
          id="card-title"
          ref={heading}
          tabIndex={-1}
          className="text-2xl font-semibold leading-tight focus:outline-none"
        >
          {cardDisplayName(card.name)}
        </h2>
        <div className="mt-3 flex flex-wrap items-center gap-x-6 gap-y-2 text-sm">
          <span className="inline-flex items-center gap-2">
            <UserRound className="size-4 text-muted-foreground" aria-hidden="true" />
            <span>
              Dono do card: <strong>{ownerName(card)}</strong>
            </span>
          </span>
          <span>Área: {card.responsible_area.name}</span>
        </div>
      </header>

      <div className="mt-6 grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="order-2 space-y-5 lg:order-1">
          {card.trigger_description ? (
            <div>
              <h3 className="text-sm font-semibold">Quando usar este card</h3>
              <p className="mt-1 text-sm text-muted-foreground">{card.trigger_description}</p>
            </div>
          ) : null}
          {steps.length ? (
            <div>
              <h3 className="text-sm font-semibold">O que acontece no protocolo</h3>
              <ol className="mt-2 list-decimal space-y-1.5 pl-5 text-sm leading-6">
                {steps.map((step) => (
                  <li key={step}>{step}</li>
                ))}
              </ol>
            </div>
          ) : null}
        </div>

        <div className="order-1 lg:order-2">
          {card.is_my_card ? (
            <div className="rounded-xl border border-border bg-muted p-5 text-sm">
              <p className="font-semibold">Você é o dono deste card.</p>
              <p className="mt-1 text-muted-foreground">
                Donos não abrem protocolo do próprio card. Os protocolos abertos por outras pessoas
                aparecem em{" "}
                <Link
                  to="/protocolos-dos-meus-cards"
                  className="font-medium text-primary underline"
                >
                  Protocolos dos meus cards
                </Link>
                .
              </p>
            </div>
          ) : card.my_open_treatment ? (
            <div className="space-y-4 rounded-xl border border-primary/30 bg-primary/5 p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <p className="text-lg font-semibold">
                  Protocolo {card.my_open_treatment.protocol_number}
                </p>
                <SituationBadge situation={card.my_open_treatment.situation} />
              </div>
              <p className="text-sm text-muted-foreground">
                Aberto em {formatDateTime(card.my_open_treatment.opened_at)}. Quando o problema
                estiver resolvido do seu lado, toque em Concluído.
              </p>
              <TreatmentActions treatment={card.my_open_treatment} />
              <Link to="/meus-protocolos" className="inline-block text-sm text-primary underline">
                Ver em Meus protocolos
              </Link>
            </div>
          ) : (
            <StartForm card={card} />
          )}
        </div>
      </div>
    </section>
  );
}

function StartForm({ card }: { card: SafraStartCatalogItem }) {
  const start = useSafraStartTreatment();
  const { readOnly } = useViewer();
  const [summary, setSummary] = useState("");
  const [startedLocal, setStartedLocal] = useState(() => toLocalInput(new Date().toISOString()));
  const [areas, setAreas] = useState<string[]>([]);
  const retryKey = useRef<string | null>(null);
  const resetKey = () => {
    retryKey.current = null;
  };

  const trimmed = summary.trim();
  const startedIso = analyticsLocalInputToIso(startedLocal);
  const startedInFuture =
    startedIso !== null && new Date(startedIso).getTime() > Date.now() + 60_000;
  const canStart =
    !readOnly && trimmed.length >= MIN_SUMMARY && !startedInFuture && !start.isPending;

  const submit = async () => {
    const idempotencyKey = retryKey.current ?? globalThis.crypto.randomUUID();
    retryKey.current = idempotencyKey;
    try {
      const created = await start.mutateAsync({
        scenarioId: card.scenario_id,
        idempotencyKey,
        impactSummary: trimmed,
        impactedAreaIds: areas,
        problemStartedAt: startedIso,
      });
      retryKey.current = null;
      toast.success(`Protocolo ${created.protocol_number} aberto.`);
    } catch (error) {
      toast.error(safraErrorMessage(error, "Não foi possível abrir o protocolo. Tente de novo."));
    }
  };

  return (
    <form
      className="space-y-5 rounded-xl border border-border bg-background p-5"
      onSubmit={(event) => event.preventDefault()}
      aria-describedby="start-help"
    >
      <p id="start-help" className="text-sm text-muted-foreground">
        Abrir um protocolo registra o problema e o coloca na lista do dono do card.
      </p>

      <label className="block space-y-2">
        <span className="text-sm font-semibold">O que está acontecendo? (obrigatório)</span>
        <Textarea
          value={summary}
          maxLength={2000}
          rows={4}
          required
          aria-describedby="summary-hint"
          onChange={(event) => {
            setSummary(event.target.value);
            resetKey();
          }}
          placeholder="Ex.: 35 pedidos do e-commerce parados desde as 9h, sem retorno da transportadora."
        />
        <span id="summary-hint" className="flex justify-between text-xs text-muted-foreground">
          <span>
            {trimmed.length < MIN_SUMMARY
              ? `Escreva pelo menos ${MIN_SUMMARY} caracteres: o dono do card usa isto para agir.`
              : "Ótimo, isso orienta o dono do card."}
          </span>
          <span>{summary.length}/2000</span>
        </span>
      </label>

      <div className="space-y-2">
        <label htmlFor="problem-start" className="block text-sm font-semibold">
          Quando o problema começou?
        </label>
        <div className="flex flex-wrap gap-2">
          <input
            id="problem-start"
            type="datetime-local"
            value={startedLocal}
            max={toLocalInput(new Date().toISOString())}
            onChange={(event) => {
              setStartedLocal(event.target.value);
              resetKey();
            }}
            aria-describedby="problem-start-hint"
            aria-invalid={startedInFuture}
            className="h-11 rounded-lg border border-input bg-card px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          />
          <Button
            type="button"
            variant="outline"
            className="h-11"
            onClick={() => {
              setStartedLocal(toLocalInput(new Date().toISOString()));
              resetKey();
            }}
          >
            Agora
          </Button>
        </div>
        <p
          id="problem-start-hint"
          className={cn("text-xs", startedInFuture ? "text-destructive" : "text-muted-foreground")}
        >
          {startedInFuture
            ? "O início não pode estar no futuro."
            : "Se não souber, deixe como está (agora). Horário de Brasília."}
        </p>
      </div>

      {card.potential_impacted_areas.length ? (
        <fieldset>
          <legend className="text-sm font-semibold">Outras áreas afetadas (opcional)</legend>
          <div className="mt-2 flex flex-wrap gap-2">
            {card.potential_impacted_areas.map((area) => {
              const checked = areas.includes(area.id);
              return (
                <label
                  key={area.id}
                  className={cn(
                    "inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-lg border px-3 text-sm",
                    checked ? "border-primary bg-primary/10" : "border-border",
                  )}
                >
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={() => {
                      setAreas((current) =>
                        current.includes(area.id)
                          ? current.filter((value) => value !== area.id)
                          : [...current, area.id],
                      );
                      resetKey();
                    }}
                    className="size-4"
                  />
                  {area.name}
                </label>
              );
            })}
          </div>
        </fieldset>
      ) : null}

      {readOnly ? (
        <p role="note" className="rounded-lg border border-secondary bg-accent p-3 text-sm">
          Modo Camaleão: só visualização. Volte para &quot;Minha visão&quot; para abrir um protocolo
          de verdade.
        </p>
      ) : null}

      <AlertDialog>
        <AlertDialogTrigger asChild>
          <Button size="lg" className="min-h-12 w-full text-base" disabled={!canStart}>
            {start.isPending ? (
              <Loader2 className="animate-spin" aria-hidden="true" />
            ) : (
              <PlayCircle aria-hidden="true" />
            )}
            Iniciar protocolo
          </Button>
        </AlertDialogTrigger>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Abrir protocolo: {cardDisplayName(card.name)}?</AlertDialogTitle>
            <AlertDialogDescription>
              O dono do card ({ownerName(card)}) vai ser responsável por conduzir a resolução. O
              horário oficial é o do servidor.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Voltar</AlertDialogCancel>
            <AlertDialogAction onClick={() => void submit()}>Sim, abrir</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </form>
  );
}
