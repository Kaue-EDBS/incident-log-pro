import { createHmac, randomUUID } from "node:crypto";
import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Browser, type Page } from "@playwright/test";

const opened = /Protocolo (\d{2}-\d{4}) aberto\./;
import postgres from "postgres";

/**
 * Smoke de front-end (C08.3). Precisa de: E2E_SUPABASE_URL, E2E_JWT_SECRET, E2E_DB_URL.
 * Cria usuários sintéticos com identidade Microsoft do tenant da Editora, gera tokens
 * assinados pelo Supabase local e coloca a sessão no navegador, sem login Microsoft real.
 */
const SUPABASE_URL = process.env["E2E_SUPABASE_URL"] ?? "";
const JWT_SECRET = process.env["E2E_JWT_SECRET"] ?? "";
const DB_URL = process.env["E2E_DB_URL"] ?? "";
const TENANT = "45ba725f-d260-45c3-ac85-11f433471277";

type Person = { id: string; email: string; sessionId: string };

const sql = postgres(DB_URL, { max: 1 });
const people: Record<string, Person> = {};
let protocol08 = "";
let lastPage: Page | null = null;

function b64url(value: string | Buffer) {
  return Buffer.from(value).toString("base64url");
}

function mintToken(p: Person) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = b64url(
    JSON.stringify({
      sub: p.id,
      email: p.email,
      role: "authenticated",
      aud: "authenticated",
      session_id: p.sessionId,
      is_anonymous: false,
      app_metadata: { provider: "azure", providers: ["azure"] },
      user_metadata: {},
      iat: now,
      exp: now + 3600,
    }),
  );
  const signature = createHmac("sha256", JWT_SECRET)
    .update(`${header}.${payload}`)
    .digest("base64url");
  return `${header}.${payload}.${signature}`;
}

async function createPerson(key: string, email: string, fullName?: string) {
  // Playwright restarts the worker after a failure and runs beforeAll again. A principal
  // only binds to one login, so reuse the login a previous run already created.
  const existing = await sql`select u.id from auth.users u
                             join auth.identities i on i.user_id = u.id and i.provider = 'azure'
                             where lower(u.email) = lower(${email}) order by u.created_at limit 1`;
  const id = (existing[0]?.id as string | undefined) ?? randomUUID();
  const p: Person = { id, email, sessionId: randomUUID() };
  if (!existing[0]) {
    await sql`insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
              values (${p.id}, ${email}, ${sql.json({ provider: "azure", providers: ["azure"] })},
                      ${sql.json(fullName ? { full_name: fullName } : {})}, true, false, now(), now())`;
    await sql`insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
              values (${p.id}, ${p.id}, ${sql.json({ custom_claims: { tid: TENANT } })}, 'azure', now(), now())`;
  }
  await sql`insert into auth.sessions(id,user_id,created_at,updated_at) values (${p.sessionId}, ${p.id}, now(), now())`;
  people[key] = p;
}

async function openAs(browser: Browser, key: string): Promise<Page> {
  const p = people[key]!;
  const token = mintToken(p);
  const storageKey = `sb-${new URL(SUPABASE_URL).hostname.split(".")[0]}-auth-token`;
  const session = {
    access_token: token,
    refresh_token: "e2e-refresh-token",
    token_type: "bearer",
    expires_in: 3600,
    expires_at: Math.floor(Date.now() / 1000) + 3600,
    user: {
      id: p.id,
      aud: "authenticated",
      role: "authenticated",
      email: p.email,
      app_metadata: { provider: "azure", providers: ["azure"] },
      user_metadata: {},
      created_at: new Date().toISOString(),
    },
  };
  const context = await browser.newContext();
  await context.addInitScript(([k, v]) => window.localStorage.setItem(k, v), [
    storageKey,
    JSON.stringify(session),
  ] as const);
  const page = await context.newPage();
  lastPage = page;
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Qual é o problema?" })).toBeVisible();
  return page;
}

async function expectAccessible(page: Page, where: string) {
  const results = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag22aa"])
    .analyze();
  const serious = results.violations.filter(
    (v) => v.impact === "serious" || v.impact === "critical",
  );
  expect(serious.map((v) => `${where}: ${v.id} — ${v.help}`)).toEqual([]);
}

