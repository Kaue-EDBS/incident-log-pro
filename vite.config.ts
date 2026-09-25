// @lovable.dev/vite-tanstack-config already includes the following — do NOT add them manually
// or the app will break with duplicate plugins:
//   - TanStack devtools (dev-only, first), tanstackStart, viteReact, tailwindcss, tsConfigPaths,
//     nitro (build-only using cloudflare as a default target), VITE_* env injection, @ path alias,
//     React/TanStack dedupe, error logger plugins, and sandbox detection (port/host/strictPort).
// You can pass additional config via defineConfig({ vite: { ... }, etc... }) if needed.
import { defineConfig } from "@lovable.dev/vite-tanstack-config";

// Public (publishable) Lovable Cloud config — safe to ship. Fallback for builds where .env is absent.
const PUBLIC_URL = process.env.VITE_SUPABASE_URL || "https://trqkwqkjjjeppuddwenu.supabase.co";
const PUBLIC_KEY =
  process.env.VITE_SUPABASE_PUBLISHABLE_KEY || "sb_publishable_XFwVZb409e0H2SsvOWZofQ_UOULyk_D";
process.env.VITE_SUPABASE_URL ||= PUBLIC_URL;
process.env.VITE_SUPABASE_PUBLISHABLE_KEY ||= PUBLIC_KEY;
process.env.SUPABASE_URL ||= PUBLIC_URL;
process.env.SUPABASE_PUBLISHABLE_KEY ||= PUBLIC_KEY;

export default defineConfig({
  tanstackStart: {
    // Redirect TanStack Start's bundled server entry to src/server.ts (our SSR error wrapper).
    // nitro/vite builds from this
    server: { entry: "server" },
  },
  vite: {
    define: {
      "import.meta.env.VITE_SUPABASE_URL": JSON.stringify(PUBLIC_URL),
      "import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY": JSON.stringify(PUBLIC_KEY),
    },
  },
});
