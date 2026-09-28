import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useRef, useState } from "react";
import {
  AlertTriangle,
  Building2,
  CheckCircle2,
  Clock3,
  Loader2,
  PlayCircle,
  RefreshCw,
  ShieldCheck,
  UserRound,
} from "lucide-react";
import { toast } from "sonner";
import { LiveTimer } from "@/components/LiveTimer";
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
import { Textarea } from "@/components/ui/textarea";
import { useSafraStartCatalog, useSafraStartTreatment } from "@/lib/safra-queries";
import type { SafraStartResult } from "@/lib/safra";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/tratativas/nova")({
  head: () => ({
    meta: [
      { title: "Abrir Protocolo | Painel Safra" },
      {
        name: "description",
        content: "Inicie uma tratativa Safra a partir de um cenário publicado.",
      },
      { property: "og:title", content: "Abrir Protocolo | Painel Safra" },
      {
        property: "og:description",
        content: "START governado, transacional e rastreável para os cenários da Safra.",
      },
    ],
  }),
  component: StartSafraTreatment,
});

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "medium",
    timeZone: "America/Sao_Paulo",
  }).format(new Date(value));
}

function errorMessage(error: unknown) {
  if (error && typeof error === "object" && "message" in error) {
    const message = String((error as { message: unknown }).message);
    if (message.includes("SAFRA_START_FORBIDDEN")) {
      return "Sua sessão não está autorizada para iniciar protocolos da Safra.";
    }
    if (message.includes("SAFRA_SCENARIO_NOT_STARTABLE")) {
      return "Este cenário não está ativo com uma versão publicada.";
    }
    if (message.includes("SAFRA_INVALID_IMPACTED_AREA")) {
      return "Uma das áreas selecionadas não pertence à versão publicada deste cenário.";
    }
    if (message.includes("SAFRA_START_IDEMPOTENCY_CONFLICT")) {
      return "A tentativa anterior usou a mesma chave com dados diferentes. Revise e tente novamente.";
    }
  }
  return "Não foi possível iniciar a tratativa.";
}

function ResultCard({ result, onReset }: { result: SafraStartResult; onReset: () => void }) {
  return (
    <section
      aria-live="polite"
      className="rounded-2xl border border-[color:var(--turquoise)]/40 bg-[color:var(--turquoise)]/5 p-6"
    >
      <div className="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
        <div className="space-y-3">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="size-5 text-[color:var(--turquoise)]" />
            <p className="font-semibold">Tratativa iniciada</p>
          </div>
          <div>
            <p className="text-lg font-semibold">
              {result.scenario.code} · {result.scenario.name}
            </p>
            <p className="mt-1 text-sm text-muted-foreground">
              START oficial em {formatDateTime(result.opened_at)}
            </p>
          </div>
          <div className="flex flex-wrap gap-x-6 gap-y-2 text-sm">
            <span>
              <strong>Owner:</strong> {result.owner.display_name ?? result.owner.corporate_email}
            </span>
            <span>
              <strong>Área:</strong> {result.responsible_area.name}
            </span>
            <span>
              <strong>Versão:</strong> v{result.scenario.version_no}
            </span>
          </div>
          <p className="break-all text-xs text-muted-foreground">
            Treatment ID: {result.treatment_id}
          </p>
          {result.idempotent_replay ? (
            <p className="text-xs text-muted-foreground">
              Retry reconhecido: a mesma tratativa foi reutilizada, sem duplicação.
            </p>
          ) : null}
        </div>

        <div className="min-w-44 rounded-xl border border-border bg-card p-4 text-center">
          <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
            Tempo em andamento
          </p>
          <LiveTimer since={result.opened_at} className="mt-2 text-2xl font-semibold" />
        </div>
      </div>

      <div className="mt-5 border-t border-border pt-5">
        <p className="text-sm font-medium">SLAs estruturados desta versão</p>
        {result.slas.length ? (
          <div className="mt-3 grid gap-3 md:grid-cols-2">
            {result.slas.map((sla) => (
              <div key={sla.sla_id} className="rounded-xl border border-border bg-card p-4">
                <div className="flex items-center justify-between gap-3">
                  <p className="font-medium">{sla.label}</p>
                  <span className="rounded-full border border-border px-2 py-1 text-xs">
                    {sla.state}
                  </span>
                </div>
                <p className="mt-2 text-xs text-muted-foreground">{sla.target_text}</p>
              </div>
            ))}
          </div>
        ) : (
          <p className="mt-2 text-sm text-muted-foreground">
            Nenhum SLA estruturado está publicado nesta versão. O sistema não inferiu relógios a
            partir do texto.
          </p>
        )}
      </div>

      <button
        type="button"
        onClick={onReset}
        className="mt-6 inline-flex items-center gap-2 rounded-lg border border-border bg-card px-4 py-2 text-sm font-medium hover:bg-muted"
      >
        <RefreshCw className="size-4" />
        Abrir outra tratativa
      </button>
    </section>
  );
}