test.beforeAll(async () => {
  const principal = async (name: string) =>
    (
      await sql`select corporate_email from private.safra_principals where display_name = ${name}`
    )[0]!.corporate_email as string;
  // Nome que viria da Microsoft (D-107: listas mostram o nome, não o e-mail).
  await createPerson("requester", "e2e.requester@editoradobrasil.com.br", "Pessoa Solicitante E2E");
  await createPerson("owner", await principal("Jiane Rodrigues"));
  await createPerson("admin", await principal("Kaue Pastrello"));
});

// On failure, print what the page showed and the roles the database returned
// (lines prefixed with PAGE: are published as a CI annotation).
// eslint-disable-next-line no-empty-pattern -- Playwright requires the fixtures object
test.afterEach(async ({}, testInfo) => {
  if (testInfo.status === testInfo.expectedStatus || !lastPage) return;
  const text = await lastPage
    .locator("body")
    .innerText()
    .catch(() => "");
  for (const line of text.split("\n").filter(Boolean).slice(0, 60)) console.log(`PAGE: ${line}`);
  const binding = await sql`
    select p.display_name, p.user_id, p.is_active,
           (select array_agg(g.role || case when g.revoked_at is null then '' else ' (revoked)' end)
              from private.safra_role_grants g where g.principal_id = p.id) as roles
    from private.safra_principals p
    where p.display_name in ('Jiane Rodrigues', 'Kaue Pastrello')`;
  console.log(`PAGE: principals ${JSON.stringify(binding)}`);
  console.log(`PAGE: e2e people ${JSON.stringify(people)}`);
  const roles = await lastPage
    .evaluate(async () => {
      const key = Object.keys(localStorage).find((k) => k.endsWith("-auth-token"));
      const token = key
        ? (JSON.parse(localStorage.getItem(key) ?? "{}").access_token as string)
        : "";
      const url = (window as unknown as { __E2E_URL?: string }).__E2E_URL ?? "";
      return { key, hasToken: Boolean(token), url };
    })
    .catch(() => null);
  console.log(`PAGE: storage ${JSON.stringify(roles)}`);
});

test.afterAll(async () => {
  await sql.end();
});

test("requester: catalog, expanding card, open, close own part", async ({ browser }) => {
  const page = await openAs(browser, "requester");

  // D-91: sem código SAFRA-NN e sem texto entre parênteses nos títulos.
  const cards = page.getByRole("list", { name: "Cards disponíveis" }).getByRole("button");
  await expect(cards).toHaveCount(11);
  const titles = await cards.allInnerTexts();
  expect(titles.join(" ")).not.toMatch(/SAFRA-\d+/);
  expect(titles.join(" ")).not.toMatch(/\(/);
  await expectAccessible(page, "início");

  // Busca.
  await page.getByLabel("Buscar card").fill("NF-e");
  await expect(cards).toHaveCount(1);

  // D-81: o card se expande e os outros somem.
  await cards.first().click();
  await expect(page.getByRole("heading", { level: 2, name: /Falha de NF-e/ })).toBeVisible();
  await expect(page.getByText("Jiane Rodrigues").first()).toBeVisible();
  await expect(page.getByRole("heading", { name: "Qual é o problema?" })).toHaveCount(0);
  await expectAccessible(page, "card aberto");

  const start = page.getByRole("button", { name: "Iniciar protocolo" });
  await expect(start).toBeDisabled();
  await page.getByLabel("O que está acontecendo? (obrigatório)").fill("curto");
  await expect(start).toBeDisabled();
  await page
    .getByLabel("O que está acontecendo? (obrigatório)")
    .fill("Notas fiscais rejeitadas pela SEFAZ desde as 9h, 40 pedidos parados");
  await expect(start).toBeEnabled();
  await start.click();
  await page.getByRole("button", { name: "Sim, abrir" }).click();
  const toast08 = page.getByText(opened).first();
  await expect(toast08).toBeVisible();
  protocol08 = opened.exec(await toast08.innerText())![1]!;
  await expect(page.getByRole("button", { name: "Concluído" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Cancelar protocolo" })).toBeVisible();

  // X fecha e todos os cards voltam.
  await page.getByRole("button", { name: "Fechar e voltar a todos os cards" }).click();
  await page.getByLabel("Buscar card").fill("");
  await expect(
    page.getByRole("list", { name: "Cards disponíveis" }).getByRole("button"),
  ).toHaveCount(11);

  // Meus protocolos: contador e Concluído da minha parte.
  await page.getByRole("link", { name: "Meus protocolos" }).first().click();
  await expect(page.getByRole("heading", { name: `Protocolo ${protocol08}` })).toBeVisible();
  await expect(page.getByText("Tempo desde a abertura:").first()).toBeVisible();
  await expectAccessible(page, "meus protocolos");
  const mine08 = page.getByRole("article", { name: `Protocolo ${protocol08}` });
  await expect(mine08.getByText(/será cancelado automaticamente/)).toBeVisible();
  await mine08.getByRole("button", { name: "Concluído" }).click();
  await page.getByRole("button", { name: "Sim, concluir" }).click();
  await expect(mine08.getByText("Aguardando o dono do card")).toBeVisible();

  // M01 (D-99): desfazer em até 5 minutos e concluir de novo.
  await mine08.getByRole("button", { name: /Desfazer conclusão/ }).click();
  await expect(mine08.getByText("Em andamento", { exact: true })).toBeVisible();
  await mine08.getByRole("button", { name: "Concluído" }).click();
  await page.getByRole("button", { name: "Sim, concluir" }).click();
  await expect(mine08.getByText("Aguardando o dono do card")).toBeVisible();
  await expect(mine08.getByText(/será cancelado automaticamente/)).toHaveCount(0);

  // D-108: quem abriu não vê o histórico.
  await expect(mine08.getByRole("button", { name: "Ver histórico" })).toHaveCount(0);

  // Um usuário comum não vê o Modo Camaleão nem a área de donos.
  await expect(page.getByLabel("Modo Camaleão")).toHaveCount(0);
  await expect(page.getByRole("link", { name: "Protocolos dos meus cards" })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "Todos os protocolos" })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "Cards e donos" })).toHaveCount(0);
});

