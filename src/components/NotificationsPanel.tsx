import { useState } from "react";
import { Loader2, Mail, Send } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/integrations/supabase/AuthProvider";
import { useViewer } from "@/lib/chameleon";
import { useOpsSummary } from "@/lib/queries";
import { deliverQueuedNotifications } from "@/lib/notifications.functions";

const OWNER_EMAIL = "kaue.pastrello@editoradobrasil.com.br";

/** Fila de avisos por e-mail — só o Kauê vê. Nenhum segredo é mostrado. */
export function NotificationsPanel() {
  const { user } = useAuth();
  const { isPlatformAdmin } = useViewer();
  const allowed = isPlatformAdmin && user?.email?.toLowerCase() === OWNER_EMAIL;
  const { data, isLoading, refetch } = useOpsSummary(allowed);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<string | null>(null);

  if (!allowed) return null;
  const n = data?.notifications;

  async function forceSend() {
    setBusy(true);
    setResult(null);
    try {
      const r = await deliverQueuedNotifications();
      if (r.status === "ok")
        setResult(
          r.sent + r.failed === 0
            ? "Nada na fila para enviar."
            : `Enviados: ${r.sent}. Com falha: ${r.failed}.`,
        );
      else if (r.status === "disabled")
        setResult("Envio desligado: a conexão do Outlook não está disponível.");
      else setResult(`Não foi possível pegar a fila (código ${r.code ?? "desconhecido"}).`);
    } catch {
      setResult("O envio falhou. Tente de novo em instantes.");
    } finally {
      setBusy(false);
      void refetch();
    }
  }

  return (
    <section
      aria-labelledby="notif-title"
      className="space-y-4 rounded-xl border border-border bg-card p-5"
    >
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 id="notif-title" className="flex items-center gap-2 text-lg font-semibold">
          <Mail className="size-5 text-primary" aria-hidden="true" />
          Fila de e-mails (últimas 24 h)
        </h2>
        <div className="flex gap-2">
          <Button variant="outline" onClick={() => void refetch()}>
            Atualizar
          </Button>
          <Button onClick={() => void forceSend()} disabled={busy}>
            {busy ? (
              <Loader2 className="size-4 animate-spin" aria-hidden="true" />
            ) : (
              <Send className="size-4" aria-hidden="true" />
            )}
            Forçar envio agora
          </Button>
        </div>
      </div>
      {isLoading || !n ? (
        <p role="status" className="text-sm text-muted-foreground">
          Carregando...
        </p>
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {[
            ["Na fila", n.queued],
            ["Enviados", n.sent],
            ["Com falha", n.failed],
            ["Expirados", n.expired],
          ].map(([label, value]) => (
            <div key={label} className="rounded-lg border border-border bg-background p-4">
              <p className="text-xs text-muted-foreground">{label}</p>
              <p className="mt-1 text-2xl font-semibold tabular-nums">{value}</p>
            </div>
          ))}
        </div>
      )}
      {result && (
        <p role="status" className="text-sm">
          {result}
        </p>
      )}
      <p className="text-xs text-muted-foreground">
        Remetente: painel.safra@editoradobrasil.com.br. A lista detalhada com o motivo de cada
        erro depende de uma mudança no banco ainda pendente.
      </p>
    </section>
  );
}
