import { cn } from "@/lib/utils";

export function StatusBadge({ active, className }: { active: boolean; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold",
        active
          ? "bg-destructive/10 text-destructive"
          : "bg-secondary/15 text-[color:var(--primary)]",
        className,
      )}
    >
      <span
        className={cn(
          "size-1.5 rounded-full",
          active ? "bg-destructive" : "bg-[color:var(--turquoise)]",
        )}
      />
      {active ? "Incidente em andamento" : "Operacional"}
    </span>
  );
}
