import { useState } from "react";
import { CalendarCheck2, CalendarX2, Loader2, Undo2 } from "lucide-react";
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
import { useViewer } from "@/lib/chameleon";
import { formatDateTime } from "@/lib/metrics";
import { useEndSeason, useSeason, useStartSeason, useUndoEndSeason } from "@/lib/queries";
import { safraErrorMessage } from "@/lib/safra";
import { CollapsibleSection } from "@/components/CollapsibleSection";

const CONFIRM = "ENCERRAR SAFRA";

/** Marcação da Safra (D-59, D-70, D-118, D-119): só o Kaue vê; o banco confere de novo. */
export function SeasonPanel() {
  const { readOnly } = useViewer();
  const season = useSeason();
  const endSeason = useEndSeason();
  const undoEnd = useUndoEndSeason();
  const startSeason = useStartSeason();
  const [typed, setTyped] = useState("");
  const [open, setOpen] = useState(false);
  const data = season.data;

  if (!data?.can_manage) return null;

  const run = async (action: () => Promise<unknown>, done: string) => {
    try {
      await action();
      toast.success(done);
    } catch (error) {
      toast.error(safraErrorMessage(error, "Não foi possível agora. Tente de novo."));
    }
  };

  const busy = endSeason.isPending || undoEnd.isPending || startSeason.isPending;

  return (
    <CollapsibleSection
      id="season-title"
      title={
        data.open
          ? `Safra: aberta desde ${formatDateTime(data.started_at)}`
          : `Safra: encerrada em ${formatDateTime(data.ended_at)}`
      }
      icon={<CalendarCheck2 className="size-5 text-primary" aria-hidden="true" />}
      className="space-y-4"
      titleClassName="text-lg"
    >
      <p className="text-sm">
        {data.open ? (
          <>
            Safra <strong>aberta</strong> desde {formatDateTime(data.started_at)}.
          </>
        ) : (
          <>
            Safra <strong>encerrada</strong> em {formatDateTime(data.ended_at)} (começou em{" "}
            {formatDateTime(data.started_at)}). Ninguém abre protocolo novo até a próxima começar;
            os que já estavam abertos continuam.
          </>
        )}
      </p>

      {readOnly ? (
        <p className="text-sm text-muted-foreground">
          Modo Camaleão: só visualização. Volte para a sua visão para encerrar ou iniciar a Safra.
        </p>
      ) : data.open ? (
        <AlertDialog
          open={open}
          onOpenChange={(next) => {
            setOpen(next);
            if (!next) setTyped("");
          }}
        >
          <AlertDialogTrigger asChild>
            <Button variant="outline" className="min-h-11" disabled={busy}>
              <CalendarX2 aria-hidden="true" />
              Encerrar Safra
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Encerrar a Safra?</AlertDialogTitle>
              <AlertDialogDescription>
                Ninguém poderá abrir protocolo novo até você iniciar a próxima Safra. Os protocolos
                abertos continuam. Os indicadores fecham o período agora. Você pode desfazer em até
                7 dias, sem perder dados.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <label className="block space-y-2">
              <span className="text-sm font-medium">Digite {CONFIRM} para confirmar</span>
              <input
                className="min-h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
                value={typed}
                onChange={(event) => setTyped(event.target.value)}
                autoComplete="off"
                aria-describedby="season-confirm-hint"
              />
              <span id="season-confirm-hint" className="block text-xs text-muted-foreground">
                Em letras maiúsculas, exatamente assim.
              </span>
            </label>
            <AlertDialogFooter>
              <AlertDialogCancel>Voltar</AlertDialogCancel>
              <AlertDialogAction
                className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                disabled={typed.trim() !== CONFIRM || endSeason.isPending}
                onClick={(event) => {
                  event.preventDefault();
                  void run(() => endSeason.mutateAsync(typed.trim()), "Safra encerrada.").then(() =>
                    setOpen(false),
                  );
                }}
              >
                {endSeason.isPending ? <Loader2 className="size-4 animate-spin" /> : null}
                Encerrar Safra
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      ) : (
        <div className="flex flex-wrap gap-3">
          {data.undo_until ? (
            <Button
              variant="outline"
              className="min-h-11"
              disabled={busy}
              onClick={() => void run(() => undoEnd.mutateAsync(), "Encerramento desfeito.")}
            >
              <Undo2 aria-hidden="true" />
              Desfazer encerramento (até {formatDateTime(data.undo_until)})
            </Button>
          ) : null}
          <Button
            className="min-h-11"
            disabled={busy}
            onClick={() => void run(() => startSeason.mutateAsync(), "Nova Safra iniciada.")}
          >
            <CalendarCheck2 aria-hidden="true" />
            Iniciar nova Safra
          </Button>
        </div>
      )}
    </CollapsibleSection>
  );
}

/** Aviso para todos quando a Safra estiver encerrada (D-118). */
export function SeasonClosedNotice() {
  const season = useSeason();
  if (!season.data || season.data.open) return null;
  return (
    <p role="status" className="rounded-xl border border-warning/50 bg-warning/15 p-4 text-sm">
      A Safra foi encerrada em {formatDateTime(season.data.ended_at)}. A abertura de protocolos
      volta quando a próxima Safra começar. Os protocolos já abertos continuam normalmente.
    </p>
  );
}
