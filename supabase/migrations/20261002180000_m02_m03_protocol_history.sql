-- SAFRA-M02/M03 (02/10/2026) — histórico do protocolo (audit trail) e linha do tempo.
--
-- D-102 as áreas impactadas são escolhidas na abertura e não mudam depois.
-- D-103 sem notas no protocolo nesta Safra; a conversa do dia a dia segue por Teams/e-mail.
-- D-104 o histórico de um protocolo é visto por quem abriu, pelo dono do card, pela gestão
--       (Jair e Bruno) e pelos platform admins.
-- D-105 no histórico, quem fez cada coisa aparece pelo nome ("Sistema" no automático).
--
-- Registro só do que importa (M02): abertura, conclusão e desfazer de cada parte, encerramento
-- e cancelamento. SLA (D-75), escalonamento (D-73) e correção admin (D-100) não existem; avisos
-- entram na M05. Os eventos continuam só de acréscimo (gatilho do C05).
begin;

-- 1. Só os tipos de evento que existem de verdade ---------------------------------
alter table public.treatment_events drop constraint treatment_events_type_check;
alter table public.treatment_events
  add constraint treatment_events_type_check
  check (event_type = any (array[
    'TREATMENT_OPENED'::text,
    'REQUESTER_PART_CLOSED'::text,
    'OWNER_PART_CLOSED'::text,
    'REQUESTER_PART_UNDONE'::text,
    'OWNER_PART_UNDONE'::text,
    'TREATMENT_RESOLVED'::text,
    'TREATMENT_CANCELLED'::text
  ]));

-- 2. Áreas impactadas fixas depois da abertura (D-102) -----------------------------
create or replace function private.safra_guard_treatment_impacted_area_history()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_status text;
  v_created_at timestamptz;
begin
  if tg_op = 'DELETE' then
    raise exception 'treatment_impacted_areas history cannot be deleted';
  end if;

  if tg_op = 'UPDATE' then
    raise exception 'impacted areas are fixed after opening (D-102)';
  end if;

  select t.status, t.created_at into v_status, v_created_at
  from public.treatments t
  where t.id = new.treatment_id;

  if v_status <> 'ACTIVE' then
    raise exception 'impacted areas can only change while treatment is ACTIVE';
  end if;

  -- Só na mesma transação que abriu o protocolo.
  if v_created_at < transaction_timestamp() then
    raise exception 'impacted areas are fixed after opening (D-102)';
  end if;

  new.valid_from := v_now;
  new.created_at := v_now;
  new.valid_to := null;
  new.removed_by := null;
  return new;
end;
$$;

revoke all on function private.safra_guard_treatment_impacted_area_history() from public, anon, authenticated;

-- 3. Nome de quem fez (D-105) -------------------------------------------------------
-- Cadastro do Painel primeiro; depois o nome que veio da Microsoft; por fim o e-mail.
create or replace function private.safra_user_display_name(p_user_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select nullif(btrim(p.display_name), '') from private.safra_principals p where p.user_id = u.id),
    nullif(btrim(u.raw_user_meta_data->>'full_name'), ''),
    nullif(btrim(u.raw_user_meta_data->>'name'), ''),
    lower(u.email)
  )
  from auth.users u
  where u.id = p_user_id;
$$;

revoke all on function private.safra_user_display_name(uuid) from public, anon, authenticated;

-- 4. Linha do tempo de um protocolo (M02/M03, D-104) --------------------------------
create or replace function public.safra_get_treatment_timeline(p_treatment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_t public.treatments%rowtype;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_TIMELINE_FORBIDDEN';
  end if;

  select * into v_t from public.treatments where id = p_treatment_id;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_TIMELINE_FORBIDDEN';
  end if;

  if not (
    v_t.opened_by = v_actor
    or private.safra_current_owner_user_id(v_t.scenario_id) is not distinct from v_actor
    or v_t.owner_closed_by = v_actor
    or private.safra_has_role('safra_governance_admin')
    or private.safra_has_role('safra_executive_admin')
    or private.safra_has_role('safra_platform_admin')
  ) then
    raise exception using errcode = '42501', message = 'SAFRA_TIMELINE_FORBIDDEN';
  end if;

  return jsonb_build_object(
    'treatment', private.safra_treatment_view_json(v_t.id, v_actor),
    'scenario_version_no', (select sv.version_no from public.scenario_versions sv where sv.id = v_t.scenario_version_id),
    'opened_by_name', private.safra_user_display_name(v_t.opened_by),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'event_id', e.id,
        'occurred_at', e.occurred_at,
        'event_type', e.event_type,
        'actor_role', case
          when e.actor_user_id is null then 'SYSTEM'
          when e.actor_user_id = v_t.opened_by then 'REQUESTER'
          else 'OWNER'
        end,
        'actor_name', case
          when e.actor_user_id is null then 'Sistema'
          else private.safra_user_display_name(e.actor_user_id)
        end
      ) order by e.occurred_at, e.created_at, e.id)
      from public.treatment_events e
      where e.treatment_id = v_t.id
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.safra_get_treatment_timeline(uuid) from public, anon;
grant execute on function public.safra_get_treatment_timeline(uuid) to authenticated, service_role;

comment on function public.safra_get_treatment_timeline(uuid) is
  'M02/M03: append-only history of one protocol, readable by requester, card owner, governance (Jair/Bruno) and platform admins (D-104); actors by name (D-105).';

-- 5. GI-SAFRA-016 (auditoria do M01) — espelha docs/GOVERNANCE_ISSUES.md (D-53) ---------
insert into public.governance_issues(issue_key, title, description, status)
values (
  'GI-SAFRA-016',
  'Aviso antes do cancelamento automático de 72 h',
  'OPEN — DEFERRED_TO_M05. Pela D-101, protocolo sem nenhuma parte concluída é cancelado sozinho 72 horas depois da abertura. Hoje o único aviso é a frase na tela "Meus protocolos"; não há e-mail nem lembrete, porque os avisos dependem da M05 (e do chamado do TI para envio de e-mail). Decidir na M05: avisar antes (por exemplo, com 48 h), quem recebe (quem abriu, o dono do card, os dois) e por qual canal. Nenhum valor é assumido.',
  'OPEN'
)
on conflict (issue_key) do nothing;

commit;
