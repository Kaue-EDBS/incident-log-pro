// SAFRA-M05 — entrega imediata dos avisos que o banco colocou na fila.
// PROVISÓRIO (D-121): usa a sessão do próprio usuário corporativo para pegar a fila
// (funções *_for_session, que exigem conta corporativa) e envia pela conexão Outlook
// vinculada ao projeto, assinando como a caixa compartilhada oficial.
// Será trocado pelo App Registration da TI.
import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const GATEWAY_URL = "https://connector-gateway.lovable.dev/microsoft_outlook";
const MAIL_SENDER = "painel.safra@editoradobrasil.com.br";

type Claimed = { id: string; to: string; subject: string; body: string; attempt: number };

export type DeliveryResult = {
  status: "ok" | "disabled" | "error";
  sent: number;
  failed: number;
  code?: string;
};

export const deliverQueuedNotifications = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<DeliveryResult> => {
    const lovableKey = process.env["LOVABLE_API_KEY"];
    const outlookKey = process.env["MICROSOFT_OUTLOOK_API_KEY"];
    if (!lovableKey || !outlookKey) {
      return { status: "disabled", sent: 0, failed: 0, code: "MISSING_CONNECTOR_KEYS" };
    }

    const rpc = context.supabase.rpc as unknown as (
      fn: string,
      args: Record<string, unknown>,
    ) => PromiseLike<{ data: unknown; error: { code?: string; message: string } | null }>;

    const { data, error } = await rpc("safra_notifications_claim_for_session", { p_limit: 20 });
    if (error) {
      console.error("notifications claim failed:", error.code, error.message);
      return { status: "error", sent: 0, failed: 0, code: `CLAIM_${error.code ?? "UNKNOWN"}` };
    }
    const notices = (data ?? []) as Claimed[];

    let sent = 0;
    let failed = 0;
    for (const n of notices) {
      let ok = false;
      let reason: string | null = null;
      try {
        const res = await fetch(`${GATEWAY_URL}/me/sendMail`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${lovableKey}`,
            "X-Connection-Api-Key": outlookKey,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              subject: n.subject,
              body: { contentType: "Text", content: n.body },
              from: { emailAddress: { address: MAIL_SENDER } },
              toRecipients: [{ emailAddress: { address: n.to } }],
            },
            saveToSentItems: false,
          }),
        });
        ok = res.ok;
        if (!ok) {
          reason = `HTTP ${res.status}: ${(await res.text()).slice(0, 300)}`;
          console.error("notification send failed:", reason);
        }
      } catch (e) {
        reason = e instanceof Error ? e.message : "NETWORK_ERROR";
      }
      const rep = await rpc("safra_notifications_report_for_session", {
        p_id: n.id,
        p_ok: ok,
        p_error: reason,
      });
      if (rep.error) console.error("notification report failed:", rep.error.code, rep.error.message);
      if (ok) sent += 1;
      else failed += 1;
    }
    return { status: "ok", sent, failed };
  });
