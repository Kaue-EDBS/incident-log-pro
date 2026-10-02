import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { Loader2, Send } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { useViewer } from "@/lib/chameleon";
import { formatDateTime } from "@/lib/metrics";
import {
  useOperationalAreas,
  useProposalAction,
  useProposals,
  type Proposal,
  type ProposalsData,
} from "@/lib/queries";
import { safraErrorMessage } from "@/lib/safra";
import { CollapsibleSection } from "@/components/CollapsibleSection";
import { ConfirmButton } from "@/components/ConfirmButton";

export const Route = createFileRoute("/propostas")({
  head: () => ({
    meta: [
      { title: "Sugerir card | Painel Safra" },
      { name: "description", content: "Proponha um card novo para a Safra." },
    ],
  }),
  component: Proposals,
});

const STATUS_LABEL: Record<Proposal["status"], string> = {
  SUBMITTED: "Aguardando o Jair encaminhar aos donos de card",
  OWNER_CONSULTATION: "Com os donos de card, para definir quem assume",
  OWNER_DEFINED: "Dono definido: quem propôs completa o conteúdo",
  CONTENT_SUBMITTED: "Aguardando aprovação",
  APPROVED: "Aprovada: aguardando a publicação por um administrador",
  PUBLISHED: "Publicada",
  REJECTED: "Recusada",
};

const EVENT_LABEL: Record<string, string> = {
  SUBMITTED: "Proposta enviada",
  FORWARDED: "Encaminhada aos donos de card",
  OWNER_ACCEPTED: "Aceitou ser dono",
  OWNER_DECLINED: "Não aceitou ser dono",
  OWNER_DEFINED: "Dono definido",
  CONTENT_SUBMITTED: "Conteúdo enviado",
  APPROVED: "Aprovada",
  PUBLISHED: "Publicada",
  REJECTED: "Recusada",
};

const fieldClass = "min-h-10 w-full rounded-md border border-input bg-background px-3 text-sm";

function useRun() {
  const action = useProposalAction();
  const run = async (name: string, args: Record<string, unknown>, done: string) => {
    try {
      await action.mutateAsync({ name, args });
      toast.success(done);
      return true;
    } catch (error) {
      toast.error(safraErrorMessage(error, "Não foi possível agora. Tente de novo."));
      return false;
    }
  };
  return { run, busy: action.isPending };
}

function NewProposalForm({ me }: { me: ProposalsData["me"] }) {
  const { run, busy } = useRun();
  const [title, setTitle] = useState("");
  const [problem, setProblem] = useState("");
  const [impact, setImpact] = useState("");
  const ready =
    title.trim().length >= 5 && problem.trim().length >= 10 && impact.trim().length >= 10;

  return (
    <CollapsibleSection
      id="new-title"
      title="Propor um card novo"
      className="space-y-4"
      titleClassName="text-lg"
    >
      <p className="text-sm text-muted-foreground">
        Em nome de <strong className="text-foreground">{me.name}</strong> ({me.email}). O Jair
        recebe a proposta e pede aos donos de card que digam quem assume.
      </p>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">Título</span>
        <span className="block text-xs text-muted-foreground">Pelo menos 5 caracteres.</span>
        <input
          className={fieldClass}
          value={title}
          maxLength={150}
          onChange={(e) => setTitle(e.target.value)}
        />
      </label>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">Qual é o problema?</span>
        <span className="block text-xs text-muted-foreground">Pelo menos 10 caracteres.</span>
        <Textarea
          rows={3}
          maxLength={3000}
          value={problem}
          onChange={(e) => setProblem(e.target.value)}
        />
      </label>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">Como ele afeta a Safra?</span>
        <span className="block text-xs text-muted-foreground">Pelo menos 10 caracteres.</span>
        <Textarea
          rows={3}
          maxLength={3000}
          value={impact}
          onChange={(e) => setImpact(e.target.value)}
        />
      </label>
      <Button
        className="min-h-11"
        disabled={!ready || busy}
        onClick={() =>
          void run(
            "safra_submit_proposal",
            { p_title: title.trim(), p_problem: problem.trim(), p_impact: impact.trim() },
            "Proposta enviada ao Jair.",
          ).then((ok) => {
            if (ok) {
              setTitle("");
              setProblem("");
              setImpact("");
            }
          })
        }
      >
        {busy ? (
          <Loader2 className="animate-spin" aria-hidden="true" />
        ) : (
          <Send aria-hidden="true" />
        )}
        Enviar proposta
      </Button>
    </CollapsibleSection>
  );
}

