import { useId, useState, type ReactNode } from "react";
import { ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * Seção que começa fechada e abre com um clique (pedido do owner, 02/10/2026).
 * O título é um botão (padrão de "disclosure"): leitor de tela anuncia aberto/fechado.
 * O conteúdo só é montado quando a seção está aberta.
 */
export function CollapsibleSection({
  id,
  title,
  icon,
  className,
  titleClassName = "text-lg",
  defaultOpen = false,
  children,
}: {
  id: string;
  title: ReactNode;
  icon?: ReactNode;
  className?: string;
  titleClassName?: string;
  defaultOpen?: boolean;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  const contentId = useId();

  return (
    <section
      aria-labelledby={id}
      className={cn("rounded-xl border border-border bg-card p-5", className)}
    >
      <h2 id={id} className={cn("font-semibold", titleClassName)}>
        <button
          type="button"
          aria-expanded={open}
          aria-controls={contentId}
          onClick={() => setOpen((value) => !value)}
          className="flex min-h-11 w-full items-center gap-2 rounded-md text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          {icon}
          <span className="flex-1">{title}</span>
          <ChevronDown
            className={cn("size-5 shrink-0 transition-transform", open && "rotate-180")}
            aria-hidden="true"
          />
        </button>
      </h2>
      {open ? (
        <div id={contentId} className="mt-3 space-y-4">
          {children}
        </div>
      ) : null}
    </section>
  );
}
