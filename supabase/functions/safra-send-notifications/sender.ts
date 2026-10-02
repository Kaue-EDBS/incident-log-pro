/**
 * SAFRA-M05 — carteiro dos avisos (D-111 a D-114).
 *
 * Pega da fila os avisos prontos (`safra_notifications_claim`), envia cada um pelo Microsoft
 * Graph (`/users/{caixa}/sendMail`) e devolve o resultado (`safra_notifications_report`).
 * O banco decide quem recebe, o texto, as novas tentativas e a expiração; aqui só se envia.
 *
 * Fica desligado (não pega nada da fila) enquanto faltar qualquer configuração do TI.
 */

export type ClaimedNotice = {
  id: string;
  to: string;
  subject: string;
  body: string;
  attempt: number;
};

export type SenderConfig = {
  tenantId: string;
  clientId: string;
  clientSecret: string;
  mailbox: string;
};

export type SenderDeps = {
  claim: (limit: number) => Promise<ClaimedNotice[]>;
  report: (id: string, ok: boolean, error: string | null) => Promise<void>;
  fetch: typeof fetch;
};

export type SenderResult =
  | { status: "disabled"; missing: string[] }
  | { status: "ok"; claimed: number; sent: number; failed: number };

/** Caixa oficial de envio de todos os avisos do Painel (donos de card, usuários etc.). */
export const DEFAULT_MAIL_SENDER = "painel.safra@editoradobrasil.com.br";

const REQUIRED = ["MS_TENANT_ID", "MS_CLIENT_ID", "MS_CLIENT_SECRET"] as const;

/** Lê a configuração; devolve o que falta em vez de inventar valores. */
export function readConfig(env: (name: string) => string | undefined): SenderConfig | string[] {
  const missing = REQUIRED.filter((name) => !env(name)?.trim());
  if (missing.length) return [...missing];
  return {
    tenantId: env("MS_TENANT_ID")!.trim(),
    clientId: env("MS_CLIENT_ID")!.trim(),
    clientSecret: env("MS_CLIENT_SECRET")!.trim(),
    mailbox: env("MAIL_SENDER")?.trim() || DEFAULT_MAIL_SENDER,
  };
}

async function getToken(config: SenderConfig, doFetch: typeof fetch): Promise<string> {
  const response = await doFetch(
    `https://login.microsoftonline.com/${encodeURIComponent(config.tenantId)}/oauth2/v2.0/token`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "client_credentials",
        client_id: config.clientId,
        client_secret: config.clientSecret,
        scope: "https://graph.microsoft.com/.default",
      }),
    },
  );
  if (!response.ok) throw new Error(`TOKEN_HTTP_${response.status}`);
  const data = (await response.json()) as { access_token?: unknown };
  if (typeof data.access_token !== "string" || !data.access_token) throw new Error("TOKEN_MISSING");
  return data.access_token;
}

/** Uma rodada: pega até `limit` avisos e envia um por um. */
export async function runOnce(
  config: SenderConfig | string[],
  deps: SenderDeps,
  limit = 20,
): Promise<SenderResult> {
  if (Array.isArray(config)) return { status: "disabled", missing: config };

  const notices = await deps.claim(limit);
  if (notices.length === 0) return { status: "ok", claimed: 0, sent: 0, failed: 0 };

  let token: string;
  try {
    token = await getToken(config, deps.fetch);
  } catch (error) {
    // Sem token, nada sai: cada aviso volta para a fila com o motivo (nova tentativa depois).
    const reason = error instanceof Error ? error.message : "TOKEN_ERROR";
    for (const notice of notices) await deps.report(notice.id, false, reason);
    return { status: "ok", claimed: notices.length, sent: 0, failed: notices.length };
  }

  let sent = 0;
  let failed = 0;
  for (const notice of notices) {
    try {
      const response = await deps.fetch(
        `https://graph.microsoft.com/v1.0/users/${encodeURIComponent(config.mailbox)}/sendMail`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
          body: JSON.stringify({
            message: {
              subject: notice.subject,
              body: { contentType: "Text", content: notice.body },
              toRecipients: [{ emailAddress: { address: notice.to } }],
            },
            saveToSentItems: false,
          }),
        },
      );
      if (response.status === 202 || response.ok) {
        await deps.report(notice.id, true, null);
        sent += 1;
      } else {
        await deps.report(notice.id, false, `HTTP ${response.status}`);
        failed += 1;
      }
    } catch (error) {
      await deps.report(notice.id, false, error instanceof Error ? error.message : "NETWORK_ERROR");
      failed += 1;
    }
  }
  return { status: "ok", claimed: notices.length, sent, failed };
}