function ContentForm({ item }: { item: Proposal }) {
  const { run, busy } = useRun();
  const areas = useOperationalAreas(true);
  const [name, setName] = useState(item.scenario_name ?? item.title);
  const [trigger, setTrigger] = useState(item.trigger_description ?? "");
  const [detection, setDetection] = useState(item.detection_description ?? "");
  const [protocol, setProtocol] = useState(item.protocol_text ?? "");
  const [impact, setImpact] = useState(item.expected_impact_summary ?? "");
  const [selected, setSelected] = useState<string[]>(item.impacted_area_ids);
  const ready =
    name.trim().length >= 5 &&
    [trigger, detection, protocol, impact].every((v) => v.trim().length >= 10) &&
    selected.length > 0;

  const text = (label: string, value: string, set: (v: string) => void) => (
    <label className="block space-y-1 text-sm">
      <span className="font-medium">{label}</span>
      <Textarea rows={2} maxLength={3000} value={value} onChange={(e) => set(e.target.value)} />
    </label>
  );

  return (
    <div className="space-y-3 rounded-lg border border-primary/30 bg-primary/5 p-4">
      <p className="text-sm font-medium">Conteúdo do card (você escreve; o Jair aprova)</p>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">Nome do card</span>
        <input
          className={fieldClass}
          value={name}
          maxLength={150}
          onChange={(e) => setName(e.target.value)}
        />
      </label>
      {text("Gatilho: quando acontece?", trigger, setTrigger)}
      {text("Como se detecta?", detection, setDetection)}
      {text("Protocolo: o que fazer?", protocol, setProtocol)}
      {text("Impacto esperado", impact, setImpact)}
      <fieldset className="space-y-1 text-sm">
        <legend className="font-medium">Áreas que podem ser impactadas</legend>
        <div className="flex flex-wrap gap-2">
          {(areas.data ?? []).map((area) => (
            <label
              key={area.id}
              className="inline-flex items-center gap-2 rounded-md border border-border px-2 py-1"
            >
              <input
                type="checkbox"
                checked={selected.includes(area.id)}
                onChange={(e) =>
                  setSelected((current) =>
                    e.target.checked
                      ? [...current, area.id]
                      : current.filter((id) => id !== area.id),
                  )
                }
              />
              {area.name}
            </label>
          ))}
        </div>
      </fieldset>
      <Button
        className="min-h-11"
        disabled={!ready || busy}
        onClick={() =>
          void run(
            "safra_submit_proposal_content",
            {
              p_proposal_id: item.proposal_id,
              p_scenario_name: name.trim(),
              p_trigger: trigger.trim(),
              p_detection: detection.trim(),
              p_protocol: protocol.trim(),
              p_expected_impact: impact.trim(),
              p_impacted_area_ids: selected,
            },
            "Conteúdo enviado para aprovação.",
          )
        }
      >
        Enviar conteúdo
      </Button>
    </div>
  );
}

function RejectBox({ proposalId }: { proposalId: string }) {
  const { run, busy } = useRun();
  const [reason, setReason] = useState("");
  return (
    <div className="flex w-full flex-wrap items-end gap-3 border-t border-border pt-3">
      <label className="block min-w-60 flex-1 space-y-1 text-sm">
        <span className="font-medium">Motivo para recusar (obrigatório)</span>
        <input
          className={fieldClass}
          value={reason}
          maxLength={1000}
          onChange={(e) => setReason(e.target.value)}
        />
      </label>
      <ConfirmButton
        variant="outline"
        label="Recusar proposta"
        title="Recusar esta proposta?"
        description="Quem propôs recebe o motivo por e-mail. A proposta não volta a andar."
        confirmLabel="Sim, recusar"
        disabled={busy || reason.trim().length < 10}
        onConfirm={() =>
          void run(
            "safra_reject_proposal",
            { p_proposal_id: proposalId, p_reason: reason.trim() },
            "Proposta recusada.",
          )
        }
      />
    </div>
  );
}

