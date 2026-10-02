-- SAFRA-C05-AUD2 — alinha o schema às decisões D-73 e à regra de histórico (01/10/2026).
--   1. D-73: escalonamento fica fora do Painel. Remove public.treatment_escalations (0 linhas),
--      seu guard de histórico e o tipo de evento ESCALATION_CHANGED.
--   2. Histórico de papéis: apagar um principal não pode apagar suas concessões de papel.
--      safra_role_grants.principal_id passa de ON DELETE CASCADE para ON DELETE RESTRICT;
--      principal se desativa (is_active = false), não se apaga.
-- Sem CASCADE: dependência desconhecida aborta a migration.

begin;

-- 1. Escalonamento -----------------------------------------------------------
do $$
begin
  if to_regclass('public.treatment_escalations') is not null
     and exists (select 1 from public.treatment_escalations) then
    raise exception 'C05-AUD2: treatment_escalations has rows; refusing to drop';
  end if;
  if exists (select 1 from public.treatment_events where event_type = 'ESCALATION_CHANGED') then
    raise exception 'C05-AUD2: ESCALATION_CHANGED events exist; refusing to retire the type';
  end if;
end;
$$;

drop trigger if exists trg_00_treatment_escalations_history on public.treatment_escalations;
drop table if exists public.treatment_escalations;
drop function if exists private.safra_guard_treatment_escalation_history();

alter table public.treatment_events drop constraint treatment_events_type_check;
alter table public.treatment_events
  add constraint treatment_events_type_check
  check (event_type = any (array[
    'TREATMENT_OPENED'::text,
    'NOTE_ADDED'::text,
    'IMPACT_AREA_ADDED'::text,
    'IMPACT_AREA_REMOVED'::text,
    'SLA_BREACHED'::text,
    'TREATMENT_RESOLVED'::text,
    'TREATMENT_CANCELLED'::text,
    'ADMIN_CORRECTION_RECORDED'::text
  ]));

-- 2. Histórico de papéis -----------------------------------------------------
alter table private.safra_role_grants drop constraint safra_role_grants_principal_id_fkey;
alter table private.safra_role_grants
  add constraint safra_role_grants_principal_id_fkey
  foreign key (principal_id) references private.safra_principals(id) on delete restrict;

-- Conferência ----------------------------------------------------------------
do $$
begin
  if to_regclass('public.treatment_escalations') is not null then
    raise exception 'C05-AUD2: treatment_escalations still present';
  end if;
  if exists (
    select 1 from pg_constraint c join pg_namespace n on n.oid = c.connamespace
    where c.contype = 'f' and c.confdeltype = 'c' and n.nspname in ('public','private')
  ) then
    raise exception 'C05-AUD2: destructive ON DELETE CASCADE still present';
  end if;
end;
$$;

commit;
