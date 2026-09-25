-- SAFRA-C05 — FK, server timestamps, version freeze, append-only history and temporal integrity
-- Canonical source: supabase/migrations
-- This migration hardens the v2 schema without creating new domain entities.

-- 1) Strong FK: current_version_id must belong to the same scenario.
alter table public.scenarios
  drop constraint if exists scenarios_current_version_fk;

alter table public.scenarios
  add constraint scenarios_current_version_same_scenario_fk
  foreign key (current_version_id, id)
  references public.scenario_versions(id, scenario_id)
  on delete restrict;

-- 2) Temporal CHECK constraints that do not depend on other rows.
alter table public.scenario_versions
  add constraint scenario_versions_published_after_created_check
  check (published_at is null or published_at >= created_at);

alter table public.notifications_log
  add constraint notifications_sent_after_queued_check
  check (sent_at is null or sent_at >= queued_at),
  add constraint notifications_failed_after_queued_check
  check (failed_at is null or failed_at >= queued_at);

alter table public.governance_issues
  add constraint governance_issues_resolved_after_opened_check
  check (resolved_at is null or resolved_at >= opened_at);

-- 3) Server clock for scenario version lifecycle.
create or replace function private.safra_scenario_version_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then
    new.created_at := v_now;
    new.updated_at := v_now;

    if new.status = 'DRAFT' then
      new.published_at := null;
      new.retired_at := null;
    elsif new.status = 'PUBLISHED' then
      new.published_at := v_now;
      new.retired_at := null;
    end if;

    return new;
  end if;

  new.updated_at := v_now;

  if old.status = 'DRAFT' and new.status = 'PUBLISHED' then
    new.published_at := v_now;
    new.retired_at := null;
  elsif old.status = 'PUBLISHED' and new.status = 'RETIRED' then
    new.published_at := old.published_at;
    new.retired_at := v_now;
  end if;

  return new;
end;
$$;

revoke all on function private.safra_scenario_version_server_clock()
from public, anon, authenticated;

drop trigger if exists trg_00_scenario_versions_server_clock on public.scenario_versions;
create trigger trg_00_scenario_versions_server_clock
before insert or update on public.scenario_versions
for each row execute function private.safra_scenario_version_server_clock();

-- 4) Full version freeze: child content of PUBLISHED/RETIRED versions is immutable.
create or replace function private.safra_guard_version_child_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_old_status text;
  v_new_status text;
begin
  if tg_op in ('UPDATE','DELETE') then
    select sv.status into v_old_status
    from public.scenario_versions sv
    where sv.id = old.scenario_version_id;

    if v_old_status in ('PUBLISHED','RETIRED') then
      raise exception 'child content of % scenario_version is immutable', v_old_status;
    end if;
  end if;

  if tg_op in ('INSERT','UPDATE') then
    select sv.status into v_new_status
    from public.scenario_versions sv
    where sv.id = new.scenario_version_id;

    if v_new_status in ('PUBLISHED','RETIRED') then
      raise exception 'child content of % scenario_version is immutable', v_new_status;
    end if;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function private.safra_guard_version_child_mutation()
from public, anon, authenticated;

drop trigger if exists trg_scenario_version_impacted_areas_freeze on public.scenario_version_impacted_areas;
create trigger trg_scenario_version_impacted_areas_freeze
before insert or update or delete on public.scenario_version_impacted_areas
for each row execute function private.safra_guard_version_child_mutation();

drop trigger if exists trg_scenario_version_systems_freeze on public.scenario_version_systems;
create trigger trg_scenario_version_systems_freeze
before insert or update or delete on public.scenario_version_systems
for each row execute function private.safra_guard_version_child_mutation();

drop trigger if exists trg_scenario_slas_freeze on public.scenario_slas;
create trigger trg_scenario_slas_freeze
before insert or update or delete on public.scenario_slas
for each row execute function private.safra_guard_version_child_mutation();

-- 5) Ownership is temporal history: server validity timestamps and no physical deletion.
create or replace function private.safra_guard_scenario_owner_history()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then
    new.valid_from := v_now;
    new.created_at := v_now;
    new.valid_to := null;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception 'scenario_owners history cannot be deleted';
  end if;

  if old.valid_to is not null then
    raise exception 'closed scenario_owner history is immutable';
  end if;

  if new.scenario_id is distinct from old.scenario_id
     or new.owner_id is distinct from old.owner_id
     or new.valid_from is distinct from old.valid_from
     or new.assigned_by is distinct from old.assigned_by
     or new.created_at is distinct from old.created_at
  then
    raise exception 'scenario_owner identity/history fields are immutable';
  end if;

  if new.valid_to is not null then
    new.valid_to := v_now;
  end if;

  return new;
end;
$$;

revoke all on function private.safra_guard_scenario_owner_history()
from public, anon, authenticated;

drop trigger if exists trg_00_scenario_owners_history on public.scenario_owners;
create trigger trg_00_scenario_owners_history
before insert or update or delete on public.scenario_owners
for each row execute function private.safra_guard_scenario_owner_history();

