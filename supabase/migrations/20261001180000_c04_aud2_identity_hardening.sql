-- SAFRA-C04-AUD2 — identity hardening found in the owner-requested broader audit (01/10/2026).
--   1. Principal binding: only a Microsoft (azure) Auth user may claim a corporate principal by e-mail.
--      Before, any Auth user (e.g. e-mail/password sign-up, unconfirmed) with a matching e-mail
--      could squat an unbound principal and lock the real person out of their role.
--   2. Default privileges: new tables, sequences and functions created by postgres in public no
--      longer grant access to anon/authenticated (or EXECUTE to PUBLIC) implicitly.
--   3. Cleanup: the PRIMARY-only C04 self-test harness is removed; its checks now run in CI
--      (supabase/tests/database/c04_aud2_identity_authz.test.sql).

begin;

-- 1. Principal binding -------------------------------------------------------
create or replace function private.bind_safra_principal_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is not null
     and coalesce(new.raw_app_meta_data ->> 'provider', '') = 'azure'
     and coalesce(new.is_anonymous, false) = false
  then
    update private.safra_principals
       set user_id = new.id,
           updated_at = now()
     where corporate_email = lower(new.email)
       and (user_id is null or user_id = new.id);
  end if;
  return new;
end;
$$;

revoke all on function private.bind_safra_principal_from_auth_user() from public, anon, authenticated;

drop trigger if exists trg_bind_safra_principal_from_auth_user on auth.users;
create trigger trg_bind_safra_principal_from_auth_user
after insert or update of email, raw_app_meta_data on auth.users
for each row
execute function private.bind_safra_principal_from_auth_user();

-- 2. Default privileges ------------------------------------------------------
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated;
alter default privileges for role postgres
  revoke execute on functions from public;

-- 3. Cleanup -----------------------------------------------------------------
drop function if exists private.safra_c04_selftest(text);
drop table if exists private.safra_c04_test_runs;

commit;
