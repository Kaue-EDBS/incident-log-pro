-- D-135 (02/10/2026, owner): regras da proposta de card novo.
-- 1. O dono precisa aceitar: o Jair só orquestra e registra o dono entre quem aceitou
--    (antes podia escolher qualquer dono consultado, até quem recusou).
-- 2. Histórico da proposta (respostas dos donos, andamento e a nota da decisão) só para gestão,
--    executivo e admins, como o histórico do protocolo (D-108). Quem propôs vê a etapa e,
--    se recusada, o motivo; o dono consultado vê a própria resposta.
-- 3. Uma proposta em andamento por pessoa: a próxima depois de publicada ou recusada.
begin;

create or replace function public.safra_submit_proposal(p_title text, p_problem text, p_impact text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_title text := nullif(btrim(coalesce(p_title, '')), '');
  v_problem text := nullif(btrim(coalesce(p_problem, '')), '');
  v_impact text := nullif(btrim(coalesce(p_impact, '')), '');
  v_id uuid;
  v_email text;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_title is null or length(v_title) < 5 or length(v_title) > 150 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_TITLE_REQUIRED';
  end if;
  if v_problem is null or length(v_problem) < 10 or v_impact is null or length(v_impact) < 10 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_DESCRIPTION_REQUIRED';
  end if;
  if length(v_problem) > 3000 or length(v_impact) > 3000 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_TOO_LONG';
  end if;
  -- D-135: uma proposta em andamento por pessoa (a próxima depois de publicada ou recusada).
  if exists (select 1 from public.scenario_proposals sp
             where sp.proposed_by = v_actor and sp.status not in ('PUBLISHED', 'REJECTED')) then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_ONE_OPEN';
  end if;

  select lower(u.email) into v_email from auth.users u where u.id = v_actor;
  insert into public.scenario_proposals(proposed_by, proposer_name, proposer_email, title, problem_description, safra_impact_description)
  values (v_actor, private.safra_user_display_name(v_actor), v_email, v_title, v_problem, v_impact)
  returning id into v_id;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id) values (v_id, 'SUBMITTED', v_actor);

  perform private.safra_enqueue_proposal_notice('PROPOSAL_SUBMITTED', v_id,
    private.safra_principals_json(private.safra_role_principals('safra_governance_admin')), 'PR:' || v_id || ':SUBMITTED');
  return v_id;
end;
$$;