test("requester: cancel needs a reason", async ({ browser }) => {
  const page = await openAs(browser, "requester");
  await page.getByLabel("Buscar card").fill("48h");
  await page.getByRole("list", { name: "Cards disponíveis" }).getByRole("button").first().click();
  await page
    .getByLabel("O que está acontecendo? (obrigatório)")
    .fill("Pedidos sem movimentação há mais de 48 horas na transportadora");
  await page.getByRole("button", { name: "Iniciar protocolo" }).click();
  await page.getByRole("button", { name: "Sim, abrir" }).click();
  const toast03 = page.getByText(opened).first();
  await expect(toast03).toBeVisible();
  const protocol03 = opened.exec(await toast03.innerText())![1]!;

  await page.getByRole("button", { name: "Cancelar protocolo" }).click();
  const confirm = page.getByRole("button", { name: "Sim, cancelar" });
  await expect(confirm).toBeDisabled();
  await page
    .getByLabel("Motivo do cancelamento (obrigatório)")
    .fill("Abri no card errado por engano");
  await confirm.click();
  await expect(page.getByText(`Protocolo ${protocol03} cancelado.`)).toBeVisible();
});

test("owner: sees own card protocols and closes the last part", async ({ browser }) => {
  const page = await openAs(browser, "owner");
  // D-65: o card do próprio dono aparece marcado e desabilitado.
  await expect(page.getByText("Você é o dono deste card.").first()).toBeVisible();

  await page.getByRole("link", { name: "Protocolos dos meus cards" }).first().click();
  const mine = page.getByRole("article", { name: `Protocolo ${protocol08}` });
  await expect(mine).toBeVisible();
  await expect(mine.getByText("Pessoa Solicitante E2E")).toBeVisible();
  await expect(mine.getByText("e2e.requester@editoradobrasil.com.br")).toHaveCount(0);
  await expectAccessible(page, "protocolos dos meus cards");
  await mine.getByRole("button", { name: "Concluído" }).click();
  await page.getByRole("button", { name: "Sim, concluir" }).click();
  await expect(mine.getByText("Encerrado", { exact: true })).toBeVisible();
});

