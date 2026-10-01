#!/usr/bin/env python3
"""C06-AUD2: the Matrix v3 staging copy cannot drift from its recorded hashes.

The XLSX is not stored in the repository. The staging JSON is the extracted copy,
and the database reconciliation test embeds the same records. This check fails if
someone edits the staging JSON or the embedded test data by hand.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

CONTRACTS = Path("docs/data-contracts")
TEST = Path("supabase/tests/database/c06_02_full_matrix_reconciliation.test.sql")
EXPECTED_CODES = [f"SAFRA-{n:02d}" for n in range(1, 12)]


def load(name):
    return json.loads((CONTRACTS / name).read_text(encoding="utf-8"))


def sha256_json(value):
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


errors = []
manifest = load("c06_matriz_v3_source_manifest.json")
staging = load("c06_matriz_v3_staging.json")
validation = load("c06_matriz_v3_validation.json")
diff = load("c06_matriz_v3_preview_diff.json")
approval = load("c06_matriz_v3_human_approval.json")
reaudit = load("c06_aud2_reconciliation_2026-10-01.json")

source_sha = manifest["source_sha256"]
records = staging["records"]
staging_sha = sha256_json(records)

if staging_sha != staging["staging_sha256"]:
    errors.append(f"staging records hash {staging_sha} differs from recorded {staging['staging_sha256']}")
if [r["code"] for r in records] != EXPECTED_CODES:
    errors.append("staging must contain exactly SAFRA-01..SAFRA-11 in order")
if any(r["source_sha256"] != source_sha for r in records) or staging["source"]["sha256"] != source_sha:
    errors.append("staging source hash differs from the source manifest")

for name, doc in (("validation", validation), ("preview_diff", diff), ("human_approval", approval), ("c06_aud2", reaudit)):
    if doc.get("source_sha256") != source_sha:
        errors.append(f"{name}: source_sha256 differs from the source manifest")
    if doc.get("staging_sha256") != staging["staging_sha256"]:
        errors.append(f"{name}: staging_sha256 differs from the staging copy")

if validation.get("status") != "PASS" or validation.get("errors"):
    errors.append("validation must be PASS with no errors")
if validation.get("criticality_inferred") is not False or validation.get("structured_sla_inferred") is not False:
    errors.append("validation must state that criticality and structured SLA were not inferred")
if diff.get("status") != "NO_DIFF" or reaudit.get("preview_diff", {}).get("status") != "NO_DIFF":
    errors.append("preview diff must be NO_DIFF")

embedded = re.findall(r"\$json\$(.*?)\$json\$", TEST.read_text(encoding="utf-8"), re.S)
if not embedded:
    errors.append(f"{TEST}: no embedded Matrix v3 records found")
for i, block in enumerate(embedded, 1):
    if json.loads(block) != records:
        errors.append(f"{TEST}: embedded block {i} differs from the staging copy")

if errors:
    print("\n".join("FAIL " + e for e in errors))
    sys.exit(1)

print(f"PASS C06 staging integrity: 11 records, staging {staging_sha[:12]}, {len(embedded)} embedded copies match")
