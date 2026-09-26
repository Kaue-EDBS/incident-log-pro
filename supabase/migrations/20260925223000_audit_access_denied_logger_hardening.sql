-- Access-denied audit logging is a backend responsibility.
-- Prevent arbitrary authenticated sessions from spamming the privileged audit writer.
revoke execute on function public.safra_log_access_denied(text, text) from authenticated;
grant execute on function public.safra_log_access_denied(text, text) to service_role;
