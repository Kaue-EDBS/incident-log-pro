#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src"

canonical_route = SRC / "routes" / "tratativas.nova.tsx"
legacy_route = SRC / "routes" / "novo-incidente.tsx"
layout = SRC / "components" / "AppLayout.tsx"
route_tree = SRC / "routeTree.gen.ts"

errors: list[str] = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

require(canonical_route.exists(), "canonical route src/routes/tratativas.nova.tsx is missing")
require(legacy_route.exists(), "legacy compatibility route src/routes/novo-incidente.tsx is missing")

canonical = canonical_route.read_text(encoding="utf-8") if canonical_route.exists() else ""
legacy = legacy_route.read_text(encoding="utf-8") if legacy_route.exists() else ""
layout_text = layout.read_text(encoding="utf-8")
tree = route_tree.read_text(encoding="utf-8")

require(
    'createFileRoute("/tratativas/nova")' in canonical,
    "canonical START route must be /tratativas/nova",
)
require(
    'createFileRoute("/novo-incidente")' in legacy,
    "legacy /novo-incidente route must remain as compatibility entrypoint",
)
require(
    'redirect({' in legacy and 'to: "/tratativas/nova"' in legacy,
    "legacy /novo-incidente must redirect to /tratativas/nova",
)
require(
    '"/tratativas/nova"' in layout_text,
    "AppLayout must navigate to the canonical /tratativas/nova route",
)
require(
    '"/novo-incidente"' not in layout_text,
    "AppLayout must not navigate to the legacy /novo-incidente route",
)
require(
    tree.count("'/tratativas/nova': typeof TratativasNovaRoute") == 3,
    "generated route tree must expose /tratativas/nova in fullPath/to/id maps exactly once each",
)
require(
    tree.count("'/tratativas/nova': {") == 1,
    "generated route tree must register one /tratativas/nova FileRoutesByPath entry",
)

allowed_legacy_files = {
    legacy_route.resolve(),
    route_tree.resolve(),
}
unexpected: list[str] = []
for path in SRC.rglob("*"):
    if not path.is_file() or path.suffix not in {".ts", ".tsx"}:
        continue
    if path.resolve() in allowed_legacy_files:
        continue
    if "/novo-incidente" in path.read_text(encoding="utf-8"):
        unexpected.append(str(path.relative_to(ROOT)))

require(
    not unexpected,
    "legacy /novo-incidente reference leaked outside redirect/generated route: "
    + ", ".join(unexpected),
)

if errors:
    for error in errors:
        print(f"FAIL C03 route coherence: {error}")
    raise SystemExit(1)

print("PASS C03 route coherence: canonical /tratativas/nova with legacy redirect only.")