function StartSafraTreatment() {
  const { data: scenarios = [], isLoading, isError, refetch } = useSafraStartCatalog();
  const startTreatment = useSafraStartTreatment();

  const [scenarioId, setScenarioId] = useState("");
  const [impactSummary, setImpactSummary] = useState("");
  const [impactedAreaIds, setImpactedAreaIds] = useState<string[]>([]);
  const [result, setResult] = useState<SafraStartResult | null>(null);
  const retryKey = useRef<string | null>(null);

  const selected = useMemo(
    () => scenarios.find((scenario) => scenario.scenario_id === scenarioId) ?? null,
    [scenarios, scenarioId],
  );

  const resetCommandKey = () => {
    retryKey.current = null;
  };

  const selectScenario = (id: string) => {
    setScenarioId(id);
    setImpactSummary("");
    setImpactedAreaIds([]);
    setResult(null);
    resetCommandKey();
  };

  const toggleArea = (id: string) => {
    setImpactedAreaIds((current) =>
      current.includes(id) ? current.filter((value) => value !== id) : [...current, id],
    );
    resetCommandKey();
  };

  const handleStart = async () => {
    if (!selected) {
      toast.error("Selecione um cenário publicado.");
      return;
    }

    const idempotencyKey = retryKey.current ?? globalThis.crypto.randomUUID();
    retryKey.current = idempotencyKey;

    try {
      const created = await startTreatment.mutateAsync({
        scenarioId: selected.scenario_id,
        idempotencyKey,
        impactSummary: impactSummary.trim() || null,
        impactedAreaIds,
      });
      retryKey.current = null;
      setResult(created);
      toast.success("START registrado. A tratativa está em andamento.");
    } catch (error) {
      toast.error(errorMessage(error));
    }
  };

  if (result) {
    return (
      <div className="mx-auto max-w-5xl space-y-6">
        <header>
          <h1 className="text-2xl font-semibold tracking-tight">Abrir Protocolo</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            O START foi persistido com ator, versão e horário definidos no servidor.
          </p>
        </header>
        <ResultCard
          result={result}
          onReset={() => {
            setResult(null);
            setScenarioId("");
            setImpactSummary("");
            setImpactedAreaIds([]);
            resetCommandKey();
          }}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Abrir Protocolo</h1>
        <p className="text-sm text-muted-foreground">
          Selecione um cenário publicado, revise o protocolo e confirme o START da tratativa.
        </p>
      </header>

      {isLoading ? (
        <div className="flex items-center gap-3 rounded-xl border border-border bg-card p-6 text-sm text-muted-foreground">
          <Loader2 className="size-4 animate-spin" />
          Carregando cenários publicados...
        </div>
      ) : null}

      {isError ? (
        <div role="alert" className="rounded-xl border border-destructive/30 bg-destructive/10 p-5">
          <p className="font-medium text-destructive">
            Não foi possível carregar o catálogo Safra.
          </p>
          <button
            type="button"
            onClick={() => void refetch()}
            className="mt-3 rounded-lg border border-border bg-card px-3 py-2 text-sm font-medium"
          >
            Tentar novamente
          </button>
        </div>
      ) : null}

      {!isLoading && !isError ? (
        <section className="space-y-3">
          <div>
            <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
              1. Cenário
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Apenas cenários ACTIVE com versão PUBLISHED aparecem aqui.
            </p>
          </div>

          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {scenarios.map((scenario) => (
              <button
                key={scenario.scenario_id}
                type="button"
                onClick={() => selectScenario(scenario.scenario_id)}
                className={cn(
                  "rounded-xl border border-border bg-card p-4 text-left transition-all hover:border-primary/60",
                  scenarioId === scenario.scenario_id && "border-primary ring-1 ring-primary",
                )}
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-xs font-semibold text-primary">{scenario.code}</p>
                    <p className="mt-1 font-semibold">{scenario.name}</p>
                  </div>
                  <span className="rounded-full border border-border px-2 py-1 text-[11px] text-muted-foreground">
                    v{scenario.version_no}
                  </span>
                </div>
                <div className="mt-4 space-y-1 text-xs text-muted-foreground">
                  <p>Owner: {scenario.owner.display_name ?? scenario.owner.corporate_email}</p>
                  <p>Área: {scenario.responsible_area.name}</p>
                  <p>
                    Criticidade:{" "}
                    <span className="font-medium text-foreground">
                      {scenario.criticality ?? "Não definida"}
                    </span>
                  </p>
                </div>
              </button>
            ))}
          </div>
        </section>
      ) : null}

      {selected ? (
        <>
          <section className="grid gap-4 lg:grid-cols-[1fr_0.8fr]">
            <div className="rounded-xl border border-border bg-card p-5">
              <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                2. Revise o protocolo
              </h2>
              <div className="mt-4 space-y-5">
                <div>
                  <p className="text-xs font-medium text-muted-foreground">Gatilho registrado</p>
                  <p className="mt-1 text-sm">
                    {selected.trigger_description ?? "Não documentado"}
                  </p>
                </div>
                <div>
                  <p className="text-xs font-medium text-muted-foreground">Protocolo vigente</p>
                  <p className="mt-1 whitespace-pre-line text-sm leading-6">
                    {selected.protocol_text ?? "Não documentado"}
                  </p>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="rounded-xl border border-border bg-card p-5">
                <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                  Snapshot do START
                </h2>
                <div className="mt-4 space-y-3 text-sm">
                  <div className="flex gap-3">
                    <UserRound className="mt-0.5 size-4 text-muted-foreground" />
                    <div>
                      <p className="text-xs text-muted-foreground">Owner</p>
                      <p className="font-medium">
                        {selected.owner.display_name ?? selected.owner.corporate_email}
                      </p>
                    </div>
                  </div>
                  <div className="flex gap-3">
                    <Building2 className="mt-0.5 size-4 text-muted-foreground" />
                    <div>
                      <p className="text-xs text-muted-foreground">Área responsável</p>
                      <p className="font-medium">{selected.responsible_area.name}</p>
                    </div>
                  </div>
                  <div className="flex gap-3">
                    <ShieldCheck className="mt-0.5 size-4 text-muted-foreground" />
                    <div>
                      <p className="text-xs text-muted-foreground">Criticidade</p>
                      <p className="font-medium">{selected.criticality ?? "Não definida"}</p>
                    </div>
                  </div>
                  <div className="flex gap-3">
                    <Clock3 className="mt-0.5 size-4 text-muted-foreground" />
                    <div>
                      <p className="text-xs text-muted-foreground">SLAs estruturados</p>
                      <p className="font-medium">{selected.structured_sla_count}</p>
                    </div>
                  </div>
                </div>
              </div>

              {selected.active_treatment_count > 0 ? (
                <div className="rounded-xl border border-[color:var(--warning)]/40 bg-[color:var(--warning)]/10 p-4">
                  <div className="flex gap-2">
                    <AlertTriangle className="mt-0.5 size-4 text-[color:var(--warning)]" />
                    <div>
                      <p className="text-sm font-medium">
                        {selected.active_treatment_count} tratativa(s) já ativa(s)
                      </p>
                      <p className="mt-1 text-xs text-muted-foreground">
                        Isso não bloqueia o START enquanto a regra de simultaneidade GI-SAFRA-004
                        estiver aberta. Duplo clique/retry do mesmo comando continua idempotente.
                      </p>
                    </div>
                  </div>
                </div>
              ) : null}
            </div>
          </section>

          <section className="rounded-xl border border-border bg-card p-5">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
              3. Contexto real da ocorrência
            </h2>

            {selected.potential_impacted_areas.length ? (
              <fieldset className="mt-4">
                <legend className="text-sm font-medium">Áreas realmente impactadas</legend>
                <p className="mt-1 text-xs text-muted-foreground">
                  Selecione somente as áreas afetadas nesta ocorrência.
                </p>
                <div className="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                  {selected.potential_impacted_areas.map((area) => (
                    <label
                      key={area.id}
                      className="flex cursor-pointer items-center gap-3 rounded-lg border border-border p-3 text-sm"
                    >
                      <input
                        type="checkbox"
                        checked={impactedAreaIds.includes(area.id)}
                        onChange={() => toggleArea(area.id)}
                        className="size-4 rounded border-border"
                      />
                      <span>{area.name}</span>
                    </label>
                  ))}
                </div>
              </fieldset>
            ) : (
              <p className="mt-4 text-sm text-muted-foreground">
                Esta versão não possui áreas potenciais adicionais cadastradas.
              </p>
            )}

            <label className="mt-5 block space-y-2">
              <span className="text-sm font-medium">Resumo do impacto observado</span>
              <Textarea
                value={impactSummary}
                maxLength={2000}
                onChange={(event) => {
                  setImpactSummary(event.target.value);
                  resetCommandKey();
                }}
                placeholder="Descreva apenas o que já foi observado nesta ocorrência. Não é necessário inferir causa."
                rows={4}
              />
              <span className="block text-right text-xs text-muted-foreground">
                {impactSummary.length}/2000
              </span>
            </label>
          </section>

          <section className="rounded-xl border border-primary/20 bg-primary/5 p-5">
            <div className="flex flex-col gap-5 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <h2 className="font-semibold">4. Confirmar START</h2>
                <p className="mt-1 max-w-3xl text-sm text-muted-foreground">
                  O backend vai congelar a versão PUBLISHED, o owner e a área responsável atuais.
                  Ator, timestamp e correlation ID serão gerados no servidor. A tela não envia
                  criticidade, owner, versão ou horário.
                </p>
              </div>

              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <button
                    type="button"
                    disabled={startTreatment.isPending}
                    className="inline-flex min-w-52 items-center justify-center gap-2 rounded-xl bg-destructive px-5 py-3 text-sm font-bold text-destructive-foreground hover:brightness-95 disabled:opacity-60"
                  >
                    {startTreatment.isPending ? (
                      <Loader2 className="size-4 animate-spin" />
                    ) : (
                      <PlayCircle className="size-5" />
                    )}
                    Iniciar tratativa
                  </button>
                </AlertDialogTrigger>

                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Confirmar abertura do protocolo?</AlertDialogTitle>
                    <AlertDialogDescription>
                      Você está iniciando {selected.code} · {selected.name}. O START cria uma
                      tratativa ACTIVE e registra TREATMENT_OPENED com horário oficial do servidor.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Voltar e revisar</AlertDialogCancel>
                    <AlertDialogAction
                      onClick={() => void handleStart()}
                      disabled={startTreatment.isPending}
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                    >
                      Confirmar START
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </div>
          </section>
        </>
      ) : null}
    </div>
  );
}
