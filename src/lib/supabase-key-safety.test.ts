import { describe, expect, test } from "bun:test";
import { assertBrowserSafeSupabaseKey } from "./supabase-key-safety";

describe("browser Supabase key safety", () => {
  test("accepts a publishable key", () => {
    expect(assertBrowserSafeSupabaseKey("sb_publishable_test")).toBe("sb_publishable_test");
  });

  test("rejects a new secret key", () => {
    expect(() => assertBrowserSafeSupabaseKey("sb_secret_test")).toThrow(
      "secret/service-role",
    );
  });

  test("rejects a legacy service_role JWT", () => {
    const key =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature";

    expect(() => assertBrowserSafeSupabaseKey(key)).toThrow("secret/service-role");
  });

  test("allows a legacy anon JWT", () => {
    const key =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.signature";

    expect(assertBrowserSafeSupabaseKey(key)).toBe(key);
  });
});
