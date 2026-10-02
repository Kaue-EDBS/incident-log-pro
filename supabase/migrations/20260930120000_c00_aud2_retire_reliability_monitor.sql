-- SAFRA-C00-AUD2 — retire the legacy Reliability Monitor/MTTR domain.
-- Decision D-50 (30/09/2026): Painel Safra is the only product of incident-log-pro.
-- public.applications and public.incidents held only the fictitious XPTO/ABC/SEP demo seed.
-- No CASCADE on purpose: any unknown dependency must abort this migration instead of
-- being dropped silently.

begin;

drop trigger if exists incidents_validate on public.incidents;
drop trigger if exists incidents_updated_at on public.incidents;
drop trigger if exists applications_updated_at on public.applications;

drop table if exists public.incidents;
drop table if exists public.applications;

drop function if exists public.validate_incident_timestamps();
drop function if exists public.set_updated_at();

do $$
begin
  if to_regclass('public.incidents') is not null
     or to_regclass('public.applications') is not null
     or to_regprocedure('public.validate_incident_timestamps()') is not null
     or to_regprocedure('public.set_updated_at()') is not null then
    raise exception 'C00-AUD2: legacy Reliability Monitor objects still present';
  end if;
end;
$$;

commit;
