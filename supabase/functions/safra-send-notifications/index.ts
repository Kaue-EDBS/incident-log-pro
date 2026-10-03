// SAFRA-M05 — função de envio dos avisos (Supabase Edge Function, Deno).
// Envia pelo aplicativo do TI (MS_TENANT_ID, MS_CLIENT_ID, MS_CLIENT_SECRET) ou, até lá, pela
// conexão Microsoft Outlook do Lovable (D-133). Remetente: painel.safra@editoradobrasil.com.br
// (MAIL_SENDER só sobrescreve). Chamada a cada 2 minutos pelo agendamento do banco. Sem nenhuma
// das duas configurações, responde "disabled" e não mexe na fila. A resposta só traz contagens.
import { createClient } from "npm:@supabase/supabase-js@2";
import { readConfig, runOnce, type ClaimedNotice } from "./sender.ts";

declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Response | Promise<Response>): void;
};

Deno.serve(async (request) => {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    return Response.json({ status: "disabled" }, { status: 503 });
  }
  const db = createClient(url, serviceKey, { auth: { persistSession: false } });

  // D-141: só o agendador do banco chama (senha interna gerada no Vault do próprio banco).
  const { data: allowed, error: tokenError } = await db.rpc("safra_sender_token_valid", {
    p_token: request.headers.get("x-safra-sender-token") ?? "",
  });
  if (tokenError || allowed !== true) {
    return Response.json({ status: "unauthorized" }, { status: 401 });
  }

  const result = await runOnce(
    readConfig((name) => Deno.env.get(name)),
    {
      claim: async (limit) => {
        const { data, error } = await db.rpc("safra_notifications_claim", { p_limit: limit });
        if (error) throw new Error(error.message);
        return (data ?? []) as ClaimedNotice[];
      },
      report: async (id, ok, reason) => {
        const { error } = await db.rpc("safra_notifications_report", {
          p_id: id,
          p_ok: ok,
          p_error: reason,
        });
        if (error) throw new Error(error.message);
      },
      fetch: (input, init) => fetch(input, init),
    },
    50,
  );

  // Pública: devolve só contagens (o que falta de configuração não sai daqui).
  if (result.status === "disabled") return Response.json({ status: "disabled" }, { status: 503 });
  return Response.json(result);
});
