-- Audit hardening: internal private helper/trigger functions must not inherit PUBLIC execute.
-- The private schema already denies USAGE to anon/authenticated; this removes redundant function-level exposure.

revoke execute on function private.safra_audit_role_grant_change() from public, anon, authenticated;
revoke execute on function private.safra_rbac_audit_immutable() from public, anon, authenticated;
revoke execute on function private.safra_correlation_id() from public, anon, authenticated;
