import { useEffect, useState } from "react";
import { formatDuration } from "@/lib/metrics";
import { cn } from "@/lib/utils";

/**
 * Contador desde a abertura. O ponto de partida vem do servidor (abertura e horário do
 * servidor na resposta); o relógio do computador só mede o tempo passado desde então,
 * para que um relógio local errado não distorça o valor. Só exibição: não é prazo.
 */
export function LiveTimer({
  since,
  serverNow,
  className,
}: {
  since: string;
  serverNow: string;
  className?: string;
}) {
  const [base] = useState(() => ({
    elapsedAtReceipt: new Date(serverNow).getTime() - new Date(since).getTime(),
    receivedAt: Date.now(),
  }));
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <span className={cn("tabular-nums", className)}>
      {formatDuration(base.elapsedAtReceipt + (now - base.receivedAt))}
    </span>
  );
}
