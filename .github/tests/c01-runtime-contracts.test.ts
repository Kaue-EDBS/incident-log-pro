import { describe, expect, test } from "bun:test";
import {
  SafraStartCatalogSchema,
  SafraStartResultSchema,
  SafraTreatmentSchema,
  cardDisplayName,
  cardNumber,
  safraErrorMessage,
} from "../../src/lib/safra";
import { assertBrowserSafeSupabaseKey } from "../../src/lib/supabase-key-safety";

const area = {
  id: "11111111-1111-4111-8111-111111111111",
  code: "AREA",
  name: "Área",
};

const owner = {
  principal_id: "22222222-2222-4222-8222-222222222222",
  display_name: "Owner",
  corporate_email: "owner@editoradobrasil.com.br",
};

describe("SAFRA START RPC contracts", () => {
  test("accepts a valid START catalog payload", () => {
    const parsed = SafraStartCatalogSchema.parse([
      {
        scenario_id: "33333333-3333-4333-8333-333333333333",
        code: "SAFRA-01",
        name: "Scenario",
        scenario_version_id: "44444444-4444-4444-8444-444444444444",
        version_no: 1,
        criticality: null,
        trigger_description: "Trigger",
        protocol_text: "Protocol",
        expected_impact_summary: null,
        responsible_area: area,
        owner,
        is_my_card: false,
        my_open_treatment: null,
        potential_impacted_areas: [area],
        active_treatment_count: 1,
      },
    ]);

    expect(parsed).toHaveLength(1);
    expect(parsed[0]?.code).toBe("SAFRA-01");
  });

  test("rejects an unexpected criticality", () => {
    const parsed = SafraStartCatalogSchema.safeParse([
      {
        scenario_id: "33333333-3333-4333-8333-333333333333",
        code: "SAFRA-01",
        name: "Scenario",
        scenario_version_id: "44444444-4444-4444-8444-444444444444",
        version_no: 1,
        criticality: "URGENT",
        trigger_description: null,
        protocol_text: null,
        expected_impact_summary: null,
        responsible_area: area,
        owner,
        is_my_card: false,
        my_open_treatment: null,
        potential_impacted_areas: [],
        active_treatment_count: 0,
      },
    ]);

    expect(parsed.success).toBe(false);
  });

  test("accepts a valid START result payload", () => {
    const parsed = SafraStartResultSchema.parse({
      treatment_id: "55555555-5555-4555-8555-555555555555",
      status: "ACTIVE",
      protocol_number: "01-0001",
      opened_at: "2026-09-27T20:00:00Z",
      problem_started_at: "2026-09-27T19:30:00Z",
      server_time: "2026-09-27T20:00:01Z",
      opened_by_user_id: "66666666-6666-4666-8666-666666666666",
      start_correlation_id: "77777777-7777-4777-8777-777777777777",
      start_idempotency_key: "88888888-8888-4888-8888-888888888888",
      impact_summary: null,
      idempotent_replay: false,
      scenario: {
        id: "33333333-3333-4333-8333-333333333333",
        code: "SAFRA-01",
        name: "Scenario",
        scenario_version_id: "44444444-4444-4444-8444-444444444444",
        version_no: 1,
        criticality: null,
        trigger_description: "Trigger",
        protocol_text: "Protocol",
        expected_impact_summary: null,
      },
      owner,
      responsible_area: area,
      impacted_areas: [],
    });

    expect(parsed.status).toBe("ACTIVE");
  });
});

describe("SAFRA protocol lifecycle contracts (C08)", () => {
  const treatment = {
    treatment_id: "99999999-9999-4999-8999-999999999999",
    protocol_number: "08-0001",
    status: "ACTIVE",
    situation: "AGUARDANDO_DONO",
    scenario: { id: "33333333-3333-4333-8333-333333333333", code: "SAFRA-08", name: "NF-e" },
    owner,
    requester_email: "pessoa@editoradobrasil.com.br",
    impact_summary: "Notas rejeitadas pela SEFAZ desde as 9h",
    impacted_areas: [area],
    problem_started_at: "2026-10-02T12:00:00Z",
    opened_at: "2026-10-02T12:10:00Z",
    requester_closed_at: "2026-10-02T13:00:00Z",
    owner_closed_at: null,
    closed_at: null,
    cancelled_at: null,
    cancellation_reason: null,
    server_time: "2026-10-02T13:05:00Z",
    my_role: "REQUESTER",
    can_close_my_part: false,
    can_cancel: true,
  };

  test("accepts a treatment view in a waiting situation", () => {
    expect(SafraTreatmentSchema.parse(treatment).situation).toBe("AGUARDANDO_DONO");
  });

  test("rejects an unknown situation", () => {
    expect(SafraTreatmentSchema.safeParse({ ...treatment, situation: "OK" }).success).toBe(false);
  });

  test("maps database errors to plain Portuguese", () => {
    expect(safraErrorMessage({ message: "SAFRA_IMPACT_SUMMARY_REQUIRED" }, "x")).toContain(
      "10 caracteres",
    );
    expect(safraErrorMessage({ message: "something else" }, "padrão")).toBe("padrão");
  });

  test("D-91: display name drops parentheses and line breaks", () => {
    expect(cardDisplayName('Pedido pago não integrado\n("limbo" de entrada)')).toBe(
      "Pedido pago não integrado",
    );
    expect(cardDisplayName("Ruptura de estoque de título (curva A)")).toBe(
      "Ruptura de estoque de título",
    );
    expect(cardDisplayName("Insucesso de entrega")).toBe("Insucesso de entrega");
  });

  test("derives the card number used in protocol numbers", () => {
    expect(cardNumber("SAFRA-08")).toBe("08");
    expect(cardNumber("TEST-X")).toBe("TEST-X");
  });
});

describe("browser Supabase key safety", () => {
  test("accepts a publishable key", () => {
    expect(assertBrowserSafeSupabaseKey("sb_publishable_test")).toBe("sb_publishable_test");
  });

  test("rejects a new secret key", () => {
    expect(() => assertBrowserSafeSupabaseKey("sb_secret_test")).toThrow("secret/service-role");
  });

  test("rejects a legacy service_role JWT", () => {
    const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature";
    expect(() => assertBrowserSafeSupabaseKey(key)).toThrow("secret/service-role");
  });

  test("allows a legacy anon JWT", () => {
    const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.signature";
    expect(assertBrowserSafeSupabaseKey(key)).toBe(key);
  });
});
