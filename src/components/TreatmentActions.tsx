import { useEffect, useMemo, useState } from "react";
import {
  Ban,
  CheckCircle2,
  CircleDot,
  Clock3,
  Hourglass,
  Loader2,
  Undo2,
  XCircle,
} from "lucide-react";
import { toast } from "sonner";
import { useViewer } from "@/lib/chameleon";
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
import { useCancelTreatment, useCloseMyPart, useUndoMyPart } from "@/lib/queries";
import { SITUATION_LABEL, safraErrorMessage } from "@/lib/safra";
import type { SafraSituation, SafraTreatment } from "@/lib/safra";
import { cn } from "@/lib/utils";

const SITUATION_STYLE: Record<SafraSituation, { icon: typeof CircleDot; className: string }> = {
  EM_ANDAMENTO: { icon: CircleDot, className: "border-primary/40 bg-primary/10 text-primary" },
  AGUARDANDO_DONO: {
    icon: Hourglass,
    className: "border-warning/50 bg-warning/15 text-foreground",
  },
  AGUARDANDO_SOLICITANTE: {
    icon: Clock3,
    className: "border-warning/50 bg-warning/15 text-foreground",
  },
  ENCERRADO: { icon: CheckCircle2, className: "border-success/50 bg-success/15 text-foreground" },
  CANCELADO: { icon: XCircle, className: "border-border bg-muted text-muted-foreground" },
};

/** Situação sempre com ícone e texto, nunca só cor. */
export function SituationBadge({ situation }: { situation: SafraSituation }) {
  const { icon: Icon, className } = SITUATION_STYLE[situation];
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-semibold",
        className,
      )}
    >
      <Icon className="size-3.5" aria-hidden="true" />
      {SITUATION_LABEL[situation]}
    </span>
  );
}

const MIN_REASON = 10;

function formatTime(iso: string) {
  return new Date(iso).toLocaleTimeString("pt-BR", {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "America/Sao_Paulo",
  });
}

/** Mostra o "Desfazer" só até o prazo (D-99); o banco confere de novo ao desfazer. */
function useUndoStillOpen(undoUntil: string | null, serverTime: string) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!undoUntil) return;
    const id = window.setInterval(() => setNow(Date.now()), 15000);
    return () => window.clearInterval(id);
  }, [undoUntil]);
  // Corrige a diferença entre o relógio do computador e o do servidor (medida uma vez por resposta).
  const skew = useMemo(() => new Date(serverTime).getTime() - Date.now(), [serverTime]);
  if (!undoUntil) return false;
  return now + skew < new Date(undoUntil).getTime();
}