create or replace function public.safra_define_proposal_owner(p_proposal_id uuid, p_owner_principal_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_p public.scenario_proposals%rowtype;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_governance_admin') then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  select * into v_p from public.scenario_proposals where id = p_proposal_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_p.status <> 'OWNER_CONSULTATION' then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_WRONG_STEP';
  end if;
  if not exists (select 1 from private.safra_proposal_candidates() c where c = p_owner_principal_id) then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_INVALID_OWNER';
  end if;
  -- D-135: o dono precisa ter aceitado; o Jair só orquestra (registra entre quem aceitou).
  if not exists (select 1 from public.scenario_proposal_owner_responses r
                 where r.proposal_id = v_p.id and r.candidate_owner_id = p_owner_principal_id
                   and r.response = 'ACCEPTED') then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_OWNER_NOT_ACCEPTED';
  end if;
  if v_note is null or length(v_note) < 10 or length(v_note) > 1000 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_NOTE_REQUIRED';
  end if;

  perform private.safra_set_proposal_owner(v_p.id, p_owner_principal_id, 'GOVERNANCE_DECISION', v_note);
end;
$$;

create or replace function public.safra_get_proposals()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_me uuid := private.safra_actor_principal_id();
  v_all boolean;
  v_governance boolean;
  v_admin boolean;
  v_candidate boolean;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  v_governance := private.safra_has_role('safra_governance_admin');
  v_admin := private.safra_has_role('safra_platform_admin');
  v_all := v_governance or v_admin or private.safra_has_role('safra_executive_admin');
  v_candidate := v_me is not null and exists (select 1 from private.safra_proposal_candidates() c where c = v_me);

  return jsonb_build_object(
    'me', jsonb_build_object('name', private.safra_user_display_name(v_actor),
                             'email', (select lower(u.email) from auth.users u where u.id = v_actor),
                             'is_candidate', v_candidate),
    'candidates', (select coalesce(jsonb_agg(jsonb_build_object('principal_id', p.id,
                     'name', coalesce(nullif(btrim(p.display_name), ''), p.corporate_email)) order by p.display_name), '[]'::jsonb)
                   from private.safra_principals p where p.id in (select private.safra_proposal_candidates())),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'proposal_id', sp.id,
        'status', sp.status,
        'title', sp.title,
        'problem_description', sp.problem_description,
        'safra_impact_description', sp.safra_impact_description,
        'proposer_name', sp.proposer_name,
        'submitted_at', sp.submitted_at,
        'mine', sp.proposed_by = v_actor,
        'owner_name', (select coalesce(nullif(btrim(p.display_name), ''), p.corporate_email) from private.safra_principals p where p.id = sp.owner_principal_id),
        'owner_decision', sp.owner_decision,
        'owner_note', case when v_all then sp.owner_note end,
        'scenario_name', sp.scenario_name,
        'trigger_description', sp.trigger_description,
        'detection_description', sp.detection_description,
        'protocol_text', sp.protocol_text,
        'expected_impact_summary', sp.expected_impact_summary,
        'impacted_area_ids', to_jsonb(sp.impacted_area_ids),
        'responsible_area', (select oa.name from public.operational_areas oa where oa.id = sp.responsible_area_id),
        'published_code', (select sc.code from public.scenarios sc where sc.id = sp.scenario_id),
        'rejection_reason', sp.rejection_reason,
        -- D-135: histórico (respostas e andamento) só para gestão, executivo e admins (como a D-108).
        'responses', case when not v_all then '[]'::jsonb else coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', coalesce(nullif(btrim(p.display_name), ''), p.corporate_email),
            'response', r.response, 'note', r.response_note, 'responded_at', r.responded_at) order by r.responded_at)
          from public.scenario_proposal_owner_responses r join private.safra_principals p on p.id = r.candidate_owner_id
          where r.proposal_id = sp.id), '[]'::jsonb) end,
        'my_response', (select r.response from public.scenario_proposal_owner_responses r
                        where r.proposal_id = sp.id and r.candidate_owner_id = v_me),
        'events', case when not v_all then '[]'::jsonb else coalesce((
          select jsonb_agg(jsonb_build_object('event_type', e.event_type, 'occurred_at', e.occurred_at,
                   'actor_name', case when e.actor_user_id is null then 'Sistema' else private.safra_user_display_name(e.actor_user_id) end,
                   'note', e.note) order by e.occurred_at, e.id)
          from public.scenario_proposal_events e where e.proposal_id = sp.id), '[]'::jsonb) end,
        'can_forward', v_governance and sp.status = 'SUBMITTED',
        'can_respond', v_candidate and sp.status = 'OWNER_CONSULTATION',
        'can_define_owner', v_governance and sp.status = 'OWNER_CONSULTATION'
          and exists (select 1 from public.scenario_proposal_owner_responses r
                      where r.proposal_id = sp.id and r.response = 'ACCEPTED'),
        'accepted_principal_ids', coalesce((select jsonb_agg(r.candidate_owner_id)
          from public.scenario_proposal_owner_responses r
          where r.proposal_id = sp.id and r.response = 'ACCEPTED' and v_governance), '[]'::jsonb),
        'can_submit_content', sp.proposed_by = v_actor and sp.status in ('OWNER_DEFINED', 'CONTENT_SUBMITTED'),
        'can_approve', sp.status = 'CONTENT_SUBMITTED' and coalesce(private.safra_can_approve_proposal(sp.proposed_by), false),
        'can_reject', sp.status not in ('PUBLISHED', 'REJECTED') and coalesce(private.safra_can_approve_proposal(sp.proposed_by), false),
        'can_publish', v_admin and sp.status = 'APPROVED' and sp.proposed_by <> v_actor and sp.approved_by is distinct from v_actor
      ) order by sp.submitted_at desc)
      from public.scenario_proposals sp
      where v_all
         or sp.proposed_by = v_actor
         or (v_candidate and sp.forwarded_at is not null)
    ), '[]'::jsonb)
  );
end;
$$;

commit;
