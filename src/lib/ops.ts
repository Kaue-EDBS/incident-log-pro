import { supabase } from "@/integrations/supabase/client";

/**
 * Observabilidade mínima (D-95): erros de tela, respostas lentas, login recusado e falhas
 * técnicas vão para o registro técnico do banco. Só o código do usuário é guardado (o banco
 * identifica pela sessão); nunca token, chave ou senha. Falhar ao registrar nunca atrapalha
 * a pessoa.
 */
export type OpsKind = "CLIENT_ERROR" | "SLOW_RESPONSE" | "LOGIN_DENIED" | "ACTION_FAILED";

export const SLOW_RESPONSE_MS = 2000;

export function logOpsEvent(
  kind: OpsKind,
  code: string,
  options: { durationMs?: number; detail?: Record<string, string | number | boolean> } = {},
) {
  if (typeof window === "undefined") return;
  void supabase
    .rpc("safra_log_ops_event", {
      p_kind: kind,
      p_route: window.location.pathname.slice(0, 200),
      p_code: code.slice(0, 100),
      ...(options.durationMs !== undefined
        ? { p_duration_ms: Math.round(options.durationMs) }
        : {}),
      p_detail: options.detail ?? {},
    })
    .then(
      () => undefined,
      () => undefined,
    );
}

/** Erros de regra de negócio (SAFRA_*) são respostas esperadas, não falhas técnicas. */
function isBusinessError(error: unknown): boolean {
  const message =
    error && typeof error === "object" && "message" in error
      ? String((error as { message: unknown }).message)
      : "";
  return /SAFRA_[A-Z_]+/.test(message);
}

function technicalCode(error: unknown): string {
  if (error && typeof error === "object") {
    const e = error as { code?: unknown; status?: unknown; name?: unknown };
    if (typeof e.code === "string" && e.code) return e.code;
    if (typeof e.status === "number") return `HTTP_${e.status}`;
    if (typeof e.name === "string" && e.name) return e.name;
  }
  return "UNKNOWN";
}

/** Mede uma chamada ao banco e registra lentidão ou falha técnica. */
export async function measured<T>(name: string, call: () => PromiseLike<T>): Promise<T> {
  const started = performance.now();
  try {
    const result = await call();
    const elapsed = performance.now() - started;
    if (elapsed >= SLOW_RESPONSE_MS) logOpsEvent("SLOW_RESPONSE", name, { durationMs: elapsed });
    // O cliente do Supabase devolve o erro em vez de lançá-lo.
    const returned = (result as { error?: unknown } | null)?.error;
    if (returned && !isBusinessError(returned)) {
      logOpsEvent("ACTION_FAILED", name, {
        durationMs: elapsed,
        detail: { error: technicalCode(returned) },
      });
    }
    return result;
  } catch (error) {
    if (!isBusinessError(error)) {
      logOpsEvent("ACTION_FAILED", name, {
        durationMs: performance.now() - started,
        detail: { error: technicalCode(error) },
      });
    }
    throw error;
  }
}

let globalHandlersInstalled = false;

/** Erros não tratados da tela (uma vez por página carregada). */
export function installClientErrorLogging() {
  if (globalHandlersInstalled || typeof window === "undefined") return;
  globalHandlersInstalled = true;
  window.addEventListener("error", (event) => {
    logOpsEvent("CLIENT_ERROR", (event.error as Error | undefined)?.name ?? "Error", {
      detail: { message: String(event.message ?? "").slice(0, 300) },
    });
  });
  window.addEventListener("unhandledrejection", (event) => {
    const reason = event.reason as { name?: string; message?: string } | undefined;
    logOpsEvent("CLIENT_ERROR", reason?.name ?? "UnhandledRejection", {
      detail: { message: String(reason?.message ?? "").slice(0, 300) },
    });
  });
}