function GovernanceActions({
  item,
  candidates,
}: {
  item: Proposal;
  candidates: ProposalsData["candidates"];
}) {
  const { run, busy } = useRun();
  const areas = useOperationalAreas(item.can_approve);
  const [owner, setOwner] = useState("");
  const [note, setNote] = useState("");
  const [decision, setDecision] = useState("");
  const [area, setArea] = useState("");

  return (
    <div className="flex flex-wrap items-end gap-3">
      {item.can_forward ? (
        <Button
          className="min-h-11"
          disabled={busy}
          onClick={() =>
            void run(
              "safra_forward_proposal",
              { p_proposal_id: item.proposal_id },
              "Encaminhada aos donos de card.",
            )
          }
        >
          Encaminhar aos donos de card
        </Button>
      ) : null}

      {item.can_respond ? (
        <>
          <label className="block min-w-60 flex-1 space-y-1 text-sm">
            <span className="font-medium">Comentário (opcional)</span>
            <input
              className={fieldClass}
              value={note}
              maxLength={1000}
              onChange={(e) => setNote(e.target.value)}
            />
          </label>
          <Button
            className="min-h-11"
            disabled={busy}
            onClick={() =>
              void run(
                "safra_respond_proposal",
                { p_proposal_id: item.proposal_id, p_accept: true, p_note: note.trim() || null },
                "Você aceitou ser dono.",
              )
            }
          >
            Aceito ser dono
          </Button>
          <ConfirmButton
            variant="outline"
            label="Não aceito"
            title="Não aceitar ser dono deste card?"
            description="O Jair e a gestão veem a sua resposta. Você pode mudar enquanto o dono não for definido."
            confirmLabel="Sim, não aceito"
            disabled={busy}
            onConfirm={() =>
              void run(
                "safra_respond_proposal",
                { p_proposal_id: item.proposal_id, p_accept: false, p_note: note.trim() || null },
                "Resposta registrada.",
              )
            }
          />
        </>
      ) : null}

      {item.can_define_owner ? (
        <div className="w-full space-y-2 rounded-lg border border-border p-3">
          <p className="text-sm">
            Registre o dono entre quem aceitou. Se mais de um aceitou, eles decidem em reunião fora
            do Painel e você registra quem ficou.
          </p>
          <div className="flex flex-wrap items-end gap-3">
            <label className="block space-y-1 text-sm">
              <span className="font-medium">Dono escolhido</span>
              <select
                className={fieldClass}
                value={owner}
                onChange={(e) => setOwner(e.target.value)}
              >
                <option value="">Escolha</option>
                {candidates
                  .filter((c) => item.accepted_principal_ids.includes(c.principal_id))
                  .map((c) => (
                    <option key={c.principal_id} value={c.principal_id}>
                      {c.name}
                    </option>
                  ))}
              </select>
            </label>
            <label className="block min-w-60 flex-1 space-y-1 text-sm">
              <span className="font-medium">Como foi decidido (obrigatório)</span>
              <input
                className={fieldClass}
                value={decision}
                maxLength={1000}
                onChange={(e) => setDecision(e.target.value)}
              />
            </label>
            <Button
              className="min-h-11"
              disabled={busy || !owner || decision.trim().length < 10}
              onClick={() =>
                void run(
                  "safra_define_proposal_owner",
                  {
                    p_proposal_id: item.proposal_id,
                    p_owner_principal_id: owner,
                    p_note: decision.trim(),
                  },
                  "Dono registrado.",
                )
              }
            >
              Registrar dono
            </Button>
          </div>
        </div>
      ) : null}

      {item.can_approve ? (
        <>
          <label className="block space-y-1 text-sm">
            <span className="font-medium">Área responsável</span>
            <select className={fieldClass} value={area} onChange={(e) => setArea(e.target.value)}>
              <option value="">Escolha</option>
              {(areas.data ?? []).map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name}
                </option>
              ))}
            </select>
          </label>
          <ConfirmButton
            label="Aprovar"
            title="Aprovar esta proposta?"
            description="O conteúdo aprovado vai para um administrador publicar como card novo."
            confirmLabel="Sim, aprovar"
            disabled={busy || !area}
            onConfirm={() =>
              void run(
                "safra_approve_proposal",
                { p_proposal_id: item.proposal_id, p_responsible_area_id: area },
                "Proposta aprovada.",
              )
            }
          />
        </>
      ) : null}

      {item.can_reject ? <RejectBox proposalId={item.proposal_id} /> : null}

      {item.can_publish ? (
        <ConfirmButton
          label="Publicar card"
          title={`Publicar o card "${item.scenario_name ?? item.title}"?`}
          description="Ele passa a aparecer para todos no Início e já pode receber protocolos. A versão publicada não muda depois."
          confirmLabel="Sim, publicar"
          disabled={busy}
          onConfirm={() =>
            void run(
              "safra_publish_proposal",
              { p_proposal_id: item.proposal_id },
              "Card publicado.",
            )
          }
        />
      ) : null}
    </div>
  );
}

