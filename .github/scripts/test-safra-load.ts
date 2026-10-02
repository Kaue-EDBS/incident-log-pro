/**
 * C09 — capacity test (D-94): worst case of 400 people and 1,000 protocols.
 * Runs against the local Supabase API (PostgREST behind the gateway), the same path the
 * browser uses, with one signed session per synthetic person.
 *
 *   Phase A (sustained): 400 people for LOAD_SECONDS reading the catalog and their protocols,
 *                        opening 1,000 protocols in total and closing part of them.
 *   Phase B (spike):     the 400 open a protocol at the same moment.
 *   Phase C (owners):    the card owners read their card protocols and close some.
 *
 * Env: E2E_SUPABASE_URL, E2E_ANON_KEY, E2E_JWT_SECRET, E2E_DB_URL.
 */
import { createHmac, randomUUID } from "node:crypto";
import postgres from "postgres";

const API = process.env["E2E_SUPABASE_URL"] ?? "";
const ANON = process.env["E2E_ANON_KEY"] ?? "";
const SECRET = process.env["E2E_JWT_SECRET"] ?? "";
const DB_URL = process.env["E2E_DB_URL"] ?? "";
const PEOPLE = Number(process.env["LOAD_PEOPLE"] ?? 400);
const TOTAL_STARTS = Number(process.env["LOAD_STARTS"] ?? 1000);
const LOAD_SECONDS = Number(process.env["LOAD_SECONDS"] ?? 120);
const P95_LIMIT_MS = Number(process.env["LOAD_P95_LIMIT_MS"] ?? 2000);
// The local gateway (Kong in one CI container) drops sockets above ~100 simultaneous
// connections from a single machine; in production 400 browsers reach the platform gateway
// from many places. The test keeps 400 active people but at most MAX_IN_FLIGHT requests on
// the wire; queue time is included in every latency, so the numbers are conservative.
const MAX_IN_FLIGHT = Number(process.env["LOAD_MAX_IN_FLIGHT"] ?? 64);
let inFlight = 0;
const waiting: Array<() => void> = [];
async function acquire() {
  if (inFlight < MAX_IN_FLIGHT) {
    inFlight += 1;
    return;
  }
  await new Promise<void>((resolve) => waiting.push(resolve));
  inFlight += 1;
}
function release() {
  inFlight -= 1;
  waiting.shift()?.();
}
const TENANT = "45ba725f-d260-45c3-ac85-11f433471277";

const sql = postgres(DB_URL, { max: 4 });
type Person = { id: string; email: string; token: string };
type Sample = { rpc: string; ms: number; status: number; business?: string; error?: string };
const samples: Sample[] = [];

function token(id: string, email: string, sessionId: string) {
  const b64 = (v: string) => Buffer.from(v).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  const head = b64(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = b64(
    JSON.stringify({
      sub: id,
      email,
      role: "authenticated",
      aud: "authenticated",
      session_id: sessionId,
      is_anonymous: false,
      app_metadata: { provider: "azure" },
      iat: now,
      exp: now + 7200,
    }),
  );
  const sig = createHmac("sha256", SECRET).update(`${head}.${body}`).digest("base64url");
  return `${head}.${body}.${sig}`;
}

async function rpc(p: Person, name: string, args: Record<string, unknown> = {}) {
  const started = performance.now();
  let status = 0;
  let text = "";
  await acquire();
  try {
    const res = await fetch(`${API}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        apikey: ANON,
        Authorization: `Bearer ${p.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(args),
    });
    status = res.status;
    text = await res.text();
  } catch (error) {
    status = 0;
    text = String((error as Error)?.message ?? error);
  } finally {
    release();
  }
  const ms = performance.now() - started;
  const business = /SAFRA_[A-Z_]+/.exec(text)?.[0];
  const technical = status === 0 || status >= 500;
  samples.push({
    rpc: name,
    ms,
    status,
    ...(business ? { business } : {}),
    ...(technical ? { error: text.slice(0, 160).replace(/\s+/g, " ") } : {}),
  });
  return {
    status,
    body: status >= 200 && status < 300 && text ? (JSON.parse(text) as unknown) : null,
  };
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function percentile(values: number[], p: number) {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return Math.round(sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)]!);
}

