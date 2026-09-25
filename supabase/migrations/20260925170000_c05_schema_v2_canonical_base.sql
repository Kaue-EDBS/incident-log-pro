-- SAFRA-C05 — Schema v2 canonical base
-- Source of truth: supabase/migrations
-- Scope: domain schema + invariants only.
-- No seed of the 11 scenarios. No START/END/CANCEL RPCs.

create table public.operational_areas (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint operational_areas_code_not_blank check (btrim(code) <> ''),
  constraint operational_areas_name_not_blank check (btrim(name) <> ''),
  constraint operational_areas_general_is_not_area check (lower(btrim(name)) <> 'geral')
);

create table public.systems (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null unique,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint systems_code_not_blank check (btrim(code) <> ''),
  constraint systems_name_not_blank check (btrim(name) <> '')
);

create table public.scenarios (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  lifecycle_status text not null,
  responsible_area_id uuid references public.operational_areas(id) on delete restrict,
  current_version_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint scenarios_code_not_blank check (btrim(code) <> ''),
  constraint scenarios_name_not_blank check (btrim(name) <> ''),
  constraint scenarios_lifecycle_status_check check (lifecycle_status in ('ACTIVE','INACTIVE'))
);

create table public.scenario_versions (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references public.scenarios(id) on delete restrict,
  version_no integer not null,
  status text not null,
  trigger_description text,
  detection_description text,
  protocol_text text,
  expected_impact_summary text,
  criticality text,
  source_reference text,
  created_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  published_at timestamptz,
  retired_at timestamptz,
  constraint scenario_versions_version_positive check (version_no > 0),
  constraint scenario_versions_status_check check (status in ('DRAFT','PUBLISHED','RETIRED')),
  constraint scenario_versions_criticality_check check (
    criticality is null or criticality in ('CRITICAL','HIGH','MODERATE')
  ),
  constraint scenario_versions_lifecycle_fields_check check (
    (status = 'DRAFT' and published_at is null and retired_at is null)
    or
    (status = 'PUBLISHED' and published_at is not null and retired_at is null)
    or
    (status = 'RETIRED' and published_at is not null and retired_at is not null and retired_at >= published_at)
  ),
  constraint scenario_versions_scenario_version_unique unique (scenario_id, version_no),
  constraint scenario_versions_id_scenario_unique unique (id, scenario_id)
);

create unique index scenario_versions_one_published_per_scenario
  on public.scenario_versions(scenario_id)
  where status = 'PUBLISHED';

alter table public.scenarios
  add constraint scenarios_current_version_fk
  foreign key (current_version_id)
  references public.scenario_versions(id)
  on delete restrict;

create table public.scenario_owners (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references public.scenarios(id) on delete restrict,
  owner_id uuid not null references private.safra_principals(id) on delete restrict,
  valid_from timestamptz not null default clock_timestamp(),
  valid_to timestamptz,
  assigned_by uuid references auth.users(id) on delete restrict,
  assignment_reason text,
  created_at timestamptz not null default clock_timestamp(),
  constraint scenario_owners_validity_check check (valid_to is null or valid_to > valid_from)
);

create unique index scenario_owners_one_active_per_scenario
  on public.scenario_owners(scenario_id)
  where valid_to is null;

create index scenario_owners_owner_idx on public.scenario_owners(owner_id);

