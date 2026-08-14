import { useEffect, useState } from "react";
import { formatDuration } from "@/lib/metrics";
import { cn } from "@/lib/utils";

/** Cronômetro reconstruído sempre como agora - detected_at (o banco é a fonte da verdade). */
export function LiveTimer({ since, className }: { since: string; className?: string }) {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <span className={cn("tabular-nums", className)}>
      {formatDuration(now - new Date(since).getTime())}
    </span>
  );
}
