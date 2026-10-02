import { useState } from "react";
import { Ban, CheckCircle2, CircleDot, Clock3, Hourglass, Loader2, XCircle } from "lucide-react";
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
import { useCancelTreatment, useCloseMyPart } from "@/lib/queries";
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

/** Concluído e Cancelar (D-64/D-66), cada um com confirmação explícita. */
export function TreatmentActions({
  treatment,
  onChanged,
}: {
  treatment: SafraTreatment;
  onChanged?: (updated: SafraTreatment) => void;
}) {
  const closePart = useCloseMyPart();
  const cancel = useCancelTreatment();
  const [reason, setReason] = useState("");
  const [cancelOpen, setCancelOpen] = useState(false);
  const busy = closePart.isPending || cancel.isPending;
  const isOwner = treatment.my_role === "OWNER";

  if (!treatment.can_close_my_part && !treatment.can_cancel) return null;

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
                Esta ação não pode ser desfeita.
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
