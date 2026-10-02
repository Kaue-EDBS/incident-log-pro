import { describe, expect, test } from "bun:test";
import {
  readConfig,
  runOnce,
  type ClaimedNotice,
  type SenderDeps,
} from "../../supabase/functions/safra-send-notifications/sender";

const CONFIG = {
  tenantId: "45ba725f-d260-45c3-ac85-11f433471277",
  clientId: "client",
  clientSecret: "secret",
  mailbox: "painel.safra@editoradobrasil.com.br",
};

function notice(id: string): ClaimedNotice {
  return {
    id,
    to: `${id}@editoradobrasil.com.br`,
    subject: "[Painel Safra] X",
    body: "Olá",
    attempt: 1,
  };
}

function fakeDeps(notices: ClaimedNotice[], sendStatus: (to: string) => number, tokenStatus = 200) {
  const reports: Array<{ id: string; ok: boolean; error: string | null }> = [];
  const calls: Array<{ url: string; body: string }> = [];
  let claimed = 0;
  const deps: SenderDeps = {
    claim: async () => {
      claimed += 1;
      return notices;
    },
    report: async (id, ok, error) => {
      reports.push({ id, ok, error });
    },
    fetch: (async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      const body = typeof init?.body === "string" ? init.body : String(init?.body ?? "");
      calls.push({ url, body });
      if (url.includes("/oauth2/v2.0/token")) {
        return new Response(JSON.stringify({ access_token: "tok" }), { status: tokenStatus });
      }
      const to = (
        JSON.parse(body) as {
          message: { toRecipients: Array<{ emailAddress: { address: string } }> };
        }
      ).message.toRecipients[0]!.emailAddress.address;
      return new Response(null, { status: sendStatus(to) });
    }) as typeof fetch,
  };
  return { deps, reports, calls, claimedCount: () => claimed };
}

describe("M05 sender", () => {
  test("stays disabled, without touching the queue, until TI provides every setting", async () => {
    const config = readConfig((name) => (name === "MS_TENANT_ID" ? CONFIG.tenantId : undefined));
    expect(config).toEqual(["MS_CLIENT_ID", "MS_CLIENT_SECRET"]);
    const fake = fakeDeps([notice("a")], () => 202);
    const result = await runOnce(config, fake.deps);
    expect(result.status).toBe("disabled");
    expect(fake.claimedCount()).toBe(0);
  });

  test("sends each notice through Microsoft Graph and reports delivery", async () => {
    const fake = fakeDeps([notice("a"), notice("b")], () => 202);
    const result = await runOnce(CONFIG, fake.deps);
    expect(result).toEqual({ status: "ok", claimed: 2, sent: 2, failed: 0 });
    expect(fake.reports).toEqual([
      { id: "a", ok: true, error: null },
      { id: "b", ok: true, error: null },
    ]);
    const tokenCalls = fake.calls.filter((c) => c.url.includes("/oauth2/v2.0/token"));
    expect(tokenCalls).toHaveLength(1);
    expect(tokenCalls[0]!.url).toContain(CONFIG.tenantId);
    const mail = fake.calls.find((c) => c.url.includes("/sendMail"))!;
    expect(mail.url).toContain(encodeURIComponent(CONFIG.mailbox));
    expect(JSON.parse(mail.body)).toMatchObject({
      message: { subject: "[Painel Safra] X", body: { contentType: "Text", content: "Olá" } },
      saveToSentItems: false,
    });
  });

  test("a failed send goes back to the queue with the reason", async () => {
    const fake = fakeDeps([notice("a"), notice("b")], (to) => (to.startsWith("b") ? 503 : 202));
    const result = await runOnce(CONFIG, fake.deps);
    expect(result).toEqual({ status: "ok", claimed: 2, sent: 1, failed: 1 });
    expect(fake.reports).toContainEqual({ id: "b", ok: false, error: "HTTP 503" });
  });

  test("without a token nothing is sent and every notice is retried later", async () => {
    const fake = fakeDeps([notice("a"), notice("b")], () => 202, 401);
    const result = await runOnce(CONFIG, fake.deps);
    expect(result).toEqual({ status: "ok", claimed: 2, sent: 0, failed: 2 });
    expect(fake.reports.every((r) => !r.ok && r.error === "TOKEN_HTTP_401")).toBe(true);
    expect(fake.calls.some((c) => c.url.includes("/sendMail"))).toBe(false);
  });
});