/** Concluído, Desfazer e Cancelar (D-64/D-66/D-99), cada um com confirmação explícita. */
export function TreatmentActions({
  treatment,
  onChanged,
}: {
  treatment: SafraTreatment;
  onChanged?: (updated: SafraTreatment) => void;
}) {
  const closePart = useCloseMyPart();
  const undoPart = useUndoMyPart();
  const cancel = useCancelTreatment();
  const undoOpen = useUndoStillOpen(
    treatment.can_undo_my_part ? treatment.undo_until : null,
    treatment.server_time,
  );
  const [reason, setReason] = useState("");
  const [cancelOpen, setCancelOpen] = useState(false);
  const busy = closePart.isPending || cancel.isPending || undoPart.isPending;
  const isOwner = treatment.my_role === "OWNER";
  const { readOnly } = useViewer();

  const canUndo = treatment.can_undo_my_part && undoOpen;

  // Modo Camaleão é só leitura: nenhuma ação sobre protocolo (D-92).
  if (readOnly) return null;
  if (!treatment.can_close_my_part && !treatment.can_cancel && !canUndo) return null;

  const confirmUndo = async () => {
    try {
      const updated = await undoPart.mutateAsync(treatment.treatment_id);
      onChanged?.(updated);
      toast.success(`Sua conclusão do protocolo ${updated.protocol_number} foi desfeita.`);
    } catch (error) {
      toast.error(safraErrorMessage(error, "Não foi possível desfazer agora. Tente de novo."));
    }
  };

  const confirmClose = async () => {
    try {
      const updated = await closePart.mutateAsync(treatment.treatment_id);
      onChanged?.(updated);
      toast.success(
        updated.situation === "ENCERRADO"
          ? `Protocolo ${updated.protocol_number} encerrado.`
          : `Sua parte do protocolo ${updated.protocol_number} foi concluída.`,
      );
    } catch (error) {
      toast.error(safraErrorMessage(error, "Não foi possível concluir agora. Tente de novo."));
    }
  };

  const confirmCancel = async () => {
    try {
      const updated = await cancel.mutateAsync({
        treatmentId: treatment.treatment_id,
        reason: reason.trim(),
      });
      setCancelOpen(false);
      setReason("");
      onChanged?.(updated);
      toast.success(`Protocolo ${updated.protocol_number} cancelado.`);
    } catch (error) {
      toast.error(safraErrorMessage(error, "Não foi possível cancelar agora. Tente de novo."));
    }
  };

  return (
    <div className="flex flex-wrap gap-3">
      {treatment.can_close_my_part ? (
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button size="lg" className="min-h-11 px-6" disabled={busy}>
              {closePart.isPending ? (
                <Loader2 className="animate-spin" aria-hidden="true" />
              ) : (
                <CheckCircle2 aria-hidden="true" />
              )}
              Concluído
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Concluir o protocolo {treatment.protocol_number}?</AlertDialogTitle>
              <AlertDialogDescription>
                {isOwner
                  ? "Você confirma, como dono do card, que o problema foi resolvido."
                  : "Você confirma que o problema foi resolvido do seu lado. O dono do card também confirma a parte dele."}{" "}
                Você pode desfazer em até 5 minutos, enquanto a outra parte não concluir.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Voltar</AlertDialogCancel>
              <AlertDialogAction onClick={() => void confirmClose()}>
                Sim, concluir
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      ) : null}

      {canUndo && treatment.undo_until ? (
        <Button
          size="lg"
          variant="outline"
          className="h-auto min-h-11 whitespace-normal px-6 text-left"
          disabled={busy}
          onClick={() => void confirmUndo()}
        >
          {undoPart.isPending ? (
            <Loader2 className="animate-spin" aria-hidden="true" />
          ) : (
            <Undo2 aria-hidden="true" />
          )}
          Desfazer conclusão (até {formatTime(treatment.undo_until)})
        </Button>
      ) : null}

      {treatment.can_cancel ? (
        <AlertDialog open={cancelOpen} onOpenChange={setCancelOpen}>
          <AlertDialogTrigger asChild>
            <Button size="lg" variant="outline" className="min-h-11 px-6" disabled={busy}>
              <Ban aria-hidden="true" />
              Cancelar protocolo
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Cancelar o protocolo {treatment.protocol_number}?</AlertDialogTitle>
              <AlertDialogDescription>
                Cancelar é para protocolo aberto por engano ou que não era um problema. Ele não
                conta como resolvido. Esta ação não pode ser desfeita.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <label className="block space-y-2">
              <span className="text-sm font-medium">Motivo do cancelamento (obrigatório)</span>
              <Textarea
                value={reason}
                maxLength={1000}
                rows={3}
                onChange={(event) => setReason(event.target.value)}
                placeholder="Ex.: abri no card errado; o problema era de outra área."
                aria-describedby={`cancel-hint-${treatment.treatment_id}`}
              />
              <span
                id={`cancel-hint-${treatment.treatment_id}`}
                className="block text-xs text-muted-foreground"
              >
                Pelo menos {MIN_REASON} caracteres.
              </span>
            </label>
            <AlertDialogFooter>
              <AlertDialogCancel>Voltar</AlertDialogCancel>
              <AlertDialogAction
                className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                disabled={reason.trim().length < MIN_REASON || cancel.isPending}
                onClick={(event) => {
                  event.preventDefault();
                  void confirmCancel();
                }}
              >
                {cancel.isPending ? <Loader2 className="size-4 animate-spin" /> : null}
                Sim, cancelar
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      ) : null}
    </div>
  );
}
