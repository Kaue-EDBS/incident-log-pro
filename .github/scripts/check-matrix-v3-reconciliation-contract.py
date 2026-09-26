#!/usr/bin/env python3
import hashlib
import json
import re
import sys
from pathlib import Path

STAGING_PATH = Path("docs/data-contracts/c06_matriz_v3_staging.json")
MANIFEST_PATH = Path("docs/data-contracts/c06_matriz_v3_source_manifest.json")
TEST_PATH = Path("supabase/tests/database/c06_02_full_matrix_reconciliation.test.sql")

CANONICAL_FIELDS = [
    "number","code","name","trigger","activation","protocol","responsible_area","owner",
    "impacted_areas","sla_target","tool","monitoring_visibility","validation_participants",
    "mapping","source_row","source_file","source_sheet","source_sha256"
]

def sha256_json(value):
    payload = json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()

errors = []
staging = json.loads(STAGING_PATH.read_text(encoding="utf-8"))
manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
test_text = TEST_PATH.read_text(encoding="utf-8")

records = staging.get("records") or []
if staging.get("record_count") != 11 or len(records) != 11:
    errors.append(f"expected 11 staging records, got {len(records)}")

expected_codes = [f"SAFRA-{i:02d}" for i in range(1, 12)]
observed_codes = [r.get("code") for r in records]
if observed_codes != expected_codes:
    errors.append(f"canonical codes mismatch: {observed_codes}")

for record in records:
    keys = list(record.keys())
    if set(keys) != set(CANONICAL_FIELDS) or len(keys) != len(CANONICAL_FIELDS):
        errors.append(
            f"{record.get('code','UNKNOWN')}: expected exactly 18 canonical fields, got {keys}"
        )

computed_staging_sha = sha256_json(records)
stored_staging_sha = staging.get("staging_sha256")
if computed_staging_sha != stored_staging_sha:
    errors.append(
        f"staging SHA mismatch: stored={stored_staging_sha} computed={computed_staging_sha}"
    )

source_sha = staging.get("source", {}).get("sha256")
manifest_sha = manifest.get("source_sha256")
if source_sha != manifest_sha:
    errors.append(
        f"source SHA mismatch between staging and manifest: {source_sha} != {manifest_sha}"
    )

for record in records:
    if record.get("source_sha256") != source_sha:
        errors.append(f"{record.get('code')}: record source SHA differs from staging source SHA")

markers = {
    "MATRIX_V3_SOURCE_SHA256": source_sha,
    "MATRIX_V3_STAGING_SHA256": stored_staging_sha,
    "MATRIX_V3_EXPECTED_RECORDS": "11",
    "MATRIX_V3_IMPORTED_FIELDS": str(len(CANONICAL_FIELDS)),
    "MATRIX_V3_EXPECTED_COMPARISONS": str(11 * len(CANONICAL_FIELDS)),
}
for key, expected in markers.items():
    match = re.search(rf"^-- {re.escape(key)}: (.+)$", test_text, flags=re.MULTILINE)
    if not match:
        errors.append(f"missing test marker: {key}")
    elif match.group(1).strip() != str(expected):
        errors.append(
            f"{key}: expected marker {expected}, found {match.group(1).strip()}"
        )

if errors:
    print("\n".join("FAIL " + error for error in errors))
    sys.exit(1)

print(f"PASS source_sha256={source_sha}")
print(f"PASS staging_sha256={stored_staging_sha}")
print("PASS records=11")
print("PASS imported_fields=18")
print("PASS required_comparisons=198")