-- 6) Treatment official timestamps and immutable close/cancel timestamps.
create or replace function private.safra_treatment_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then
    new.opened_at := v_now;
    new.created_at := v_now;
    new.updated_at := v_now;
    new.closed_at := null;
    new.cancelled_at := null;
    return new;
  end if;

  new.updated_at := v_now;

  if old.status = 'ACTIVE' and new.status = 'RESOLVED' then
    new.closed_at := v_now;
    new.cancelled_at := null;
  elsif old.status = 'ACTIVE' and new.status = 'CANCELLED' then
    new.cancelled_at := v_now;
    new.closed_at := null;
  elsif old.status = 'RESOLVED' then
    new.closed_by := old.closed_by;
    new.closed_at := old.closed_at;
  elsif old.status = 'CANCELLED' then
    new.cancelled_by := old.cancelled_by;
    new.cancelled_at := old.cancelled_at;
    new.cancellation_reason := old.cancellation_reason;
  end if;

  return new;
end;
$$;

revoke all on function private.safra_treatment_server_clock()
from public, anon, authenticated;

drop trigger if exists trg_00_treatments_server_clock on public.treatments;
create trigger trg_00_treatments_server_clock
before insert or update on public.treatments
for each row execute function private.safra_treatment_server_clock();

-- 7) Treatment events: event time is always database time; existing append-only trigger remains authoritative.
create or replace function private.safra_treatment_event_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  new.occurred_at := v_now;
  new.created_at := v_now;
  return new;
end;
$$;

revoke all on function private.safra_treatment_event_server_clock()
from public, anon, authenticated;

drop trigger if exists trg_00_treatment_events_server_clock on public.treatment_events;
create trigger trg_00_treatment_events_server_clock
before insert on public.treatment_events
for each row execute function private.safra_treatment_event_server_clock();

-- 8) Impact measurements remain append-only; source measurement time may be historical,
-- but materially future timestamps are rejected.
create or replace function private.safra_guard_impact_measurement_time()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if new.measured_at > v_now + interval '5 minutes' then
    raise exception 'impact measurement cannot be materially in the future';
  end if;

  new.created_at := v_now;
  return new;
end;
$$;

revoke all on function private.safra_guard_impact_measurement_time()
from public, anon, authenticated;

drop trigger if exists trg_00_treatment_impact_measurement_time on public.treatment_impact_measurements;
create trigger trg_00_treatment_impact_measurement_time
before insert on public.treatment_impact_measurements
for each row execute function private.safra_guard_impact_measurement_time();

-- 9) Impacted-area history: additions/removals only while treatment is ACTIVE,
-- server validity timestamps and no physical deletion.
create or replace function private.safra_guard_treatment_impacted_area_history()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_status text;
begin
  if tg_op = 'DELETE' then
    raise exception 'treatment_impacted_areas history cannot be deleted';
  end if;

  select t.status into v_status
  from public.treatments t
  where t.id = case when tg_op = 'INSERT' then new.treatment_id else old.treatment_id end;

  if v_status <> 'ACTIVE' then
    raise exception 'impacted areas can only change while treatment is ACTIVE';
  end if;

  if tg_op = 'INSERT' then
    new.valid_from := v_now;
    new.created_at := v_now;
    new.valid_to := null;
    new.removed_by := null;
    return new;
  end if;

  if old.valid_to is not null then
    raise exception 'closed impacted-area history is immutable';
  end if;

  if new.treatment_id is distinct from old.treatment_id
     or new.operational_area_id is distinct from old.operational_area_id
     or new.valid_from is distinct from old.valid_from
     or new.added_by is distinct from old.added_by
     or new.created_at is distinct from old.created_at
  then
    raise exception 'impacted-area identity/history fields are immutable';
  end if;

  if new.valid_to is not null then
    new.valid_to := v_now;
  end if;

  return new;
end;
$$;

revoke all on function private.safra_guard_treatment_impacted_area_history()
from public, anon, authenticated;

drop trigger if exists trg_00_treatment_impacted_areas_history on public.treatment_impacted_areas;
create trigger trg_00_treatment_impacted_areas_history
before insert or update or delete on public.treatment_impacted_areas
for each row execute function private.safra_guard_treatment_impacted_area_history();

-- 10) Escalation history: temporal rows are closed, not rewritten/deleted.
create or replace function private.safra_guard_treatment_escalation_history()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_status text;
begin
  if tg_op = 'DELETE' then
    raise exception 'treatment_escalations history cannot be deleted';
  end if;

  select t.status into v_status
  from public.treatments t
  where t.id = case when tg_op = 'INSERT' then new.treatment_id else old.treatment_id end;

  if v_status <> 'ACTIVE' then
    raise exception 'escalation can only change while treatment is ACTIVE';
  end if;

  if tg_op = 'INSERT' then
    new.valid_from := v_now;
    new.created_at := v_now;
    new.valid_to := null;
    return new;
  end if;

  if old.valid_to is not null then
    raise exception 'closed escalation history is immutable';
  end if;

  if new.treatment_id is distinct from old.treatment_id
     or new.level is distinct from old.level
     or new.reason is distinct from old.reason
     or new.valid_from is distinct from old.valid_from
     or new.changed_by is distinct from old.changed_by
     or new.correlation_id is distinct from old.correlation_id
     or new.created_at is distinct from old.created_at
  then
    raise exception 'escalation identity/history fields are immutable';
  end if;

  if new.valid_to is not null then
    new.valid_to := v_now;
  end if;

  return new;