test("admin: Modo Camaleão previews other audiences, read-only", async ({ browser }) => {
  const page = await openAs(browser, "admin");

  // M03: a gestão e os admins veem todos os protocolos, só leitura, com histórico.
  await page.getByRole("link", { name: "Todos os protocolos" }).first().click();
  // D-121: Cards e donos.
  await page.getByRole("link", { name: "Cards e donos" }).first().click();
  await expect(page.getByRole("table", { name: /Cards, donos/ })).toBeVisible();
  await expectAccessible(page, "cards e donos");
  await page.getByRole("link", { name: "Todos os protocolos" }).first().click();
  // D-120: faixa com os números do momento (no lugar da Torre de Controle).
  await expect(page.getByRole("heading", { name: "Agora, em todos os cards" })).toBeVisible();
  const anyProtocol = page.getByRole("article", { name: `Protocolo ${protocol08}` });
  await expect(anyProtocol).toBeVisible();
  await expect(anyProtocol.getByRole("button", { name: "Concluído" })).toHaveCount(0);
  await anyProtocol.getByRole("button", { name: "Ver histórico" }).click();
  const history = anyProtocol.getByRole("list", { name: "Histórico do protocolo" });
  await expect(history).toBeVisible();
  await expect(history.getByText("Desfez a conclusão")).toBeVisible();
  // M05: a gestão vê os avisos por e-mail de cada protocolo (ainda na fila: envio aguarda o TI).
  const notices = anyProtocol.getByRole("list", { name: "Avisos do protocolo" });
  await expect(notices.getByText(/Aviso de abertura para/).first()).toBeVisible();
  await expect(notices.getByText(/Aviso de encerramento para/).first()).toBeVisible();
  // D-107: quem abriu aparece pelo nome, nunca pelo e-mail.
  await expect(anyProtocol.getByText("e2e.requester@editoradobrasil.com.br")).toHaveCount(0);
  await expectAccessible(page, "todos os protocolos");
  await page.getByRole("link", { name: "Início" }).first().click();

  const select = page.getByLabel("Modo Camaleão");
  await expect(select).toBeVisible();

  const ownerOption = await select
    .locator("option", { hasText: "Jiane Rodrigues" })
    .getAttribute("value");
  await select.selectOption(ownerOption!);
  await expect(page.getByText(/Você está vendo como Dono do card: Jiane Rodrigues/)).toBeVisible();

  // Início: o card da Jiane aparece como "seu"; outro card não deixa abrir.
  await expect(page.getByText("Você é o dono deste card.").first()).toBeVisible();
  await page.getByLabel("Buscar card").fill("48h");
  await page.getByRole("list", { name: "Cards disponíveis" }).getByRole("button").first().click();
  await expect(page.getByText(/Modo Camaleão: só visualização/)).toBeVisible();
  // D-109: no Camaleão o botão some em vez de ficar cinza.
  await expect(page.getByRole("button", { name: "Iniciar protocolo" })).toHaveCount(0);
  await page.getByRole("button", { name: "Fechar e voltar a todos os cards" }).click();

  // Protocolos dos cards da Jiane, sem botões de ação.
  await page.getByRole("link", { name: "Protocolos dos meus cards" }).first().click();
  await expect(page.getByRole("heading", { name: `Protocolo ${protocol08}` })).toBeVisible();
  await expect(page.getByRole("button", { name: "Concluído" })).toHaveCount(0);

  // Visões de gestão e administração.
  await select.selectOption("gestao");
  await page.getByRole("link", { name: "Analytics" }).first().click();
  // D-117: indicadores por card, com o consolidado para a gestão.
  const metrics = page.getByRole("table", { name: /Indicadores por card/ });
  await expect(metrics.getByRole("rowheader", { name: "Consolidado" })).toBeVisible();
  await expect(metrics.getByRole("columnheader", { name: "MTTR" })).toBeVisible();
  await expectAccessible(page, "analytics");
  await select.selectOption("admin");
  await page.getByRole("link", { name: "Administração" }).first().click();
  await expect(page.getByText("Painel de cadastrados", { exact: false })).toBeVisible();
  await expectAccessible(page, "administração");
  // D-123/D-124: cadastrados, trilha de papéis e uso das telas (anônimo).
  await expect(page.getByRole("heading", { name: "Painel de cadastrados" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Trilha de papéis" })).toBeVisible();
  await expect(page.getByRole("heading", { name: /Uso das telas/ })).toBeVisible();
  // D-59: só o Kaue vê a marcação da Safra (o teste não encerra a Safra).
  await expect(page.getByRole("heading", { name: "Safra", exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Encerrar Safra" })).toBeVisible();
  // M05: Saúde do sistema mostra a fila de avisos.
  await expect(page.getByText("Avisos na fila")).toBeVisible();
  await expect(page.getByText("Avisos com falha")).toBeVisible();

  await select.selectOption("real");
  await expect(page.getByText(/Você está vendo como/)).toHaveCount(0);
});
