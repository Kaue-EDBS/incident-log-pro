begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

-- Drift de 28/09 reconstituído: o banco descartável agora tem o mesmo schema do PRIMARY.
select ok(
  exists(select 1 from pg_constraint where conname = 'notifications_delivery_status_check')
  and exists(select 1 from pg_constraint where conname = 'notifications_delivery_state_fields_check')
  and not exists(select 1 from pg_constraint where conname = 'notifications_status_not_blank'),
  'drift 20260928090910: notification delivery state machine constraints match PRIMARY'
);

select is(
  (select count(*)::bigint from pg_indexes where indexname in (
    'idx_governance_issues_resolved_by',
    'idx_scenario_proposal_owner_responses_candidate_owner_id',
    'idx_scenario_version_impacted_areas_operational_area_id',
    'idx_scenario_version_systems_system_id',
    'idx_treatment_impacted_areas_operational_area_id')),
  5::bigint,
  'drift 20260928095246: the five FK indexes exist'
);

select ok(
  not exists(select 1 from pg_trigger where tgname = 'trg_treatments_updated_at'),
  'drift 20260928095246: updated_at on treatments is owned only by the server clock trigger'
);

select is(
  (select count(*)::bigint from supabase_migrations.schema_migrations
   where version in ('20260928075934','20260928090910','20260928095246')),
  3::bigint,
  'the three 28/09 versions are now part of the repository history'
);

-- Máquina de estados dos avisos.
select throws_ok(
  $$ insert into public.notifications_log(notification_type, recipient_email, delivery_status, idempotency_key, correlation_id)
     values ('C05_AUD2', 'c05@example.invalid', 'SENT', 'c05aud2-sent-first', gen_random_uuid()) $$,
  'P0001', 'notification must start QUEUED',
  'a notification cannot be born SENT'
);

insert into public.notifications_log(notification_type, recipient_email, delivery_status, idempotency_key, correlation_id)
values ('C05_AUD2', 'c05@example.invalid', 'QUEUED', 'c05aud2-queued', gen_random_uuid());

select throws_ok(
  $$ update public.notifications_log set delivery_status = 'FAILED' where idempotency_key = 'c05aud2-queued' $$,
  'P0001', 'FAILED notification requires failure_reason',
  'FAILED notification requires a reason'
);

update public.notifications_log set delivery_status = 'SENT' where idempotency_key = 'c05aud2-queued';

select throws_ok(
  $$ update public.notifications_log set delivery_status = 'QUEUED' where idempotency_key = 'c05aud2-queued' $$,
  'P0001', 'terminal notification status is immutable',
  'SENT notification cannot go back'
);

-- D-73: escalonamento fora do schema.
select ok(
  to_regclass('public.treatment_escalations') is null
  and to_regprocedure('private.safra_guard_treatment_escalation_history()') is null,
  'D-73: treatment_escalations and its history guard are removed'
);

select ok(
  pg_get_constraintdef((select oid from pg_constraint where conname = 'treatment_events_type_check')) not like '%ESCALATION_CHANGED%',
  'D-73: ESCALATION_CHANGED is no longer an accepted event type'
);

-- Histórico de papéis não é apagado em cascata.
select is(
  (select count(*)::bigint from pg_constraint c join pg_namespace n on n.oid = c.connamespace
   where c.contype = 'f' and c.confdeltype = 'c' and n.nspname in ('public','private')),
  0::bigint,
  'no destructive ON DELETE CASCADE remains in public/private'
);

insert into private.safra_principals(corporate_email, display_name, is_active)
values ('c05aud2.history@editoradobrasil.com.br', 'C05 AUD2 History', true);
insert into private.safra_role_grants(principal_id, role, source)
select id, 'safra_executive_admin', 'C05_AUD2_HISTORY_TEST'
from private.safra_principals where corporate_email = 'c05aud2.history@editoradobrasil.com.br';

select throws_ok(
  $$ delete from private.safra_principals where corporate_email = 'c05aud2.history@editoradobrasil.com.br' $$,
  '23503', null,
  'a principal with role history cannot be deleted (deactivate instead)'
);

select is(
  (select count(*)::bigint from private.safra_role_grants where source = 'C05_AUD2_HISTORY_TEST'),
  1::bigint,
  'role history of the principal is preserved'
);

select is(
  (select count(*)::bigint from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'),
  19::bigint,
  'public schema holds the 15 Safra domain tables, ops_events (D-95), the analytics exclusion list (D-115) and the Safra marking tables (D-59)'
);

select * from finish();
rollback;
