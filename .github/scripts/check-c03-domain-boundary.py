#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
layout = (ROOT / "src/components/AppLayout.tsx").read_text(encoding="utf-8")
home = (ROOT / "src/routes/index.tsx").read_text(encoding="utf-8")
auth = (ROOT / "src/routes/auth.tsx").read_text(encoding="utf-8")
route_tree = (ROOT / "src/routeTree.gen.ts").read_text(encoding="utf-8")
start_route = (ROOT / "src/routes/tratativas.nova.tsx").read_text(encoding="utf-8")
live_timer = (ROOT / "src/components/LiveTimer.tsx").read_text(encoding="utf-8")
c07_test = (ROOT / ".github/scripts/test-c07-analytics-timezone.ts").read_text(encoding="utf-8")

errors: list[str] = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

require("Painel Safra" in layout, "Painel Safra product identity is missing")
require("Operação Safra" in layout, "Safra operational label is missing")
require('to="/tratativas/nova"' in layout, "Safra navigation must target /tratativas/nova")

for forbidden in [
    "Reliability / Legado TI",
    "Visão Geral TI",
    "Incidentes TI",
    "Aplicações TI",
    "Indicadores TI",
    'to="/incidentes"',
    'to="/aplicacoes"',
    'to="/indicadores"',
]:
    require(forbidden not in layout, f"Reliability surface leaked into product navigation: {forbidden}")

require(
    'createFileRoute("/")' in home and 'to: "/tratativas/nova"' in home and "redirect({" in home,
    "root route must redirect to the canonical Safra flow",
)
require(
    'navigate({ to: "/tratativas/nova", replace: true })' in auth,
    "successful authentication must land on the Safra flow",
)

legacy_frontend_paths = [
    "src/routes/incidentes.index.tsx",
    "src/routes/incidentes.$id.tsx",
    "src/routes/aplicacoes.tsx",
    "src/routes/indicadores.tsx",
    "src/components/Filters.tsx",
    "src/components/MetricCard.tsx",
    "src/components/StatusBadge.tsx",
    "src/lib/queries.ts",
    "src/lib/types.ts",
    "src/lib/metrics.ts",
]
for relative_path in legacy_frontend_paths:
    require(
        not (ROOT / relative_path).exists(),
        f"unused Reliability frontend artifact still exists: {relative_path}",
    )

for legacy_route in ["/incidentes", "/aplicacoes", "/indicadores"]:
    require(
        legacy_route not in route_tree,
        f"legacy Reliability route still registered in route tree: {legacy_route}",
    )

require(
    (ROOT / "src/lib/safra-queries.ts").exists(),
    "Safra-only query module is missing",
)
require(
    (ROOT / "src/lib/analytics-time.ts").exists(),
    "neutral analytics-time module is missing",
)
require(
    '@/lib/safra-queries' in start_route and '@/lib/queries' not in start_route,
    "START route must use the Safra-only query module",
)
require(
    '@/lib/analytics-time' in live_timer and '@/lib/metrics' not in live_timer,
    "LiveTimer must not depend on removed Reliability metrics",
)
require(
    '../../src/lib/analytics-time' in c07_test and '../../src/lib/metrics' not in c07_test,
    "C07 timezone test must use the neutral time module",
)

if errors:
    for error in errors:
        print(f"FAIL C03 migration-boundary coherence: {error}")
    raise SystemExit(1)

print(
    "PASS C03 migration-boundary coherence: user-facing code is Safra-only; "
    "Reliability frontend/hooks are removed while database legacy remains out of scope."
)
