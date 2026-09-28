#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
layout = (ROOT / "src/components/AppLayout.tsx").read_text(encoding="utf-8")

errors: list[str] = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

require("const SAFRA_NAV" in layout, "SAFRA navigation group is missing")
require("const LEGACY_TI_NAV" in layout, "Legacy TI navigation group is missing")
require("Reliability / Legado TI" in layout, "Legacy TI group label is missing")
require('label: "Abrir Protocolo"' in layout, "Safra START entry is missing")
require('to: "/tratativas/nova"' in layout, "Safra navigation must target /tratativas/nova")

for label in ["Visão Geral TI", "Incidentes TI", "Aplicações TI", "Indicadores TI"]:
    require(f'label: "{label}"' in layout, f"missing explicit TI label: {label}")

for forbidden in [
    'label: "Visão Geral"',
    'label: "Incidentes"',
    'label: "Aplicações"',
    'label: "Indicadores"',
]:
    require(forbidden not in layout, f"ambiguous legacy label remains: {forbidden}")

require(
    '{isLegacyTi ? "Reliability / Legado TI" : "Operação Safra"}' in layout,
    "mobile header must expose the active domain boundary",
)
require(
    '{isSafraItem ? "Safra" : "TI"}' in layout,
    "mobile bottom navigation must identify Safra vs TI",
)

if errors:
    for error in errors:
        print(f"FAIL C03 domain-boundary coherence: {error}")
    raise SystemExit(1)

print("PASS C03 domain-boundary coherence: Safra and Reliability/Legacy TI are visually explicit.")
