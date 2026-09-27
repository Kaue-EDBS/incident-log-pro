-- SAFRA-C00-AUD-02 — restore least privilege on legacy tables after C04
-- Created through Supabase CLI by the corrective bootstrap workflow on 2026-09-27.
-- This migration does not change the corporate RLS predicate introduced in C04.
-- It only narrows table/column privileges exposed to the authenticated Data API role.

revoke all on public.applications from anon;
revoke all on public.incidents from anon;

revoke all on public.applications from authenticated;
grant select on public.applications to authenticated;

revoke all on public.incidents from authenticated;
grant select on public.incidents to authenticated;

grant insert (
  application_id,
  status,
  detected_at,
  type,
  category
) on public.incidents to authenticated;

grant update (
  failure_started_at,
  response_started_at,
  recovered_at,
  status,
  type,
  category,
  responsible,
  cause,
  resolution,
  notes
) on public.incidents to authenticated;

comment on table public.applications is
  'Legacy application catalogue. Authenticated corporate users retain read-only access; anon remains blocked.';

comment on table public.incidents is
  'Legacy incident table. Authenticated corporate users are RLS-governed and restricted to the minimum legacy insert/update columns.';
