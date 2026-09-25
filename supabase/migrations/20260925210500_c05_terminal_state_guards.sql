-- SAFRA-C05 — terminal-state guards and destructive-delete protection
-- Canonical source: supabase/migrations
-- Scope: make CANCEL/END invariants explicit and preserve treatment history.

-- CANCEL must always carry a non-blank reason.
-- This is intentionally explicit even though treatments_state_fields_check already
-- encodes the same invariant; keeping a named constraint makes the rule auditable.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.treatments'::regclass
      and conname = 'treatments_cancel_reason_required'
  ) then
    alter table public.treatments
      add constraint treatments_cancel_reason_required
      check (
        status <> 'CANCELLED'
        or btrim(coalesce(cancellation_reason, '')) <> ''
      );
  end if;
end
$$;

-- Strengthen the treatment guard with explicit END/CANCEL transition rules
-- and prevent physical deletion of treatment history.
create or replace function private.safra_guard_treatment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_current_version uuid;
  v_lifecycle text;
  v_responsible_area uuid;
  v_active_owner uuid;
begin
  if tg_op = 'DELETE' then
    raise exception 'treatment history cannot be physically deleted';
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'ACTIVE' then
      raise exception 'new treatment must start ACTIVE';
    end if;

    select s.current_version_id, s.lifecycle_status, s.responsible_area_id
      into v_current_version, v_lifecycle, v_responsible_area
    from public.scenarios s
    where s.id = new.scenario_id;

    if v_lifecycle <> 'ACTIVE' then
      raise exception 'START requires ACTIVE scenario';
    end if;

    if v_current_version is distinct from new.scenario_version_id then
      raise exception 'treatment must freeze current PUBLISHED scenario_version_id';
    end if;

    select so.owner_id into v_active_owner
    from public.scenario_owners so
    where so.scenario_id = new.scenario_id
      and so.valid_to is null;

    if v_active_owner is distinct from new.owner_id_at_start then
      raise exception 'owner_id_at_start must snapshot active scenario owner';
    end if;

    if v_responsible_area is distinct from new.responsible_area_id_at_start then
      raise exception 'responsible_area_id_at_start must snapshot current responsible area';
    end if;

    return new;
  end if;

  if new.scenario_id is distinct from old.scenario_id
     or new.scenario_version_id is distinct from old.scenario_version_id
     or new.opened_by is distinct from old.opened_by
     or new.opened_at is distinct from old.opened_at
     or new.owner_id_at_start is distinct from old.owner_id_at_start
     or new.responsible_area_id_at_start is distinct from old.responsible_area_id_at_start
     or new.start_correlation_id is distinct from old.start_correlation_id
     or new.start_idempotency_key is distinct from old.start_idempotency_key
  then
    raise exception 'treatment START snapshot fields are immutable';
  end if;

  if new.status is distinct from old.status then
    if new.status = 'RESOLVED' and old.status <> 'ACTIVE' then
      raise exception 'END is allowed only from ACTIVE treatment';
    end if;

    if new.status = 'CANCELLED' and old.status <> 'ACTIVE' then
      raise exception 'CANCEL is allowed only from ACTIVE treatment';
    end if;

    if old.status <> 'ACTIVE' then
      raise exception 'closed treatment status is immutable';
    end if;

    if new.status not in ('RESOLVED','CANCELLED') then
      raise exception 'invalid treatment state transition';
    end if;
  end if;

  if old.status = 'ACTIVE'
     and new.status = 'CANCELLED'
     and btrim(coalesce(new.cancellation_reason, '')) = ''
  then
    raise exception 'CANCEL requires cancellation_reason';
  end if;

  return new;
end;
$$;

revoke all on function private.safra_guard_treatment()
from public, anon, authenticated;

drop trigger if exists trg_treatments_guard on public.treatments;
create trigger trg_treatments_guard
before insert or update or delete on public.treatments
for each row execute function private.safra_guard_treatment();

comment on constraint treatments_cancel_reason_required on public.treatments is
  'CANCEL requires a non-blank business reason.';

comment on function private.safra_guard_treatment() is
  'Protects START snapshot, allows END/CANCEL only from ACTIVE and blocks physical deletion of treatment history.';
