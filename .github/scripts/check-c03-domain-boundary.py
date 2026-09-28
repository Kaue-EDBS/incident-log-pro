#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
layout = (ROOT / "src/components/AppLayout.tsx").read_text(encoding="utf-8")
home = (ROOT / "src/routes/index.tsx").read_text(encoding="utf-8")
auth = (ROOT / "src/routes/auth.tsx").read_text(encoding="utf-8")

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
    require(forbidden not in layout, f"transitional Reliability surface leaked into product navigation: {forbidden}")

require(
    'createFileRoute("/")' in home and 'to: "/tratativas/nova"' in home and "redirect({" in home,
    "root route must redirect to the canonical Safra flow",
)
require(
    'navigate({ to: "/tratativas/nova", replace: true })' in auth,
    "successful authentication must land on the Safra flow",
)

for legacy_route in [
    ROOT / "src/routes/incidentes.index.tsx",
    ROOT / "src/routes/incidentes.$id.tsx",
    ROOT / "src/routes/aplicacoes.tsx",
    ROOT / "src/routes/indicadores.tsx",
]:
    require(
        legacy_route.exists(),
        f"transitional legacy implementation disappeared before its controlled migration: {legacy_route.name}",
    )

if errors:
    for error in errors:
        print(f"FAIL C03 migration-boundary coherence: {error}")
    raise SystemExit(1)

print(
    "PASS C03 migration-boundary coherence: Painel Safra is the only user-facing product identity; "
    "Reliability remains technical migration code only."
)
