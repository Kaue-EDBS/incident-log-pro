-- SAFRA-C04-AUD — legacy Reliability surface hardening.
-- applications/incidents remain preserved as historical stationary persistence,
-- but are no longer part of the browser/Data API product surface.
--
-- Canonical intent:
--   - deny anon/authenticated direct table access;
--   - remove obsolete C04 policies for the retired Reliability surface;
--   - preserve RLS and trusted service_role/migration access;
--   - do not drop historical tables or data.

revoke all on table public.applications from anon, authenticated;
revoke all on table public.incidents from anon, authenticated;

drop policy if exists safra_c04_applications_select on public.applications;
drop policy if exists safra_c04_incidents_select on public.incidents;
drop policy if exists safra_c04_incidents_insert on public.incidents;
drop policy if exists safra_c04_incidents_update on public.incidents;