create table public.scenario_version_impacted_areas (
  scenario_version_id uuid not null references public.scenario_versions(id) on delete restrict,
  operational_area_id uuid not null references public.operational_areas(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  primary key (scenario_version_id, operational_area_id)
);

create table public.scenario_version_systems (
  scenario_version_id uuid not null references public.scenario_versions(id) on delete restrict,
  system_id uuid not null references public.systems(id) on delete restrict,
  context text,
  created_at timestamptz not null default clock_timestamp(),
  primary key (scenario_version_id, system_id)
);

create table public.scenario_slas (
  id uuid primary key default gen_random_uuid(),
  scenario_version_id uuid not null references public.scenario_versions(id) on delete restrict,
  code text not null,
  label text not null,
  start_event text not null,
  end_event text not null,
  target_value numeric,
  target_unit text,
  target_text text not null,
  applicability_text text,
  created_at timestamptz not null default clock_timestamp(),
  constraint scenario_slas_code_not_blank check (btrim(code) <> ''),
  constraint scenario_slas_label_not_blank check (btrim(label) <> ''),
  constraint scenario_slas_start_event_not_blank check (btrim(start_event) <> ''),
  constraint scenario_slas_end_event_not_blank check (btrim(end_event) <> ''),
  constraint scenario_slas_target_text_not_blank check (btrim(target_text) <> ''),
  constraint scenario_slas_structured_target_pair check (
    (target_value is null and target_unit is null)
    or
    (target_value is not null and target_unit is not null and btrim(target_unit) <> '')
  ),
  constraint scenario_slas_version_code_unique unique (scenario_version_id, code)
);

create table public.treatments (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references public.scenarios(id) on delete restrict,
  scenario_version_id uuid not null,
  status text not null,
  opened_by uuid not null references auth.users(id) on delete restrict,
  opened_at timestamptz not null default clock_timestamp(),
  owner_id_at_start uuid not null references private.safra_principals(id) on delete restrict,
  responsible_area_id_at_start uuid not null references public.operational_areas(id) on delete restrict,
  impact_summary text,
  start_correlation_id uuid not null,
  start_idempotency_key text not null unique,
  closed_by uuid references auth.users(id) on delete restrict,
  closed_at timestamptz,
  cancelled_by uuid references auth.users(id) on delete restrict,
  cancelled_at timestamptz,
  cancellation_reason text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint treatments_version_same_scenario_fk
    foreign key (scenario_version_id, scenario_id)
    references public.scenario_versions(id, scenario_id)
    on delete restrict,
  constraint treatments_status_check check (status in ('ACTIVE','RESOLVED','CANCELLED')),
  constraint treatments_state_fields_check check (
    (
      status = 'ACTIVE'
      and closed_by is null and closed_at is null
      and cancelled_by is null and cancelled_at is null and cancellation_reason is null
    )
    or
    (
      status = 'RESOLVED'
      and closed_by is not null and closed_at is not null
      and cancelled_by is null and cancelled_at is null and cancellation_reason is null
    )
    or
    (
      status = 'CANCELLED'
      and cancelled_by is not null and cancelled_at is not null
      and btrim(coalesce(cancellation_reason,'')) <> ''
      and closed_by is null and closed_at is null
    )
  ),
  constraint treatments_closed_after_open check (closed_at is null or closed_at >= opened_at),
  constraint treatments_cancelled_after_open check (cancelled_at is null or cancelled_at >= opened_at)
);

create index treatments_scenario_idx on public.treatments(scenario_id);
create index treatments_scenario_version_idx on public.treatments(scenario_version_id);
create index treatments_status_idx on public.treatments(status);

create table public.treatment_impacted_areas (
  id uuid primary key default gen_random_uuid(),
  treatment_id uuid not null references public.treatments(id) on delete restrict,
  operational_area_id uuid not null references public.operational_areas(id) on delete restrict,
  valid_from timestamptz not null default clock_timestamp(),
  valid_to timestamptz,
  added_by uuid references auth.users(id) on delete restrict,
  removed_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  constraint treatment_impacted_areas_validity_check check (valid_to is null or valid_to > valid_from),
  constraint treatment_impacted_areas_remove_actor_check check (
    (valid_to is null and removed_by is null)
    or
    (valid_to is not null and removed_by is not null)
  )
);

create unique index treatment_impacted_areas_one_active
  on public.treatment_impacted_areas(treatment_id, operational_area_id)
  where valid_to is null;

create table public.treatment_impact_measurements (
  id uuid primary key default gen_random_uuid(),
  treatment_id uuid not null references public.treatments(id) on delete restrict,
  metric_code text not null,
  metric_label text not null,
  value_numeric numeric not null,
  unit text not null,
  source_type text not null,
  source_reference text not null,
  measured_at timestamptz not null,
  recorded_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  constraint treatment_impact_metric_code_not_blank check (btrim(metric_code) <> ''),
  constraint treatment_impact_metric_label_not_blank check (btrim(metric_label) <> ''),
  constraint treatment_impact_unit_not_blank check (btrim(unit) <> ''),
  constraint treatment_impact_source_type_not_blank check (btrim(source_type) <> ''),
  constraint treatment_impact_source_reference_not_blank check (btrim(source_reference) <> '')
);

create table public.treatment_events (
  id uuid primary key default gen_random_uuid(),
  treatment_id uuid not null references public.treatments(id) on delete restrict,
  event_type text not null,
  actor_user_id uuid references auth.users(id) on delete restrict,
  occurred_at timestamptz not null default clock_timestamp(),
  correlation_id uuid not null,
  idempotency_key text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp(),
  constraint treatment_events_type_check check (
    event_type in (
      'TREATMENT_OPENED',
      'NOTE_ADDED',
      'IMPACT_AREA_ADDED',
      'IMPACT_AREA_REMOVED',
      'ESCALATION_CHANGED',
      'SLA_BREACHED',
      'TREATMENT_RESOLVED',
      'TREATMENT_CANCELLED',
      'ADMIN_CORRECTION_RECORDED'
    )
  )
);

create unique index treatment_events_idempotency_unique
  on public.treatment_events(treatment_id, event_type, idempotency_key)
  where idempotency_key is not null;

create index treatment_events_timeline_idx
  on public.treatment_events(treatment_id, occurred_at, id);

create table public.treatment_escalations (
  id uuid primary key default gen_random_uuid(),
  treatment_id uuid not null references public.treatments(id) on delete restrict,
  level text not null,
  reason text,
  valid_from timestamptz not null default clock_timestamp(),
  valid_to timestamptz,
  changed_by uuid references auth.users(id) on delete restrict,
  correlation_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint treatment_escalations_level_check check (
    level in ('NONE','TECHNICAL_CRISIS','BUSINESS_CRISIS','EXECUTIVE')
  ),
  constraint treatment_escalations_validity_check check (valid_to is null or valid_to > valid_from)
);

create unique index treatment_escalations_one_active
  on public.treatment_escalations(treatment_id)
  where valid_to is null;

create table public.scenario_proposals (
  id uuid primary key default gen_random_uuid(),
  proposed_by uuid not null references auth.users(id) on delete restrict,
  proposer_name text not null,
  proposer_email text not null,
  title text not null,
  problem_description text not null,
  safra_impact_description text not null,
  submitted_at timestamptz not null default clock_timestamp(),
  created_at timestamptz not null default clock_timestamp(),
  constraint scenario_proposals_name_not_blank check (btrim(proposer_name) <> ''),
  constraint scenario_proposals_email_not_blank check (btrim(proposer_email) <> ''),
  constraint scenario_proposals_title_not_blank check (btrim(title) <> ''),
  constraint scenario_proposals_problem_not_blank check (btrim(problem_description) <> ''),
  constraint scenario_proposals_impact_not_blank check (btrim(safra_impact_description) <> '')
);

create table public.scenario_proposal_owner_responses (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.scenario_proposals(id) on delete restrict,
  candidate_owner_id uuid not null references private.safra_principals(id) on delete restrict,
  response text not null,
  response_note text,
  responded_at timestamptz not null default clock_timestamp(),
  created_at timestamptz not null default clock_timestamp(),
  constraint scenario_proposal_response_check check (response in ('ACCEPTED','DECLINED')),
  constraint scenario_proposal_one_response_per_candidate unique (proposal_id, candidate_owner_id)
);

create table public.notifications_log (
  id uuid primary key default gen_random_uuid(),
  treatment_id uuid references public.treatments(id) on delete restrict,
  proposal_id uuid references public.scenario_proposals(id) on delete restrict,
  notification_type text not null,
  recipient_email text not null,
  recipient_principal_id uuid references private.safra_principals(id) on delete restrict,
  channel text,
  provider text,
  delivery_status text not null,
  idempotency_key text not null unique,
  correlation_id uuid not null,
  queued_at timestamptz not null default clock_timestamp(),
  sent_at timestamptz,
  failed_at timestamptz,
  failure_reason text,
  created_at timestamptz not null default clock_timestamp(),
  constraint notifications_type_not_blank check (btrim(notification_type) <> ''),
  constraint notifications_recipient_not_blank check (btrim(recipient_email) <> ''),
  constraint notifications_status_not_blank check (btrim(delivery_status) <> ''),
  constraint notifications_delivery_time_check check (
    not (sent_at is not null and failed_at is not null)
  )
);

create table public.governance_issues (
  id uuid primary key default gen_random_uuid(),
  issue_key text not null unique,
  title text not null,
  description text not null,
  status text not null,
  opened_at timestamptz not null default clock_timestamp(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete restrict,
  resolution_text text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint governance_issues_status_check check (status in ('OPEN','RESOLVED')),
  constraint governance_issues_resolution_check check (
    (status='OPEN' and resolved_at is null and resolved_by is null and resolution_text is null)
    or
    (status='RESOLVED' and resolved_at is not null and resolved_by is not null and btrim(coalesce(resolution_text,'')) <> '')
  )
);

create or replace function private.safra_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

revoke all on function private.safra_touch_updated_at() from public, anon, authenticated;

create trigger trg_operational_areas_updated_at
before update on public.operational_areas
for each row execute function private.safra_touch_updated_at();
create trigger trg_systems_updated_at
before update on public.systems
for each row execute function private.safra_touch_updated_at();
create trigger trg_scenarios_updated_at
before update on public.scenarios
for each row execute function private.safra_touch_updated_at();
create trigger trg_treatments_updated_at
before update on public.treatments
for each row execute function private.safra_touch_updated_at();
create trigger trg_governance_issues_updated_at
before update on public.governance_issues
for each row execute function private.safra_touch_updated_at();

create or replace function private.safra_guard_scenario_version_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'RETIRED' then
    raise exception 'RETIRED scenario_version is immutable';
  end if;

  if old.status = 'PUBLISHED' then
    if new.scenario_id is distinct from old.scenario_id
       or new.version_no is distinct from old.version_no
       or new.trigger_description is distinct from old.trigger_description
       or new.detection_description is distinct from old.detection_description
       or new.protocol_text is distinct from old.protocol_text
       or new.expected_impact_summary is distinct from old.expected_impact_summary
       or new.criticality is distinct from old.criticality
       or new.source_reference is distinct from old.source_reference
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at
       or new.published_at is distinct from old.published_at
    then
      raise exception 'PUBLISHED scenario_version content is immutable';
    end if;

    if new.status not in ('PUBLISHED','RETIRED') then
      raise exception 'PUBLISHED scenario_version may only remain PUBLISHED or become RETIRED';
    end if;

    if new.status = 'RETIRED' and new.retired_at is null then
      raise exception 'RETIRED scenario_version requires retired_at';
    end if;
  end if;

  new.updated_at := clock_timestamp();
  return new;
end;
$$;

revoke all on function private.safra_guard_scenario_version_update() from public, anon, authenticated;

create trigger trg_scenario_versions_guard_update
before update on public.scenario_versions
for each row execute function private.safra_guard_scenario_version_update();

create or replace function private.safra_guard_scenario_version_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status in ('PUBLISHED','RETIRED') then
    raise exception 'Published/retired scenario_version cannot be deleted';
  end if;
  return old;
end;
$$;

revoke all on function private.safra_guard_scenario_version_delete() from public, anon, authenticated;

create trigger trg_scenario_versions_guard_delete
before delete on public.scenario_versions
for each row execute function private.safra_guard_scenario_version_delete();

create or replace function private.safra_validate_published_scenario()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_scenario_id uuid;
  v_current_version uuid;
  v_published_version uuid;
  v_responsible_area uuid;
  v_active_owners integer;
  v_eligible_active_owners integer;
begin
  if tg_table_name = 'scenarios' then
    v_scenario_id := case when tg_op = 'DELETE' then old.id else new.id end;
  elsif tg_table_name = 'scenario_versions' then
    v_scenario_id := case when tg_op = 'DELETE' then old.scenario_id else new.scenario_id end;
  elsif tg_table_name = 'scenario_owners' then
    v_scenario_id := case when tg_op = 'DELETE' then old.scenario_id else new.scenario_id end;
  else
    raise exception 'Unexpected trigger table %', tg_table_name;
  end if;

  select s.current_version_id, s.responsible_area_id
    into v_current_version, v_responsible_area
  from public.scenarios s
  where s.id = v_scenario_id;

  if not found then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  select sv.id
    into v_published_version
  from public.scenario_versions sv
  where sv.scenario_id = v_scenario_id
    and sv.status = 'PUBLISHED';

  if v_published_version is null then
    if v_current_version is not null then
      raise exception 'scenario.current_version_id must be null when no PUBLISHED version exists';
    end if;
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if v_current_version is distinct from v_published_version then
    raise exception 'scenario.current_version_id must point to its PUBLISHED version';
  end if;

  if v_responsible_area is null then
    raise exception 'published scenario requires responsible_area_id';
  end if;

  select count(*) into v_active_owners
  from public.scenario_owners so
  where so.scenario_id = v_scenario_id
    and so.valid_to is null;

  if v_active_owners <> 1 then
    raise exception 'published scenario requires exactly one active owner';
  end if;

  select count(*) into v_eligible_active_owners
  from public.scenario_owners so
  join private.safra_role_grants rg
    on rg.principal_id = so.owner_id
   and rg.role = 'scenario_owner'
   and rg.revoked_at is null
  where so.scenario_id = v_scenario_id
    and so.valid_to is null;

  if v_eligible_active_owners <> 1 then
    raise exception 'published scenario owner must have active scenario_owner role';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function private.safra_validate_published_scenario() from public, anon, authenticated;

create constraint trigger trg_scenarios_validate_published
after insert or update on public.scenarios
deferrable initially deferred
for each row execute function private.safra_validate_published_scenario();
create constraint trigger trg_scenario_versions_validate_published
after insert or update or delete on public.scenario_versions
deferrable initially deferred
for each row execute function private.safra_validate_published_scenario();
create constraint trigger trg_scenario_owners_validate_published
after insert or update or delete on public.scenario_owners
deferrable initially deferred
for each row execute function private.safra_validate_published_scenario();

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
    where so.scenario_id = new.scenario_id and so.valid_to is null;

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

  if old.status <> 'ACTIVE' and new.status is distinct from old.status then
    raise exception 'closed treatment status is immutable';
  end if;

  if old.status = 'ACTIVE' and new.status not in ('ACTIVE','RESOLVED','CANCELLED') then
    raise exception 'invalid treatment state transition';
  end if;

  return new;
end;
$$;

revoke all on function private.safra_guard_treatment() from public, anon, authenticated;

create trigger trg_treatments_guard
before insert or update on public.treatments
for each row execute function private.safra_guard_treatment();

create or replace function private.safra_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% is append-only', tg_table_name;
end;
$$;

revoke all on function private.safra_append_only() from public, anon, authenticated;

create trigger trg_treatment_events_append_only
before update or delete on public.treatment_events
for each row execute function private.safra_append_only();

create trigger trg_treatment_impact_measurements_append_only
before update or delete on public.treatment_impact_measurements
for each row execute function private.safra_append_only();

alter table public.operational_areas enable row level security;
alter table public.systems enable row level security;
alter table public.scenarios enable row level security;
alter table public.scenario_versions enable row level security;
alter table public.scenario_owners enable row level security;
alter table public.scenario_version_impacted_areas enable row level security;
alter table public.scenario_version_systems enable row level security;
alter table public.scenario_slas enable row level security;
alter table public.treatments enable row level security;
alter table public.treatment_impacted_areas enable row level security;
alter table public.treatment_impact_measurements enable row level security;
alter table public.treatment_events enable row level security;
alter table public.treatment_escalations enable row level security;
alter table public.scenario_proposals enable row level security;
alter table public.scenario_proposal_owner_responses enable row level security;
alter table public.notifications_log enable row level security;
alter table public.governance_issues enable row level security;

revoke all on public.operational_areas from public, anon, authenticated;
revoke all on public.systems from public, anon, authenticated;
revoke all on public.scenarios from public, anon, authenticated;
revoke all on public.scenario_versions from public, anon, authenticated;
revoke all on public.scenario_owners from public, anon, authenticated;
revoke all on public.scenario_version_impacted_areas from public, anon, authenticated;
revoke all on public.scenario_version_systems from public, anon, authenticated;
revoke all on public.scenario_slas from public, anon, authenticated;
revoke all on public.treatments from public, anon, authenticated;
revoke all on public.treatment_impacted_areas from public, anon, authenticated;
revoke all on public.treatment_impact_measurements from public, anon, authenticated;
revoke all on public.treatment_events from public, anon, authenticated;
revoke all on public.treatment_escalations from public, anon, authenticated;
revoke all on public.scenario_proposals from public, anon, authenticated;
revoke all on public.scenario_proposal_owner_responses from public, anon, authenticated;
revoke all on public.notifications_log from public, anon, authenticated;
revoke all on public.governance_issues from public, anon, authenticated;

grant all on public.operational_areas to service_role;
grant all on public.systems to service_role;
grant all on public.scenarios to service_role;
grant all on public.scenario_versions to service_role;
grant all on public.scenario_owners to service_role;
grant all on public.scenario_version_impacted_areas to service_role;
grant all on public.scenario_version_systems to service_role;
grant all on public.scenario_slas to service_role;
grant all on public.treatments to service_role;
grant all on public.treatment_impacted_areas to service_role;
grant all on public.treatment_impact_measurements to service_role;
grant all on public.treatment_events to service_role;
grant all on public.treatment_escalations to service_role;
grant all on public.scenario_proposals to service_role;
grant all on public.scenario_proposal_owner_responses to service_role;
grant all on public.notifications_log to service_role;
grant all on public.governance_issues to service_role;

revoke truncate on public.operational_areas from service_role;
revoke truncate on public.systems from service_role;
revoke truncate on public.scenarios from service_role;
revoke truncate on public.scenario_versions from service_role;
revoke truncate on public.scenario_owners from service_role;
revoke truncate on public.scenario_version_impacted_areas from service_role;
revoke truncate on public.scenario_version_systems from service_role;
revoke truncate on public.scenario_slas from service_role;
revoke truncate on public.treatments from service_role;
revoke truncate on public.treatment_impacted_areas from service_role;
revoke truncate on public.treatment_impact_measurements from service_role;
revoke truncate on public.treatment_events from service_role;
revoke truncate on public.treatment_escalations from service_role;
revoke truncate on public.scenario_proposals from service_role;
revoke truncate on public.scenario_proposal_owner_responses from service_role;
revoke truncate on public.notifications_log from service_role;
revoke truncate on public.governance_issues from service_role;

insert into public.governance_issues(issue_key,title,description,status)
values (
  'GI-SAFRA-001',
  'Definição nominal dos quatro cenários CRITICAL',
  'A lista nominal dos quatro cenários CRITICAL permanece sem evidência suficiente. C06 não pode inferir criticidade; resolução futura deve ser registrada por governança e aplicada por versionamento.',
  'OPEN'
)
on conflict (issue_key) do nothing;

comment on table public.scenarios is 'Stable Safra scenario identity. Operational content belongs to scenario_versions.';
comment on table public.scenario_versions is 'Versioned operational snapshot. Published versions are immutable except transition to RETIRED.';
comment on table public.scenario_owners is 'Explicit temporal scenario ownership. Administrative roles do not imply ownership.';
comment on table public.treatments is 'Real Safra occurrence. START snapshots scenario version, owner and responsible area.';
comment on table public.treatment_events is 'Append-only operational event timeline.';
comment on table public.scenario_proposals is '12th-card proposal. It is not a productive scenario and cannot receive START.';
comment on table public.governance_issues is 'Material governance decisions kept explicit instead of replaced by defaults.';
