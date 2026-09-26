#!/usr/bin/env python3
import json
import sys
from pathlib import Path

path = Path("docs/product-gates/P1_P4.json")
data = json.loads(path.read_text(encoding="utf-8"))
errors = []

for gate_id in ("P1", "P2", "P3", "P4"):
    gate = data["gates"].get(gate_id)
    if not gate:
        errors.append(f"{gate_id}: missing")
        continue

    status = gate.get("status")
    criteria = gate.get("required_criteria") or []
    evidence = gate.get("evidence") or {}

    if status not in data["allowed_status"]:
        errors.append(f"{gate_id}: invalid status {status}")

    if len(criteria) != len(set(criteria)):
        errors.append(f"{gate_id}: duplicate required criterion")

    if status == "PASS":
        if gate.get("human_approval") is not True:
            errors.append(f"{gate_id}: PASS without human approval")
        missing = [criterion for criterion in criteria if not evidence.get(criterion)]
        if missing:
            errors.append(f"{gate_id}: PASS missing evidence for {', '.join(missing)}")
    elif gate.get("human_approval") is True:
        errors.append(f"{gate_id}: human approval set while gate is not PASS")

if errors:
    print("\n".join("FAIL " + x for x in errors))
    sys.exit(1)

for gate_id, gate in data["gates"].items():
    print(f"PASS {gate_id}: {gate['status']} (no inferred publication)")