end;
$$;

revoke all on function private.safra_guard_treatment_escalation_history()
from public, anon, authenticated;

drop trigger if exists trg_00_treatment_escalations_history on public.treatment_escalations;
create trigger trg_00_treatment_escalations_history
before insert or update or delete on public.treatment_escalations
for each row execute function private.safra_guard_treatment_escalation_history();

-- 11) Proposal timestamps are always database timestamps.
create or replace function private.safra_scenario_proposal_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  new.submitted_at := v_now;
  new.created_at := v_now;
  return new;
end;
$$;

revoke all on function private.safra_scenario_proposal_server_clock()
from public, anon, authenticated;

drop trigger if exists trg_00_scenario_proposals_server_clock on public.scenario_proposals;
create trigger trg_00_scenario_proposals_server_clock
before insert on public.scenario_proposals
for each row execute function private.safra_scenario_proposal_server_clock();

create or replace function private.safra_proposal_response_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then
    new.responded_at := v_now;
    new.created_at := v_now;
  elsif new.response is distinct from old.response
        or new.response_note is distinct from old.response_note then
    new.responded_at := v_now;
    new.created_at := old.created_at;
  else
    new.responded_at := old.responded_at;
    new.created_at := old.created_at;
  end if;

  return new;
end;
$$;

revoke all on function private.safra_proposal_response_server_clock()
from public, anon, authenticated;

drop trigger if exists trg_00_scenario_proposal_responses_server_clock on public.scenario_proposal_owner_responses;
create trigger trg_00_scenario_proposal_responses_server_clock
before insert or update on public.scenario_proposal_owner_responses
for each row execute function private.safra_proposal_response_server_clock();

-- 12) Notification queue/delivery timestamps are generated by the database.
create or replace function private.safra_notification_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then
    new.queued_at := v_now;
    new.created_at := v_now;

    if new.sent_at is not null then
      new.sent_at := v_now;
    end if;
    if new.failed_at is not null then
      new.failed_at := v_now;
    end if;

    return new;
  end if;

  new.queued_at := old.queued_at;
  new.created_at := old.created_at;

  if old.sent_at is null and new.sent_at is not null then
    new.sent_at := v_now;
  elsif old.sent_at is not null then
    new.sent_at := old.sent_at;
  end if;

  if old.failed_at is null and new.failed_at is not null then
    new.failed_at := v_now;
  elsif old.failed_at is not null then
    new.failed_at := old.failed_at;
  end if;

  return new;
end;
$$;

revoke all on function private.safra_notification_server_clock()
from public, anon, authenticated;

drop trigger if exists trg_00_notifications_server_clock on public.notifications_log;
create trigger trg_00_notifications_server_clock
before insert or update on public.notifications_log
for each row execute function private.safra_notification_server_clock();

-- 13) Governance issue lifecycle timestamps are generated by the database.
create or replace function private.safra_governance_issue_server_clock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then
    new.opened_at := v_now;
    new.created_at := v_now;
    new.updated_at := v_now;

    if new.status = 'RESOLVED' then
      new.resolved_at := v_now;
    else
      new.resolved_at := null;
    end if;

    return new;
  end if;

  new.opened_at := old.opened_at;
  new.created_at := old.created_at;
  new.updated_at := v_now;

  if old.status = 'OPEN' and new.status = 'RESOLVED' then
    new.resolved_at := v_now;
  elsif old.status = 'RESOLVED' and new.status = 'RESOLVED' then
    new.resolved_at := old.resolved_at;
  end if;

  return new;
end;
$$;

revoke all on function private.safra_governance_issue_server_clock()
from public, anon, authenticated;

drop trigger if exists trg_00_governance_issues_server_clock on public.governance_issues;
create trigger trg_00_governance_issues_server_clock
before insert or update on public.governance_issues
for each row execute function private.safra_governance_issue_server_clock();

comment on constraint scenarios_current_version_same_scenario_fk on public.scenarios is
  'Ensures current_version_id belongs to the same scenario at FK level.';

comment on function private.safra_guard_version_child_mutation() is
  'Freezes version-owned areas, systems and SLA content after scenario_version publication.';

comment on function private.safra_treatment_server_clock() is
  'Makes START/END/CANCEL lifecycle timestamps database-controlled and preserves terminal timestamps.';

comment on function private.safra_treatment_event_server_clock() is
  'Makes treatment event occurred_at/created_at database-controlled. Existing append-only trigger prevents rewrites.';
