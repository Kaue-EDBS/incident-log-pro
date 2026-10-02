import { cn } from "@/lib/utils";

/** Símbolo da Editora do Brasil (losango verde-limão/verde-água com círculo branco). */
export function BrandMark({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 64 88"
      className={cn("h-9 w-auto", className)}
      aria-hidden="true"
      focusable="false"
    >
      <path d="M32 2c-3 0-6 2-8 5L1 46h62L40 7c-2-3-5-5-8-5Z" fill="#93D50A" />
      <path d="M1 46l23 35c2 3 5 5 8 5s6-2 8-5l23-35Z" fill="#00C3B3" />
      <circle cx="32" cy="46" r="17" fill="#FFFFFF" />
    </svg>
  );
}
