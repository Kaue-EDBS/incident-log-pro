import { createServerFn } from "@tanstack/react-start";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

/**
 * SAFRA-C00 — concessão da claim `app_metadata.safra_access`.
 *
 * As policies de RLS exigem `app_metadata.safra_access = true`. `app_metadata`
 * só pode ser escrito pelo backend (service role), nunca pelo próprio usuário.
 *
 * Regra aplicada aqui:
 * 1. O usuário precisa ter entrado por identidade corporativa Microsoft
 *    (provider `azure` / `microsoft`). Contas criadas por outros meios não
 *    recebem a claim.
 * 2. Se `SAFRA_ALLOWED_EMAIL_DOMAINS` estiver definida (lista separada por
 *    vírgula), o domínio do e-mail precisa estar na lista.
 */

const MICROSOFT_PROVIDERS = new Set(["azure", "microsoft", "entra", "azuread"]);

function allowedDomains(): string[] {
  const raw = process.env["SAFRA_ALLOWED_EMAIL_DOMAINS"] ?? "";
  return raw
    .split(",")
    .map((d) => d.trim().toLowerCase().replace(/^@/, ""))
    .filter(Boolean);
}

export type SafraAccessResult = {
  granted: boolean;
  refreshed: boolean;
  reason?: "not_microsoft" | "domain_not_allowed" | "no_email";
  email?: string | null;
};

export const ensureSafraAccess = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<SafraAccessResult> => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

    const { data, error } = await supabaseAdmin.auth.admin.getUserById(context.userId);
    if (error || !data?.user) {
      throw new Error("Não foi possível validar a identidade do usuário.");
    }

    const user = data.user;
    const appMetadata = (user.app_metadata ?? {}) as Record<string, unknown>;

    const providers = new Set<string>([
      ...(typeof appMetadata["provider"] === "string" ? [appMetadata["provider"] as string] : []),
      ...(Array.isArray(appMetadata["providers"])
        ? (appMetadata["providers"] as unknown[]).filter(
            (p): p is string => typeof p === "string",
          )
        : []),
      ...(user.identities ?? []).map((identity) => identity.provider),
    ]);

    const isMicrosoft = [...providers].some((p) => MICROSOFT_PROVIDERS.has(p.toLowerCase()));

    const email = user.email?.toLowerCase() ?? null;
    const alreadyGranted = appMetadata["safra_access"] === true;

    if (!isMicrosoft) {
      return { granted: alreadyGranted, refreshed: false, reason: "not_microsoft", email };
    }

    if (!email) {
      return { granted: alreadyGranted, refreshed: false, reason: "no_email", email };
    }

    const domains = allowedDomains();
    if (domains.length > 0) {
      const domain = email.split("@")[1] ?? "";
      if (!domains.includes(domain)) {
        return { granted: alreadyGranted, refreshed: false, reason: "domain_not_allowed", email };
      }
    }

    if (alreadyGranted) {
      return { granted: true, refreshed: false, email };
    }

    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(context.userId, {
      app_metadata: { ...appMetadata, safra_access: true },
    });

    if (updateError) {
      throw new Error("Não foi possível liberar o acesso desta conta.");
    }

    return { granted: true, refreshed: true, email };
  });