function report(label: string, from: number, to: number) {
  const slice = samples.slice(from, to);
  const technical = slice.filter((s) => s.status === 0 || s.status >= 500).length;
  const business = slice.filter((s) => s.business).length;
  const all = slice.map((s) => s.ms);
  console.log(
    `Phase ${label}: ${slice.length} calls, technical errors ${technical}, business refusals ${business}, ` +
      `p50 ${percentile(all, 50)} ms, p95 ${percentile(all, 95)} ms, p99 ${percentile(all, 99)} ms, max ${Math.round(Math.max(0, ...all))} ms`,
  );
  const byRpc = new Map<string, number[]>();
  for (const s of slice) byRpc.set(s.rpc, [...(byRpc.get(s.rpc) ?? []), s.ms]);
  for (const [name, values] of byRpc) {
    console.log(
      `Phase ${label}:   ${name}: ${values.length} calls, p95 ${percentile(values, 95)} ms`,
    );
  }
  const errors = new Map<string, number>();
  for (const s of slice.filter((x) => x.error)) {
    const key = `${s.rpc} HTTP ${s.status} ${s.error}`;
    errors.set(key, (errors.get(key) ?? 0) + 1);
  }
  for (const [key, count] of [...errors.entries()].sort((x, y) => y[1] - x[1]).slice(0, 8)) {
    console.log(`FAIL detail phase ${label}: ${count}x ${key}`);
  }
  return { technical, p95: percentile(all, 95), business };
}

