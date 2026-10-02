import { useState } from "react";
import { Loader2, Mail, Send } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CollapsibleSection } from "@/components/CollapsibleSection";
import { useAuth } from "@/integrations/supabase/AuthProvider";
import { useViewer } from "@/lib/chameleon";
import { formatDateTime } from "@/lib/metrics";
import { useNotificationsQueue, useOpsSummary, type NotificationsQueue } from "@/lib/queries";
import { deliverQueuedNotifications } from "@/lib/notifications.functions";

const OWNER_EMAIL = "kaue.pastrello@editoradobrasil.com.br";

/** Fila de avisos por e-mail — só o Kauê vê. Nenhum segredo é mostrado. */
export function NotificationsPanel() {
  const { user } = useAuth();
  const { isPlatformAdmin, readOnly } = useViewer();
  const allowed = isPlatformAdmin && user?.email?.toLowerCase() === OWNER_EMAIL;
  const { data, isLoading, isError, isFetching, refetch } = useOpsSummary(allowed);
  const queue = useNotificationsQueue(allowed);
  const refresh = () => {
    void refetch();
    void queue.refetch();
  };
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
      refresh();
    }
  }

  return (
    <CollapsibleSection
      id="notif-title"
      title="Fila de e-mails"
      icon={<Mail className="size-5 text-primary" aria-hidden="true" />}
    >
      <div className="flex flex-wrap items-center justify-end gap-3">
        <div className="flex gap-2">
          <Button variant="outline" onClick={refresh} disabled={isFetching || queue.isFetching}>
            {isFetching || queue.isFetching ? "Atualizando..." : "Atualizar"}
          </Button>
          {readOnly ? null : (
            <Button onClick={() => void forceSend()} disabled={busy}>
              {busy ? (
                <Loader2 className="size-4 animate-spin" aria-hidden="true" />
              ) : (
                <Send className="size-4" aria-hidden="true" />
              )}
              Forçar envio agora
            </Button>
          )}
        </div>
      </div>
      {isError ? (
        <p role="alert" className="text-sm text-destructive">
          Não foi possível carregar os totais. Tente "Atualizar".
        </p>
      ) : isLoading || !n ? (
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
      <QueueList queue={queue.data} loading={queue.isLoading} failed={queue.isError} />
      <p className="text-xs text-muted-foreground">
        Remetente: painel.safra@editoradobrasil.com.br. O servidor envia sozinho a cada 2 minutos;
        os totais são das últimas 24 h e a lista mostra os 50 e-mails mais recentes.
      </p>
    </CollapsibleSection>
  );
}

const STATUS_LABEL: Record<string, string> = {
  QUEUED: "Na fila",
  SENT: "Enviado",
  FAILED: "Com falha",
};

function QueueList({
  queue,
  loading,
  failed,
}: {
  queue: NotificationsQueue | undefined;
  loading: boolean;
  failed: boolean;
}) {
  if (loading) {
    return (
      <p role="status" className="text-sm text-muted-foreground">
        Carregando a lista...
      </p>
    );
  }
  if (failed || !queue) {
    return (
      <p role="alert" className="text-sm text-destructive">
        Não foi possível carregar a lista de e-mails.
      </p>
    );
  }
  if (queue.items.length === 0) {
    return <p className="text-sm text-muted-foreground">Nenhum e-mail na fila ainda.</p>;
  }
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[640px] text-left text-sm">
        <caption className="sr-only">
          E-mails mais recentes, com a situação e o motivo do erro
        </caption>
        <thead className="text-xs text-muted-foreground">
          <tr>
            <th scope="col" className="py-2 pr-3 font-medium">
              Quando
            </th>
            <th scope="col" className="py-2 pr-3 font-medium">
              Para
            </th>
            <th scope="col" className="py-2 pr-3 font-medium">
              Assunto
            </th>
            <th scope="col" className="py-2 pr-3 font-medium">
              Situação
            </th>
            <th scope="col" className="py-2 font-medium">
              Erro
            </th>
          </tr>
        </thead>
        <tbody>
          {queue.items.map((n) => (
            <tr key={n.id} className="border-t border-border align-top">
              <td className="py-2 pr-3 tabular-nums">{formatDateTime(n.queued_at)}</td>
              <td className="py-2 pr-3">{n.recipient_name ?? n.recipient_email}</td>
              <td className="py-2 pr-3">{n.subject ?? n.notification_type}</td>
              <td className="py-2 pr-3">
                {n.delivery_status === "FAILED" && n.error?.startsWith("EXPIRED")
                  ? "Expirado"
                  : (STATUS_LABEL[n.delivery_status] ?? n.delivery_status)}
                {n.attempts > 1 ? ` (${n.attempts} tentativas)` : ""}
              </td>
              <td className="py-2 text-muted-foreground">{n.error ?? "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
