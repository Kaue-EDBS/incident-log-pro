#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "docs/data-contracts/C04_AUTHORIZATION_SURFACE.json"
SRC = ROOT / "src"

contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
allowed_rpcs = set(contract["ui"]["allowed_rpcs"])
allowed_tables = set(contract["ui"]["allowed_direct_tables"])

rpc_literal = re.compile(r"""\.rpc\s*\(\s*(["'\x60])([^"'\x60]+)\1""")
from_literal = re.compile(r"""\.from\s*\(\s*(["'\x60])([^"'\x60]+)\1""")
rpc_any = re.compile(r"""\.rpc\s*\(""")
from_any = re.compile(r"""\.from\s*\(""")

seen_rpcs = set()
seen_tables = set()
dynamic_rpc_calls = []
dynamic_from_calls = []

for path in sorted(SRC.rglob("*")):
    if path.suffix not in {".ts", ".tsx"}:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")

    rpc_matches = list(rpc_literal.finditer(text))
    from_matches = list(from_literal.finditer(text))
    rpc_total = len(list(rpc_any.finditer(text)))
    from_total = len(list(from_any.finditer(text)))

    if rpc_total != len(rpc_matches):
        dynamic_rpc_calls.append(str(path.relative_to(ROOT)))
    if from_total != len(from_matches):
        dynamic_from_calls.append(str(path.relative_to(ROOT)))

    seen_rpcs.update(match.group(2) for match in rpc_matches)
    seen_tables.update(match.group(2) for match in from_matches)

errors = []

if dynamic_rpc_calls:
    errors.append(
        "dynamic Supabase .rpc(...) call detected; authorization surface must use literal governed RPC names: "
        + ", ".join(dynamic_rpc_calls)
    )
if dynamic_from_calls:
    errors.append(
        "dynamic Supabase .from(...) call detected; direct table access is forbidden: "
        + ", ".join(dynamic_from_calls)
    )

unexpected_rpcs = sorted(seen_rpcs - allowed_rpcs)
missing_rpcs = sorted(allowed_rpcs - seen_rpcs)
unexpected_tables = sorted(seen_tables - allowed_tables)

if unexpected_rpcs:
    errors.append("UI/server source references unapproved RPCs: " + ", ".join(unexpected_rpcs))
if missing_rpcs:
    errors.append("canonical UI RPCs disappeared without contract update: " + ", ".join(missing_rpcs))
if unexpected_tables:
    errors.append("direct Supabase table access found in src: " + ", ".join(unexpected_tables))

print("Observed RPC surface:", ", ".join(sorted(seen_rpcs)) or "<none>")
print("Observed direct table surface:", ", ".join(sorted(seen_tables)) or "<none>")

if errors:
    for error in errors:
        print("FAIL", error)
    sys.exit(1)

print("PASS C04 PREV-05 UI/RPC/Data API source-surface coherence")