function ProposalItem({
  item,
  candidates,
  readOnly,
}: {
  item: Proposal;
  candidates: ProposalsData["candidates"];
  readOnly: boolean;
}) {
  return (
    <li>
      <article
        aria-labelledby={`proposal-${item.proposal_id}`}
        className="space-y-3 rounded-xl border border-border bg-card p-5"
      >
        <div>
          <h3 id={`proposal-${item.proposal_id}`} className="text-base font-semibold">
            {item.title}
          </h3>
          <p className="text-sm text-muted-foreground">
            {item.status === "PUBLISHED" && item.published_code
              ? `Publicada como ${item.published_code}`
              : item.mine && item.can_submit_content
                ? "Sua vez: escreva o conteúdo do card"
                : STATUS_LABEL[item.status]}{" "}
            · proposta por {item.proposer_name} em {formatDateTime(item.submitted_at)}
          </p>
        </div>
        <p className="text-sm">{item.problem_description}</p>
        <p className="text-sm text-muted-foreground">Na Safra: {item.safra_impact_description}</p>
        {item.rejection_reason ? (
          <p className="text-sm text-destructive">Recusada: {item.rejection_reason}</p>
        ) : null}
        {item.owner_name ? <p className="text-sm">Dono: {item.owner_name}</p> : null}
        {item.my_response ? (
          <p className="text-sm font-medium">
            Sua resposta: {item.my_response === "ACCEPTED" ? "aceitou ser dono" : "não aceitou"}
            {item.can_respond ? " (dá para mudar enquanto o dono não for definido)" : ""}
          </p>
        ) : null}
        {item.responses.length ? (
          <ul aria-label="Respostas dos donos de card" className="text-sm text-muted-foreground">
            {item.responses.map((r) => (
              <li key={r.name}>
                {r.name}: {r.response === "ACCEPTED" ? "aceitou" : "não aceitou"}
                {r.note ? ` (${r.note})` : ""}
              </li>
            ))}
          </ul>
        ) : null}
        {!readOnly && item.can_submit_content ? <ContentForm item={item} /> : null}
        {!readOnly ? <GovernanceActions item={item} candidates={candidates} /> : null}
        {item.events.length ? (
          <ol
            aria-label="Andamento da proposta"
            className="space-y-1 border-t border-border pt-2 text-xs text-muted-foreground"
          >
            {item.events.map((e, i) => (
              <li key={`${e.occurred_at}-${i}`}>
                {formatDateTime(e.occurred_at)} · {e.actor_name}:{" "}
                {EVENT_LABEL[e.event_type] ?? e.event_type}
                {e.note ? ` (${e.note})` : ""}
              </li>
            ))}
          </ol>
        ) : null}
      </article>
    </li>
  );
}

/** Proposta de card novo (M10, D-60/D-68/D-125 a D-129). */
function Proposals() {
  const { readOnly } = useViewer();
  const query = useProposals();
  // D-135: uma proposta em andamento por pessoa.
  const openOwn = query.data?.items.find(
    (item) => item.mine && item.status !== "PUBLISHED" && item.status !== "REJECTED",
  );

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Sugerir card</h1>
        <p className="text-sm text-muted-foreground">
          Viu um problema da Safra que ainda não tem card? Proponha. O Jair encaminha aos donos de
          card, um deles aceita ser o dono, você escreve o conteúdo, o Jair aprova e um
          administrador publica.
        </p>
      </header>
      {query.isLoading ? (
        <p role="status" className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="size-4 animate-spin" aria-hidden="true" />
          Carregando...
        </p>
      ) : query.isError || !query.data ? (
        <div role="alert" className="flex flex-wrap items-center gap-3 text-sm text-destructive">
          Não foi possível carregar as propostas.
          <Button variant="outline" className="min-h-11" onClick={() => void query.refetch()}>
            Tentar de novo
          </Button>
        </div>
      ) : (
        <>
          {readOnly ? null : openOwn ? (
            <p className="rounded-xl border border-border bg-card p-5 text-sm">
              Você já tem uma proposta em andamento ("{openOwn.title}"). Você poderá enviar outra
              quando ela for publicada ou recusada.
            </p>
          ) : (
            <NewProposalForm me={query.data.me} />
          )}
          <section aria-labelledby="list-title" className="space-y-3">
            <h2 id="list-title" className="text-lg font-semibold">
              Propostas
            </h2>
            {query.data.items.length === 0 ? (
              <p className="rounded-xl border border-dashed border-border bg-card p-6 text-sm text-muted-foreground">
                Nenhuma proposta por aqui.
              </p>
            ) : (
              <ul className="space-y-3">
                {query.data.items.map((item) => (
                  <ProposalItem
                    key={item.proposal_id}
                    item={item}
                    candidates={query.data.candidates}
                    readOnly={readOnly}
                  />
                ))}
              </ul>
            )}
          </section>
        </>
      )}
    </div>
  );
}
