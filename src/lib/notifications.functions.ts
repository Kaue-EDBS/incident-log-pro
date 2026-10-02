// SAFRA-M05 — entrega imediata dos avisos que o banco colocou na fila.
// PROVISÓRIO (D-132/D-134): usa a sessão de quem está logado para pegar a fila (funções
// *_for_session: só gestão/admins; é o botão "Forçar envio agora"; o envio de rotina é o
// agendado no servidor, D-133) e envia pela conexão Outlook
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

    // bind: rpc usa `this` (o cliente); sem ele a chamada quebra ("reading 'rest'").
    const rpc = context.supabase.rpc.bind(context.supabase) as unknown as (
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
    const started = Date.now();
    for (const n of notices) {
      let ok = false;
      let reason: string | null = null;
      // A trava de cada aviso dura 5 minutos: para de enviar bem antes disso.
      if (Date.now() - started > 40_000) {
        reason = "ROUND_TIME_BUDGET";
      } else
        try {
          const res = await fetch(`${GATEWAY_URL}/me/sendMail`, {
            method: "POST",
            signal: AbortSignal.timeout(15_000),
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
            // Só o status e o código do provedor: o texto do erro pode trazer dados pessoais.
            let code = "";
            try {
              const body = (await res.json()) as { error?: { code?: unknown } };
              if (typeof body?.error?.code === "string") code = ` ${body.error.code.slice(0, 60)}`;
            } catch {
              // corpo vazio ou não JSON
            }
            reason = `HTTP ${res.status}${code}`;
            console.error("notification send failed:", reason);
          } else {
            await res.body?.cancel();
          }
        } catch (e) {
          reason = e instanceof Error && e.name === "TimeoutError" ? "TIMEOUT" : "NETWORK_ERROR";
        }
      const rep = await rpc("safra_notifications_report_for_session", {
        p_id: n.id,
        p_ok: ok,
        p_error: reason,
      });
      if (rep.error)
        console.error("notification report failed:", rep.error.code, rep.error.message);
      if (ok) sent += 1;
      else failed += 1;
    }
    return { status: "ok", sent, failed };
  });