async function main() {
  // --- people -----------------------------------------------------------------------
  await sql`
    insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
    select ('10ad0000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
           'load.user' || n || '@editoradobrasil.com.br', '{"provider":"azure"}', true, false, now(), now()
    from generate_series(1, ${PEOPLE}) n`;
  await sql`
    insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
    select u.id::text, u.id, ${sql.json({ custom_claims: { tid: TENANT } })}, 'azure', now(), now()
    from auth.users u where u.id::text like '10ad0000-%'`;
  await sql`
    insert into auth.sessions(id,user_id,created_at,updated_at)
    select u.id, u.id, now(), now() from auth.users u where u.id::text like '10ad0000-%'`;

  const people: Person[] = (
    await sql`select id::text, email from auth.users where id::text like '10ad0000-%' order by id`
  ).map((r) => ({
    id: r.id as string,
    email: r.email as string,
    token: token(r.id as string, r.email as string, r.id as string),
  }));

  // Owners: reuse the login already bound to each owner principal, with a fresh session.
  const owners: Person[] = [];
  for (const row of await sql`
      select p.display_name, p.corporate_email, p.user_id::text as user_id
      from private.safra_principals p
      where p.display_name in ('Daniel Garcia', 'Jiane Rodrigues', 'Renato de Paulo')`) {
    let id = row.user_id as string | null;
    if (!id) {
      id = randomUUID();
      await sql`insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
                values (${id}, ${row.corporate_email as string}, '{"provider":"azure"}', true, false, now(), now())`;
      await sql`insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
                values (${id}, ${id}, ${sql.json({ custom_claims: { tid: TENANT } })}, 'azure', now(), now())`;
    }
    const session = randomUUID();
    await sql`insert into auth.sessions(id,user_id,created_at,updated_at) values (${session}, ${id}, now(), now())`;
    owners.push({
      id,
      email: row.corporate_email as string,
      token: token(id, row.corporate_email as string, session),
    });
  }

  const cards = (
    await sql`select id::text from public.scenarios where code ~ '^SAFRA-(0[1-9]|1[01])$' order by code`
  ).map((r) => r.id as string);

  const before = Number(
    (
      await sql`select count(*)::int as n from public.treatments t join auth.users u on u.id = t.opened_by
               where u.email like 'load.user%'`
    )[0]!.n,
  );

  // --- phase A: sustained ---------------------------------------------------------------
  const startA = samples.length;
  const deadline = Date.now() + LOAD_SECONDS * 1000;
  let startsLeft = TOTAL_STARTS;
  const usedCards = new Map<string, number>();
  let opened = 0;
  await Promise.all(
    people.map(async (p, index) => {
      await sleep((index % 50) * 40);
      while (Date.now() < deadline) {
        await rpc(p, "safra_get_start_catalog");
        if (startsLeft > 0) {
          const n = usedCards.get(p.id) ?? 0;
          if (n < cards.length) {
            startsLeft -= 1;
            usedCards.set(p.id, n + 1);
            const card = cards[(index + n) % cards.length]!;
            const res = await rpc(p, "safra_start_treatment", {
              p_scenario_id: card,
              p_idempotency_key: randomUUID(),
              p_impact_summary: `Carga: problema ${index}-${n} na operação`,
              p_impacted_area_ids: [],
            });
            if (res.status === 200) {
              opened += 1;
              const id = (res.body as { treatment_id?: string } | null)?.treatment_id;
              if (id && Math.random() < 0.5)
                await rpc(p, "safra_close_my_part", { p_treatment_id: id });
            }
          }
        }
        await rpc(p, "safra_get_my_treatments");
        // Pior caso pedido pelo owner: cada pessoa interage a cada 5-10 s durante a carga.
        await sleep(5000 + Math.random() * 5000);
      }
    }),
  );
  const a = report("A (sustained)", startA, samples.length);

  // --- phase B: spike -----------------------------------------------------------------------
  const startB = samples.length;
  let spikeOpened = 0;
  await Promise.all(
    people.map(async (p, index) => {
      const n = usedCards.get(p.id) ?? 0;
      if (n >= cards.length) return;
      usedCards.set(p.id, n + 1);
      const res = await rpc(p, "safra_start_treatment", {
        p_scenario_id: cards[(index + n) % cards.length]!,
        p_idempotency_key: randomUUID(),
        p_impact_summary: `Pico: problema simultâneo ${index}`,
        p_impacted_area_ids: [],
      });
      if (res.status === 200) spikeOpened += 1;
    }),
  );
  const b = report("B (spike)", startB, samples.length);

  // --- phase C: owners ----------------------------------------------------------------------
  const startC = samples.length;
  for (const owner of owners) {
    const res = await rpc(owner, "safra_get_owner_treatments");
    const list =
      (res.body as Array<{ treatment_id: string; can_close_my_part: boolean }> | null) ?? [];
    await Promise.all(
      list
        .filter((t) => t.can_close_my_part)
        .slice(0, 50)
        .map((t) => rpc(owner, "safra_close_my_part", { p_treatment_id: t.treatment_id })),
    );
  }
  const c = report("C (owners)", startC, samples.length);

  // --- checks ---------------------------------------------------------------------------------
  const after = Number(
    (
      await sql`select count(*)::int as n from public.treatments t join auth.users u on u.id = t.opened_by
               where u.email like 'load.user%'`
    )[0]!.n,
  );
  const duplicates = Number(
    (
      await sql`select count(*)::int as n from (select protocol_number from public.treatments
               group by 1 having count(*) > 1) x`
    )[0]!.n,
  );
  const broken = Number(
    (
      await sql`select count(*)::int as n from public.treatments
               where (status = 'RESOLVED') <> (requester_closed_at is not null and owner_closed_at is not null)`
    )[0]!.n,
  );

  const checks: Array<[string, boolean, string]> = [
    ["phase A opened the planned 1,000 protocols", opened === TOTAL_STARTS, `${opened}`],
    ["phase B spike opened one protocol per person", spikeOpened === PEOPLE, `${spikeOpened}`],
    [
      "database has every protocol the API confirmed",
      after - before === opened + spikeOpened,
      `${after - before}`,
    ],
    [
      "no technical errors (HTTP 5xx or network)",
      a.technical + b.technical + c.technical === 0,
      `${a.technical + b.technical + c.technical}`,
    ],
    [
      "no business refusal (each person opens each card once)",
      a.business + b.business + c.business === 0,
      `${a.business + b.business + c.business}`,
    ],
    [`sustained p95 below ${P95_LIMIT_MS} ms`, a.p95 < P95_LIMIT_MS, `${a.p95} ms`],
    [`spike p95 below ${P95_LIMIT_MS * 2} ms`, b.p95 < P95_LIMIT_MS * 2, `${b.p95} ms`],
    ["protocol numbers stay unique", duplicates === 0, `${duplicates}`],
    ["RESOLVED always has both parts", broken === 0, `${broken}`],
  ];
  let failed = false;
  for (const [label, ok, value] of checks) {
    console.log(`${ok ? "PASS" : "FAIL"} ${label} (${value})`);
    if (!ok) failed = true;
  }
  await sql.end();
  if (failed) process.exit(1);
  console.log(
    `PASS C09 capacity test (${PEOPLE} people, ${TOTAL_STARTS} protocols, spike; at most ${MAX_IN_FLIGHT} requests in flight)`,
  );
}

main().catch(async (error) => {
  console.error("FAIL load test crashed", error);
  await sql.end();
  process.exit(1);
});
