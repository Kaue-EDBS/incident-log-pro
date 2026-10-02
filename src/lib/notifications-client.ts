import { deliverQueuedNotifications } from "./notifications.functions";
import { logOpsEvent } from "./ops";

/** Esvazia a fila de avisos; falhas vão para o registro técnico, nunca para a tela. */
export function runNotificationDelivery() {
  void deliverQueuedNotifications()
    .then((r) => {
      if (r.status === "error" || r.failed > 0) {
        logOpsEvent("ACTION_FAILED", "notifications_delivery", {
          detail: { status: r.status, code: r.code ?? "", failed: r.failed },
        });
      }
    })
    .catch((e: unknown) => {
      logOpsEvent("ACTION_FAILED", "notifications_delivery", {
        detail: { error: (e instanceof Error ? e.message : "UNKNOWN").slice(0, 120) },
      });
    });
}
