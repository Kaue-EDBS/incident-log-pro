from pathlib import Path

checks = {
    "migration_primary_domain": (
        "supabase/migrations/20260927204325_c01_corporate_domains_and_profile_alignment.sql",
        "editoradobrasil.com.br",
    ),
    "migration_onmicrosoft_domain": (
        "supabase/migrations/20260927204325_c01_corporate_domains_and_profile_alignment.sql",
        "editoradobrasil1.onmicrosoft.com",
    ),
    "ui_uses_canonical_rpc": (
        "src/integrations/supabase/AuthProvider.tsx",
        '.rpc("safra_is_corporate_user")',
    ),
    "root_blocks_unapproved_session": (
        "src/routes/__root.tsx",
        "corporateAuthorized !== true",
    ),
    "auth_only_redirects_authorized_session": (
        "src/routes/auth.tsx",
        "corporateAuthorized === true",
    ),
    "server_uses_canonical_rpc": (
        "src/integrations/supabase/auth-middleware.ts",
        '.rpc("safra_is_corporate_user")',
    ),
    "database_test_covers_onmicrosoft": (
        "supabase/tests/database/c01_corporate_domains.test.sql",
        "@editoradobrasil1.onmicrosoft.com",
    ),
    "profile_lists_onmicrosoft": (
        "docs/PROJECT_PROFILE.yaml",
        '    - "editoradobrasil1.onmicrosoft.com"',
    ),
}

failed = []

for name, (path, needle) in checks.items():
    content = Path(path).read_text(encoding="utf-8")
    if needle not in content:
        failed.append(name)
        print(f"FAIL {name}: {needle!r} not found in {path}")
    else:
        print(f"PASS {name}")

if failed:
    raise SystemExit(f"C01 corporate access coherence failed: {', '.join(failed)}")

print("PASS C01 corporate access coherence contract")
