import { Info } from "lucide-react";
import type { ReactNode } from "react";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";

export function MetricCard({
  label,
  value,
  hint,
  helper,
  icon,
}: {
  label: string;
  value: string;
  hint: string;
  helper?: string;
  icon?: ReactNode;
}) {
  return (
    <div className="rounded-xl border border-border bg-card p-5 transition-shadow hover:shadow-sm">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground">
          {icon}
          {label}
        </div>
        <Tooltip>
          <TooltipTrigger aria-label={`Sobre ${label}`}>
            <Info className="size-4 text-muted-foreground" />
          </TooltipTrigger>
          <TooltipContent className="max-w-64">{hint}</TooltipContent>
        </Tooltip>
      </div>
      <p className="mt-3 text-3xl font-semibold tracking-tight text-foreground">{value}</p>
      {helper ? <p className="mt-1 text-xs text-muted-foreground">{helper}</p> : null}
    </div>
  );
}
