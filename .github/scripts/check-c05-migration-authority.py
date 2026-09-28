#!/usr/bin/env python3
"""C05 migration authority gate.

The Safra database has one schema/migration authority:
  supabase/migrations/*.sql

Drizzle is intentionally not a migration/schema authority in this repository.
If Drizzle is reintroduced, that requires an explicit architectural decision
and an update to the C05 audit contract before this gate is changed.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE_JSON = ROOT / "package.json"
SUPABASE_MIGRATIONS = ROOT / "supabase" / "migrations"

errors: list[str] = []

# Canonical migration source must exist and be populated.
if not SUPABASE_MIGRATIONS.is_dir():
    errors.append("canonical directory supabase/migrations is missing")
else:
    migrations = sorted(SUPABASE_MIGRATIONS.glob("*.sql"))
    if not migrations:
        errors.append("canonical directory supabase/migrations contains no SQL migrations")

# A second Drizzle schema/migration tree is forbidden by the C05 decision.
for forbidden in (
    ROOT / "drizzle.config.ts",
    ROOT / "drizzle.config.js",
    ROOT / "drizzle.config.mjs",
    ROOT / "drizzle.config.cjs",
    ROOT / "drizzle",
):
    if forbidden.exists():
        errors.append(f"obsolete Drizzle authority artifact exists: {forbidden.relative_to(ROOT)}")

# Direct Drizzle migration dependencies must not silently return.
pkg = json.loads(PACKAGE_JSON.read_text(encoding="utf-8"))
for section in ("dependencies", "devDependencies", "optionalDependencies", "peerDependencies"):
    deps = pkg.get(section) or {}
    for forbidden_dep in ("drizzle-kit", "drizzle-orm"):
        if forbidden_dep in deps:
            errors.append(f"{forbidden_dep} is declared in package.json {section}")

# No npm/bun script may create a parallel Drizzle migration route.
for name, command in (pkg.get("scripts") or {}).items():
    if "drizzle" in str(command).lower():
        errors.append(f"package script {name!r} invokes Drizzle")

if errors:
    for error in errors:
        print(f"FAIL: {error}")
    print("C05 migration authority gate failed.")
    sys.exit(1)

migration_count = len(list(SUPABASE_MIGRATIONS.glob("*.sql")))
print("PASS C05 migration authority")
print("canonical_source=supabase/migrations")
print(f"migration_count={migration_count}")
print("drizzle_authority=absent")
