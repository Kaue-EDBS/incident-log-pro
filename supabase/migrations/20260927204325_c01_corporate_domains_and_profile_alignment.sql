-- SAFRA-C01-AUD-02 — canonical corporate domains
-- Filename scaffolded through Supabase CLI on 2026-09-27.
-- Keeps the C04 live-session authorization contract and expands only the approved email domains.

begin;

create or replace function public.safra_is_corporate_user()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and coalesce((select auth.jwt() ->> 'is_anonymous'), 'false') <> 'true'
    and coalesce((select auth.jwt() -> 'app_metadata' ->> 'provider'), '') = 'azure'
    and (
      lower(coalesce((select auth.jwt() ->> 'email'), '')) like '%@editoradobrasil.com.br'
      or lower(coalesce((select auth.jwt() ->> 'email'), '')) like '%@editoradobrasil1.onmicrosoft.com'
    )
    and coalesce((select (auth.jwt() ->> 'exp')::bigint), 0) > extract(epoch from now())::bigint
    and (select private.safra_session_is_live());
$$;

revoke all on function public.safra_is_corporate_user() from public, anon;
grant execute on function public.safra_is_corporate_user() to authenticated, service_role;

comment on function public.safra_is_corporate_user() is
  'Canonical SAFRA authorization predicate: live non-anonymous Azure session, unexpired JWT and corporate email in editoradobrasil.com.br or editoradobrasil1.onmicrosoft.com.';

commit;
