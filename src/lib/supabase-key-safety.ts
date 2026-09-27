function decodeLegacyJwtRole(value: string): string | null {
  const parts = value.split(".");
  if (parts.length !== 3 || typeof globalThis.atob !== "function") return null;

  const payloadPart = parts[1];
  if (!payloadPart) return null;

  try {
    const payload = payloadPart.replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload.padEnd(payload.length + ((4 - (payload.length % 4)) % 4), "=");
    const decoded = JSON.parse(globalThis.atob(padded)) as { role?: unknown };
    return typeof decoded.role === "string" ? decoded.role : null;
  } catch {
    return null;
  }
}

export function assertBrowserSafeSupabaseKey(value: string): string {
  const isSecretKey = value.startsWith("sb_secret_");
  const isLegacyServiceRole = decodeLegacyJwtRole(value) === "service_role";

  if (isSecretKey || isLegacyServiceRole) {
    throw new Error(
      "Refusing to initialize the browser Supabase client with a secret/service-role key.",
    );
  }

  return value;
}
