// SAFRA-M05 — função de envio dos avisos (Supabase Edge Function, Deno).
// Ativação depois do chamado do TI: configurar MS_TENANT_ID, MS_CLIENT_ID e MS_CLIENT_SECRET nos
// segredos do projeto (remetente padrão: painel.safra@editoradobrasil.com.br; MAIL_SENDER só
// sobrescreve) e agendar a chamada (migration de
// ativação). Sem essas configurações, a função responde "disabled" e não mexe na fila.
import { createClient } from "npm:@supabase/supabase-js@2";
import { readConfig, runOnce, type ClaimedNotice } from "./sender.ts";

declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Response | Promise<Response>): void;
};

Deno.serve(async () => {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    return Response.json({ status: "disabled", missing: ["SUPABASE_URL"] }, { status: 503 });
  }
  const db = createClient(url, serviceKey, { auth: { persistSession: false } });

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
      fetch,
    },
  );

  return Response.json(result, { status: result.status === "disabled" ? 503 : 200 });
});
