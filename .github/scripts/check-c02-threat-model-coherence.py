from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"C02 threat-model coherence failed: {label}: missing {needle!r}")


threat = read("docs/PRIVACIDADE_THREAT_MODEL.md")
migration = read("supabase/migrations/20260927214303_c02_threat_model_authz_hardening.sql")
db_test = read("supabase/tests/database/c02_threat_model_authz.test.sql")
db_workflow = read(".github/workflows/database-disposable-test.yml")
api_smoke = read(".github/scripts/test-safra-direct-api.sh")
rpc_smoke = read(".github/scripts/test-safra-direct-rpc.sh")
parity = read("docs/MATRIZ_PARIDADE.md")
profile = read("docs/PROJECT_PROFILE.yaml")

for abuse_id in (
    "AB-START-01",
    "AB-START-02",
    "AB-START-03",
    "AB-END-01",
    "AB-CANCEL-01",
    "AB-AUTHZ-01",
    "AB-OWNER-01",
    "AB-API-01",
    "AB-DATA-01",
    "AB-LEAK-01",
    "AB-TIME-01",
    "AB-VERSION-01",
    "AB-RETRY-01",
    "AB-SLA-01",
    "AB-CARD-01",
):
    require(threat, abuse_id, "canonical abuse-case catalog")

require(migration, "public.safra_is_corporate_user()", "RBAC functions must use canonical corporate predicate")
require(migration, "revoke all on function public.set_updated_at()", "legacy trigger helper revoke")
require(migration, "revoke all on function public.validate_incident_timestamps()", "legacy timestamp helper revoke")

for marker in (
    "invalid corporate session cannot enumerate governed roles",
    "invalid corporate session cannot enumerate RBAC audit rows",
    "SAFRA_START_IDEMPOTENCY_CONFLICT",
    "END/CANCEL RPCs remain unexposed",
):
    require(db_test, marker, "C02 pgTAP regression")

require(db_workflow, "test-safra-start-concurrency.sh", "concurrent START workflow step")

for table in (
    "operational_areas",
    "systems",
    "scenarios",
    "scenario_versions",
    "scenario_owners",
    "scenario_version_impacted_areas",
    "scenario_version_systems",
    "scenario_slas",
    "treatments",
    "treatment_impacted_areas",
    "treatment_impact_measurements",
    "treatment_events",
    "treatment_escalations",
    "scenario_proposals",
    "scenario_proposal_owner_responses",
    "notifications_log",
    "governance_issues",
):
    require(api_smoke, table, "full Safra Data API denial surface")

for rpc in (
    "get_my_safra_roles",
    "safra_has_role",
    "get_safra_rbac_audit_events",
    "safra_session_is_live",
):
    require(rpc_smoke, rpc, "RBAC RPC anonymous denial surface")

require(parity, "START server-side", "START parity")
require(parity, "END server-side", "END parity")
require(parity, "CANCEL server-side", "CANCEL parity")
require(profile, "c02_reaudit:", "PROJECT_PROFILE C02 reaudit state")

print("PASS: C02 threat-model, authz, concurrency and API-surface contracts are coherent.")
