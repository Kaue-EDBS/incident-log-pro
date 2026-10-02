import { Construction } from "lucide-react";

/** Tela futura (D-88): mostra o que vai existir aqui, sem dado inventado. */
export function ComingSoon({
  title,
  intro,
  items,
  allowed,
}: {
  title: string;
  intro: string;
  items: string[];
  allowed: boolean;
}) {
  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        <p className="text-sm text-muted-foreground">{intro}</p>
      </header>
      {allowed ? (
        <section className="rounded-xl border border-dashed border-secondary bg-card p-6">
          <div className="flex items-center gap-2">
            <Construction className="size-5 text-warning" aria-hidden="true" />
            <p className="font-semibold">Em construção</p>
          </div>
          <p className="mt-2 text-sm text-muted-foreground">O que vai aparecer aqui:</p>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm">
            {items.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </section>
      ) : (
        <p className="rounded-xl border border-border bg-card p-6 text-sm text-muted-foreground">
          Você não tem acesso a esta área.
        </p>
      )}
    </div>
  );
}
