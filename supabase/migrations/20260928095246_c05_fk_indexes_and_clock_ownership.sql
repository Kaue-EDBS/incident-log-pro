-- RECONSTITUÍDA em 01/10/2026 (C05-AUD2, D-52) a partir das definições vigentes no PRIMARY.
-- Versão aplicada no PRIMARY em 28/09/2026 fora do repositório; SQL original não preservado.
-- Efeitos:
--   1. índices para as chaves estrangeiras que ainda não tinham índice;
--   2. "clock ownership": updated_at passa a ser responsabilidade exclusiva dos gatilhos
--      de relógio do servidor (trg_00_*_server_clock). Sai o gatilho duplicado de
--      treatments e a escrita de updated_at no guard de scenario_versions.
-- Idempotente: reaplicar no PRIMARY não altera nada.

create index if not exists idx_governance_issues_resolved_by
  on public.governance_issues using btree (resolved_by);
create index if not exists idx_scenario_proposal_owner_responses_candidate_owner_id
  on public.scenario_proposal_owner_responses using btree (candidate_owner_id);
create index if not exists idx_scenario_version_impacted_areas_operational_area_id
  on public.scenario_version_impacted_areas using btree (operational_area_id);
create index if not exists idx_scenario_version_systems_system_id
  on public.scenario_version_systems using btree (system_id);
create index if not exists idx_treatment_impacted_areas_operational_area_id
  on public.treatment_impacted_areas using btree (operational_area_id);

drop trigger if exists trg_treatments_updated_at on public.treatments;

create or replace function private.safra_guard_scenario_version_update()
 returns trigger
 language plpgsql
 set search_path to ''
as $function$
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

  return new;
end;
$function$;

revoke all on function private.safra_guard_scenario_version_update() from public, anon, authenticated;
