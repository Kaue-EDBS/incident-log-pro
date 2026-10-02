import { describe, expect, test } from "bun:test";
import {
  readConfig,
  runOnce,
  type ClaimedNotice,
  type SenderDeps,
} from "../../supabase/functions/safra-send-notifications/sender";

const CONFIG = {
  kind: "graph_app" as const,
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
  const calls: Array<{ url: string; body: string; headers: Record<string, string> }> = [];
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
      calls.push({ url, body, headers: (init?.headers ?? {}) as Record<string, string> });
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
    expect(config).toEqual([
      "MS_CLIENT_ID",
      "MS_CLIENT_SECRET",
      "LOVABLE_API_KEY",
      "MICROSOFT_OUTLOOK_API_KEY",
    ]);
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

  test("D-133: without the TI app, sends through the Lovable Outlook connection as painel.safra@", async () => {
    const env: Record<string, string> = { LOVABLE_API_KEY: "lk", MICROSOFT_OUTLOOK_API_KEY: "ok" };
    const config = readConfig((name) => env[name]);
    expect(config).toMatchObject({ kind: "outlook_gateway", mailbox: CONFIG.mailbox });
    const fake = fakeDeps([notice("a")], () => 202);
    const result = await runOnce(config, fake.deps);
    expect(result).toEqual({ status: "ok", claimed: 1, sent: 1, failed: 0 });
    expect(fake.calls.some((c) => c.url.includes("/oauth2/v2.0/token"))).toBe(false);
    const mail = fake.calls[0]!;
    expect(mail.url).toBe("https://connector-gateway.lovable.dev/microsoft_outlook/me/sendMail");
    expect(mail.headers).toMatchObject({
      Authorization: "Bearer lk",
      "X-Connection-Api-Key": "ok",
    });
    expect(JSON.parse(mail.body)).toMatchObject({
      message: { from: { emailAddress: { address: CONFIG.mailbox } } },
      saveToSentItems: false,
    });
  });

  test("the TI app wins when both are configured", () => {
    const env: Record<string, string> = {
      MS_TENANT_ID: CONFIG.tenantId,
      MS_CLIENT_ID: "c",
      MS_CLIENT_SECRET: "s",
      LOVABLE_API_KEY: "lk",
      MICROSOFT_OUTLOOK_API_KEY: "ok",
    };
    expect(readConfig((name) => env[name])).toMatchObject({ kind: "graph_app" });
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
    expect(fake.reports).toHaveLength(2);
    expect(fake.reports.every((r) => !r.ok && r.error === "TOKEN_HTTP_401")).toBe(true);
    expect(fake.calls.some((c) => c.url.includes("/sendMail"))).toBe(false);
  });

  test("an accepted e-mail is never put back as failed, even if the report fails once", async () => {
    const fake = fakeDeps([notice("a")], () => 202);
    let calls = 0;
    const reports: Array<{ ok: boolean }> = [];
    fake.deps.report = async (_id, ok) => {
      calls += 1;
      if (calls === 1) throw new Error("db glitch");
      reports.push({ ok });
    };
    const result = await runOnce(CONFIG, fake.deps);
    expect(result).toEqual({ status: "ok", claimed: 1, sent: 1, failed: 0 });
    expect(reports).toEqual([{ ok: true }]);
  });

  test("a network error is retried later and the round goes on", async () => {
    const fake = fakeDeps([notice("a"), notice("b")], () => 202);
    const realFetch = fake.deps.fetch;
    fake.deps.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
      if (String(init?.body ?? "").includes("a@editoradobrasil"))
        throw new TypeError("network down");
      return realFetch(input, init);
    }) as typeof fetch;
    const result = await runOnce(CONFIG, fake.deps);
    expect(result).toEqual({ status: "ok", claimed: 2, sent: 1, failed: 1 });
    expect(fake.reports).toContainEqual({ id: "a", ok: false, error: "NETWORK_ERROR" });
  });

  test("a slow round stops sending before the 5-minute lock runs out", async () => {
    const fake = fakeDeps([notice("a"), notice("b")], () => 202);
    let clock = 0;
    fake.deps.now = () => clock;
    const realReport = fake.deps.report;
    fake.deps.report = async (id, ok, error) => {
      clock += 200_000;
      await realReport(id, ok, error);
    };
    const result = await runOnce(CONFIG, fake.deps);
    expect(result).toEqual({ status: "ok", claimed: 2, sent: 1, failed: 1 });
    expect(fake.reports).toContainEqual({ id: "b", ok: false, error: "ROUND_TIME_BUDGET" });
  });
});
