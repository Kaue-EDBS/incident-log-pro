-- C07-AUD2b (01/10/2026) — auditoria detalhada do SLA.
--
-- 1. safra_close_times passa a devolver também o total em segundos. O tipo interval
--    do PostgreSQL agrupa horas em dias ("2 days 01:15"); somado a um horário, esse
--    "dia" é de calendário. Para o analytics, segundos é o número seguro.
-- 2. Comentário da função de proteção das relações da versão sem citar SLA (D-75).
begin;

drop function private.safra_close_times(timestamptz, timestamptz, timestamptz, timestamptz);

create function private.safra_close_times(
  p_opened_at timestamptz,
  p_requester_closed_at timestamptz,
  p_owner_closed_at timestamptz,
  p_cancelled_at timestamptz
)
returns table(
  measurement_status text,
  requester_time interval,
  owner_time interval,
  consolidated_time interval,
  requester_seconds numeric,
  owner_seconds numeric,
  consolidated_seconds numeric
)
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_consolidated timestamptz;
begin
  if p_opened_at is null then
    raise exception using errcode = '22023', message = 'SAFRA_TIME_REQUIRED';
  end if;
  if p_requester_closed_at < p_opened_at
     or p_owner_closed_at < p_opened_at
     or p_cancelled_at < p_opened_at then
    raise exception using errcode = '22023', message = 'SAFRA_TIME_NEGATIVE';
  end if;

  if p_cancelled_at is not null then
    return query select 'CANCELLED'::text, null::interval, null::interval, null::interval,
                        null::numeric, null::numeric, null::numeric;
    return;
  end if;

  if p_requester_closed_at is not null and p_owner_closed_at is not null then
    v_consolidated := greatest(p_requester_closed_at, p_owner_closed_at);
  end if;

  return query select
    case when v_consolidated is not null then 'CLOSED' else 'IN_PROGRESS' end,
    p_requester_closed_at - p_opened_at,
    p_owner_closed_at - p_opened_at,
    v_consolidated - p_opened_at,
    extract(epoch from (p_requester_closed_at - p_opened_at)),
    extract(epoch from (p_owner_closed_at - p_opened_at)),
    extract(epoch from (v_consolidated - p_opened_at));
end;
$$;

revoke all on function private.safra_close_times(timestamptz, timestamptz, timestamptz, timestamptz) from public, anon, authenticated;

comment on function private.safra_guard_version_child_mutation() is
  'Freezes version-owned impacted areas and systems after scenario_version publication.';

commit;
