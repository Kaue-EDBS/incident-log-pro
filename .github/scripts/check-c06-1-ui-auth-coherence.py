from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

root = (ROOT / "src/routes/__root.tsx").read_text(encoding="utf-8")
client = (ROOT / "src/integrations/supabase/client.ts").read_text(encoding="utf-8")
middleware = (ROOT / "src/integrations/supabase/auth-middleware.ts").read_text(encoding="utf-8")
src_text = "\n".join(
    p.read_text(encoding="utf-8", errors="ignore")
    for p in (ROOT / "src").rglob("*")
    if p.suffix in {".ts", ".tsx"}
)

checks = {
    "ui_global_session_gate": "if (!loading && (!session || corporateAuthorized === false) && !isAuthRoute)" in root,
    "ui_uses_publishable_client": "VITE_SUPABASE_PUBLISHABLE_KEY" in client,
    "ui_does_not_reference_service_role": "SERVICE_ROLE" not in client.upper(),
    "server_uses_canonical_corporate_rpc": "safra_is_corporate_user" in middleware,
    "server_rejects_failed_corporate_auth": "Microsoft corporate identity required" in middleware,
    "no_direct_ui_scenarios_read_yet": '.from("scenarios")' not in src_text and ".from('scenarios')" not in src_text,
    "no_direct_ui_scenario_owners_read_yet": '.from("scenario_owners")' not in src_text and ".from('scenario_owners')" not in src_text,
    "no_ui_role_metadata_authorization": "user_metadata" not in src_text,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(f"{'PASS' if ok else 'FAIL'} {name}")

if failed:
    raise SystemExit("C06.1 UI authorization coherence failed: " + ", ".join(failed))

print("PASS C06.1 UI/server authorization coherence contract")
