import { Input } from "@/components/ui/input";
import { PERIOD_LABELS, type Application, type PeriodKey } from "@/lib/types";
import { cn } from "@/lib/utils";

const PERIODS: PeriodKey[] = ["today", "7d", "30d", "month", "custom"];

export type FilterState = {
  period: PeriodKey;
  applicationId: string;
  from?: string;
  to?: string;
};

export function Filters({
  value,
  onChange,
  applications,
}: {
  value: FilterState;
  onChange: (next: FilterState) => void;
  applications: Application[];
}) {
  return (
    <div className="flex flex-col gap-3 rounded-xl border border-border bg-card p-4 sm:flex-row sm:flex-wrap sm:items-center">
      <div className="flex flex-wrap gap-1.5">
        {PERIODS.map((p) => (
          <button
            key={p}
            type="button"
            onClick={() => onChange({ ...value, period: p })}
            className={cn(
              "rounded-lg px-3 py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:bg-muted",
              value.period === p && "bg-primary text-primary-foreground hover:bg-primary",
            )}
          >
            {PERIOD_LABELS[p]}
          </button>
        ))}
      </div>

      {value.period === "custom" ? (
        <div className="flex items-center gap-2">
          <Input
            type="date"
            className="h-9 w-40"
            value={value.from ?? ""}
            onChange={(e) => onChange({ ...value, from: e.target.value })}
          />
          <span className="text-xs text-muted-foreground">até</span>
          <Input
            type="date"
            className="h-9 w-40"
            value={value.to ?? ""}
            onChange={(e) => onChange({ ...value, to: e.target.value })}
          />
        </div>
      ) : null}

      <div className="flex flex-wrap gap-1.5 sm:ml-auto">
        <button
          type="button"
          onClick={() => onChange({ ...value, applicationId: "all" })}
          className={cn(
            "rounded-lg px-3 py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:bg-muted",
            value.applicationId === "all" && "bg-secondary/20 text-foreground",
          )}
        >
          Todas
        </button>
        {applications.map((app) => (
          <button
            key={app.id}
            type="button"
            onClick={() => onChange({ ...value, applicationId: app.id })}
            className={cn(
              "rounded-lg px-3 py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:bg-muted",
              value.applicationId === app.id && "bg-secondary/20 text-foreground",
            )}
          >
            {app.name}
          </button>
        ))}
      </div>
    </div>
  );
}
