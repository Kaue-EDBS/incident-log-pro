-- SAFRA-M10 (02/10/2026) — governança do 12º card (proposta de card novo).
--
-- D-60  quem propõe escreve o conteúdo; o Jair aprova; um platform admin publica a primeira
--       versão; o card novo nasce CRITICAL. Sem SLA (D-62/D-75).
-- D-68  separação de funções: quem propõe não aprova nem publica; proposta do Jair é aprovada
--       pelo Kaue; quem aprova não publica.
-- D-125 qualquer pessoa com login corporativo propõe (nome e e-mail vêm da sessão Microsoft).
-- D-126 o Jair encaminha aos donos de card (Daniel, Renato, Jiane); respondidos todos, se
--       exatamente 1 aceitou, ele vira o dono; nos outros casos (2+ aceites ou nenhum), os donos
--       conversam numa reunião fora do Painel e o Jair registra o dono escolhido.
-- D-127 campos obrigatórios antes de aprovar: nome do card, gatilho, como se detecta, protocolo,
--       impacto esperado e áreas que podem ser impactadas (escritos por quem propôs); dono e área
--       responsável definidos pelo Jair. Nada é completado por inferência.
-- D-128 fluxo: proposta -> consulta aos donos -> dono definido -> conteúdo -> aprovação (Jair,
--       com a área responsável) -> publicação por um admin como SAFRA-NN, CRITICAL, versão 1.
--       Publicar nunca reescreve versão publicada (gatilhos do C05); mudar card publicado fica
--       para depois.
-- D-129 avisos por e-mail da M10 pela fila da M05 (saem quando o TI liberar o envio).
-- D-130 o Jair pode recusar a proposta, com motivo, em qualquer etapa antes da publicação
--       (proposta do Jair: o Kaue recusa, como na aprovação da D-68); quem propôs é avisado.
begin;

-- 1. Proposta com estado e conteúdo -------------------------------------------------------
alter table public.scenario_proposals
  add column status text not null default 'SUBMITTED',
  add column forwarded_at timestamptz,
  add column forwarded_by uuid references auth.users(id) on delete restrict,
  add column owner_principal_id uuid references private.safra_principals(id) on delete restrict,
  add column owner_decision text,
  add column owner_note text,
  add column owner_defined_at timestamptz,
  add column owner_defined_by uuid references auth.users(id) on delete restrict,
  add column scenario_name text,
  add column trigger_description text,
  add column detection_description text,
  add column protocol_text text,
  add column expected_impact_summary text,
  add column impacted_area_ids uuid[] not null default '{}',
  add column content_submitted_at timestamptz,
  add column responsible_area_id uuid references public.operational_areas(id) on delete restrict,
  add column approved_at timestamptz,
  add column approved_by uuid references auth.users(id) on delete restrict,
  add column published_at timestamptz,
  add column published_by uuid references auth.users(id) on delete restrict,
  add column scenario_id uuid references public.scenarios(id) on delete restrict,
  add column rejected_at timestamptz,
  add column rejected_by uuid references auth.users(id) on delete restrict,
  add column rejection_reason text,
  add constraint scenario_proposals_status_check check (status in (
    'SUBMITTED', 'OWNER_CONSULTATION', 'OWNER_DEFINED', 'CONTENT_SUBMITTED', 'APPROVED', 'PUBLISHED', 'REJECTED')),
  add constraint scenario_proposals_rejection_check check (
    (status = 'REJECTED') = (rejected_at is not null and rejected_by is not null and length(btrim(coalesce(rejection_reason, ''))) between 10 and 1000)),
  add constraint scenario_proposals_owner_decision_check check (
    owner_decision is null or owner_decision in ('SINGLE_ACCEPT', 'GOVERNANCE_DECISION')),
  add constraint scenario_proposals_title_len check (length(title) <= 150),
  add constraint scenario_proposals_problem_len check (length(problem_description) <= 3000),
  add constraint scenario_proposals_impact_len check (length(safra_impact_description) <= 3000),
  add constraint scenario_proposals_published_has_scenario check ((status = 'PUBLISHED') = (scenario_id is not null));

create index if not exists idx_scenario_proposals_proposed_by on public.scenario_proposals(proposed_by);
create index if not exists idx_scenario_proposals_owner on public.scenario_proposals(owner_principal_id);
create index if not exists idx_scenario_proposals_scenario on public.scenario_proposals(scenario_id);
create index if not exists idx_scenario_proposals_area on public.scenario_proposals(responsible_area_id);
create index if not exists idx_scenario_proposals_forwarded_by on public.scenario_proposals(forwarded_by);
create index if not exists idx_scenario_proposals_owner_defined_by on public.scenario_proposals(owner_defined_by);
create index if not exists idx_scenario_proposals_approved_by on public.scenario_proposals(approved_by);
create index if not exists idx_scenario_proposals_published_by on public.scenario_proposals(published_by);
create index if not exists idx_scenario_proposals_rejected_by on public.scenario_proposals(rejected_by);

create table public.scenario_proposal_events (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.scenario_proposals(id) on delete restrict,
  event_type text not null,
  actor_user_id uuid references auth.users(id) on delete restrict,
  occurred_at timestamptz not null default clock_timestamp(),
  note text,
  constraint scenario_proposal_events_type_check check (event_type in (
    'SUBMITTED', 'FORWARDED', 'OWNER_ACCEPTED', 'OWNER_DECLINED', 'OWNER_DEFINED',
    'CONTENT_SUBMITTED', 'APPROVED', 'PUBLISHED', 'REJECTED')),
  constraint scenario_proposal_events_note_len check (note is null or length(note) <= 1000)
);

create index if not exists idx_scenario_proposal_events_proposal on public.scenario_proposal_events(proposal_id, occurred_at);
create index if not exists idx_scenario_proposal_events_actor on public.scenario_proposal_events(actor_user_id);

create or replace function private.safra_proposal_events_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'proposal history is append-only';
end;
$$;

revoke all on function private.safra_proposal_events_append_only() from public, anon, authenticated;

create trigger trg_scenario_proposal_events_append_only
before update or delete on public.scenario_proposal_events
for each row execute function private.safra_proposal_events_append_only();

alter table public.scenario_proposal_events enable row level security;
revoke all on public.scenario_proposal_events from public, anon, authenticated;

-- 2. Quem é quem ----------------------------------------------------------------------------
create or replace function private.safra_actor_principal_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id from private.safra_principals p where p.user_id = (select auth.uid()) and p.is_active
$$;

-- Donos consultados: quem tem o papel de dono de card hoje (Daniel, Renato, Jiane).
create or replace function private.safra_proposal_candidates()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from private.safra_principals p
  where p.is_active
    and exists (select 1 from private.safra_role_grants rg
                where rg.principal_id = p.id and rg.role = 'scenario_owner' and rg.revoked_at is null)
$$;

create or replace function private.safra_user_has_role(p_user_id uuid, p_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from private.safra_principals p
    join private.safra_role_grants rg on rg.principal_id = p.id and rg.revoked_at is null
    where p.user_id = p_user_id and p.is_active and rg.role = p_role)
$$;

-- D-68: quem aprova. Proposta de quem tem governança (Jair) é aprovada pelo Kaue.
create or replace function private.safra_can_approve_proposal(p_proposed_by uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
     and (select auth.uid()) <> p_proposed_by
     and coalesce(public.safra_is_corporate_user(), false)
     and case
           when private.safra_user_has_role(p_proposed_by, 'safra_governance_admin')
             then coalesce(private.safra_is_season_manager(), false)
           else private.safra_has_role('safra_governance_admin')
         end
$$;

revoke all on function private.safra_actor_principal_id() from public, anon, authenticated;
revoke all on function private.safra_proposal_candidates() from public, anon, authenticated;
revoke all on function private.safra_user_has_role(uuid, text) from public, anon, authenticated;
revoke all on function private.safra_can_approve_proposal(uuid) from public, anon, authenticated;

-- 3. Avisos da M10 (D-129) -----------------------------------------------------------------
create or replace function private.safra_enqueue_proposal_notice(
  p_type text,
  p_proposal_id uuid,
  p_recipients jsonb,  -- [{email, name, principal_id}]
  p_key_prefix text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_p public.scenario_proposals%rowtype;
  v_subject text;
  v_head text;
  v_count integer := 0;
  r record;
begin
  select * into v_p from public.scenario_proposals where id = p_proposal_id;

  case p_type
    when 'PROPOSAL_SUBMITTED' then
      v_subject := 'Nova proposta de card: ' || v_p.title;
      v_head := v_p.proposer_name || ' propôs um card novo. Encaminhe aos donos de card para avaliarem quem assume.';
    when 'PROPOSAL_OWNER_REQUEST' then
      v_subject := 'Você assume o card proposto? ' || v_p.title;
      v_head := 'O Jair pediu que você diga se aceita ser dono deste card novo. Responda no Painel.';
    when 'PROPOSAL_OWNER_DEFINED' then
      v_subject := 'Dono definido para a proposta: ' || v_p.title;
      v_head := 'O dono do card proposto foi definido. Quem propôs completa agora o conteúdo do card no Painel.';
    when 'PROPOSAL_CONTENT_SUBMITTED' then
      v_subject := 'Proposta pronta para aprovação: ' || v_p.title;
      v_head := 'O conteúdo do card proposto foi completado e aguarda a sua aprovação no Painel.';
    when 'PROPOSAL_APPROVED' then
      v_subject := 'Proposta aprovada: ' || v_p.title;
      v_head := 'A proposta foi aprovada e aguarda a publicação por um administrador.';
    when 'PROPOSAL_PUBLISHED' then
      v_subject := 'Card publicado: ' || coalesce(v_p.scenario_name, v_p.title);
      v_head := 'O card novo foi publicado e já pode receber protocolos.';
    when 'PROPOSAL_REJECTED' then
      v_subject := 'Proposta recusada: ' || v_p.title;
      v_head := 'A proposta foi recusada. Motivo: ' || coalesce(v_p.rejection_reason, '—');
    else
      raise exception 'unknown proposal notice %', p_type;
  end case;

  for r in
    select distinct on (lower(x->>'email')) lower(x->>'email') as email, x->>'name' as name,
           nullif(x->>'principal_id', '')::uuid as principal_id
    from jsonb_array_elements(coalesce(p_recipients, '[]'::jsonb)) x
    where btrim(coalesce(x->>'email', '')) <> ''
    order by lower(x->>'email')
  loop
    insert into public.notifications_log(
      proposal_id, notification_type, recipient_email, recipient_principal_id, recipient_name,
      channel, provider, delivery_status, idempotency_key, correlation_id, template_version, subject, body)
    values (
      v_p.id, p_type, r.email, r.principal_id, r.name, 'EMAIL', 'MS_GRAPH', 'QUEUED',
      p_key_prefix || ':' || r.email, gen_random_uuid(), 1,
      '[Painel Safra] ' || v_subject,
      'Olá, ' || coalesce(nullif(btrim(r.name), ''), 'tudo bem') || '.' || E'\n\n' || v_head || E'\n\n'
        || 'Proposta: ' || v_p.title || E'\n'
        || 'Proposta por: ' || v_p.proposer_name || E'\n'
        || 'Problema: ' || v_p.problem_description || E'\n'
        || 'Como afeta a Safra: ' || v_p.safra_impact_description || E'\n\n'
        || 'Abrir no Painel: ' || private.safra_app_url() || '/propostas' || E'\n\n'
        || 'Aviso automático do Painel Safra. Não responda este e-mail.')
    on conflict (idempotency_key) do nothing;
    if found then v_count := v_count + 1; end if;
  end loop;
  return v_count;
end;
$$;

revoke all on function private.safra_enqueue_proposal_notice(text, uuid, jsonb, text) from public, anon, authenticated;

-- Destinatários prontos (e-mail, nome, principal).
create or replace function private.safra_principals_json(p_ids uuid[])
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'email', p.corporate_email, 'name', coalesce(nullif(btrim(p.display_name), ''), p.corporate_email), 'principal_id', p.id)), '[]'::jsonb)
  from private.safra_principals p where p.id = any (p_ids) and p.is_active
$$;

create or replace function private.safra_role_principals(p_role text)
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(p.id), '{}')
  from private.safra_principals p
  join private.safra_role_grants rg on rg.principal_id = p.id and rg.revoked_at is null and rg.role = p_role
  where p.is_active
$$;

revoke all on function private.safra_principals_json(uuid[]) from public, anon, authenticated;
revoke all on function private.safra_role_principals(text) from public, anon, authenticated;

-- 4. Comandos ------------------------------------------------------------------------------
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

create or replace function public.safra_forward_proposal(p_proposal_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_p public.scenario_proposals%rowtype;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_governance_admin') then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  select * into v_p from public.scenario_proposals where id = p_proposal_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_p.status <> 'SUBMITTED' then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_WRONG_STEP';
  end if;

  update public.scenario_proposals
     set status = 'OWNER_CONSULTATION', forwarded_at = clock_timestamp(), forwarded_by = v_actor
   where id = v_p.id;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id) values (v_p.id, 'FORWARDED', v_actor);
  perform private.safra_enqueue_proposal_notice('PROPOSAL_OWNER_REQUEST', v_p.id,
    private.safra_principals_json(array(select private.safra_proposal_candidates())), 'PR:' || v_p.id || ':OWNER_REQUEST');
end;
$$;

-- Define o dono e avisa quem propôs (uso interno).
create or replace function private.safra_set_proposal_owner(p_proposal_id uuid, p_owner uuid, p_decision text, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_p public.scenario_proposals%rowtype;
begin
  update public.scenario_proposals
     set status = 'OWNER_DEFINED', owner_principal_id = p_owner, owner_decision = p_decision,
         owner_note = p_note, owner_defined_at = clock_timestamp(), owner_defined_by = v_actor
   where id = p_proposal_id
  returning * into v_p;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id, note)
  values (p_proposal_id, 'OWNER_DEFINED', v_actor,
          case p_decision when 'SINGLE_ACCEPT' then 'Único aceite entre os donos consultados (D-126).'
                          else coalesce(p_note, 'Decisão registrada pela governança (D-126).') end);
  perform private.safra_enqueue_proposal_notice('PROPOSAL_OWNER_DEFINED', p_proposal_id,
    jsonb_build_array(jsonb_build_object('email', v_p.proposer_email, 'name', v_p.proposer_name))
      || private.safra_principals_json(array[p_owner]),
    'PR:' || p_proposal_id || ':OWNER_DEFINED');
end;
$$;

revoke all on function private.safra_set_proposal_owner(uuid, uuid, text, text) from public, anon, authenticated;

create or replace function public.safra_respond_proposal(p_proposal_id uuid, p_accept boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_me uuid := private.safra_actor_principal_id();
  v_p public.scenario_proposals%rowtype;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_candidates integer;
  v_answers integer;
  v_accepts integer;
  v_single uuid;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false)
     or v_me is null or not exists (select 1 from private.safra_proposal_candidates() c where c = v_me) then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  select * into v_p from public.scenario_proposals where id = p_proposal_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_p.status <> 'OWNER_CONSULTATION' then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_WRONG_STEP';
  end if;
  if v_note is not null and length(v_note) > 1000 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_TOO_LONG';
  end if;

  insert into public.scenario_proposal_owner_responses(proposal_id, candidate_owner_id, response, response_note)
  values (v_p.id, v_me, case when p_accept then 'ACCEPTED' else 'DECLINED' end, v_note)
  on conflict (proposal_id, candidate_owner_id)
  do update set response = excluded.response, response_note = excluded.response_note;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id, note)
  values (v_p.id, case when p_accept then 'OWNER_ACCEPTED' else 'OWNER_DECLINED' end, v_actor, v_note);

  -- D-126: todos responderam e exatamente 1 aceitou -> ele é o dono.
  select count(*) into v_candidates from private.safra_proposal_candidates();
  select count(*), count(*) filter (where r.response = 'ACCEPTED'),
         (array_agg(r.candidate_owner_id) filter (where r.response = 'ACCEPTED'))[1]
    into v_answers, v_accepts, v_single
  from public.scenario_proposal_owner_responses r
  where r.proposal_id = v_p.id and r.candidate_owner_id in (select private.safra_proposal_candidates());

  if v_answers >= v_candidates and v_accepts = 1 then
    perform private.safra_set_proposal_owner(v_p.id, v_single, 'SINGLE_ACCEPT', null);
  end if;
end;
$$;

-- D-126: 2+ aceites ou nenhum (reunião fora do Painel): o Jair registra o dono escolhido.
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
  if v_note is null or length(v_note) < 10 or length(v_note) > 1000 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_NOTE_REQUIRED';
  end if;

  perform private.safra_set_proposal_owner(v_p.id, p_owner_principal_id, 'GOVERNANCE_DECISION', v_note);
end;
$$;

-- D-127: quem propôs escreve o conteúdo (pode corrigir até a aprovação).
create or replace function public.safra_submit_proposal_content(
  p_proposal_id uuid,
  p_scenario_name text,
  p_trigger text,
  p_detection text,
  p_protocol text,
  p_expected_impact text,
  p_impacted_area_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_p public.scenario_proposals%rowtype;
  v_areas uuid[];
  v_first boolean;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  select * into v_p from public.scenario_proposals where id = p_proposal_id for update;
  if not found or v_p.proposed_by <> v_actor then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_p.status not in ('OWNER_DEFINED', 'CONTENT_SUBMITTED') then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_WRONG_STEP';
  end if;
  if length(btrim(coalesce(p_scenario_name, ''))) not between 5 and 150
     or length(btrim(coalesce(p_trigger, ''))) < 10
     or length(btrim(coalesce(p_detection, ''))) < 10
     or length(btrim(coalesce(p_protocol, ''))) < 10
     or length(btrim(coalesce(p_expected_impact, ''))) < 10 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_CONTENT_REQUIRED';
  end if;
  if greatest(length(p_trigger), length(p_detection), length(p_protocol), length(p_expected_impact)) > 3000 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_TOO_LONG';
  end if;
  select coalesce(array_agg(distinct a order by a), '{}') into v_areas from unnest(coalesce(p_impacted_area_ids, '{}')) a;
  if cardinality(v_areas) = 0
     or exists (select 1 from unnest(v_areas) a where not exists (select 1 from public.operational_areas oa where oa.id = a)) then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_AREAS_REQUIRED';
  end if;

  v_first := v_p.status = 'OWNER_DEFINED';
  update public.scenario_proposals
     set status = 'CONTENT_SUBMITTED',
         scenario_name = btrim(p_scenario_name), trigger_description = btrim(p_trigger),
         detection_description = btrim(p_detection), protocol_text = btrim(p_protocol),
         expected_impact_summary = btrim(p_expected_impact), impacted_area_ids = v_areas,
         content_submitted_at = clock_timestamp()
   where id = v_p.id;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id, note)
  values (v_p.id, 'CONTENT_SUBMITTED', v_actor, case when v_first then null else 'Conteúdo corrigido.' end);

  if v_first then
    perform private.safra_enqueue_proposal_notice('PROPOSAL_CONTENT_SUBMITTED', v_p.id,
      case when private.safra_user_has_role(v_p.proposed_by, 'safra_governance_admin')
           then (select private.safra_principals_json(array_agg(p.id)) from private.safra_principals p
                 where lower(p.corporate_email) = 'kaue.pastrello@editoradobrasil.com.br')
           else private.safra_principals_json(private.safra_role_principals('safra_governance_admin')) end,
      'PR:' || v_p.id || ':CONTENT');
  end if;
end;
$$;

-- D-60/D-68: o Jair aprova (proposta do Jair: o Kaue) e define a área responsável.
create or replace function public.safra_approve_proposal(p_proposal_id uuid, p_responsible_area_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_p public.scenario_proposals%rowtype;
  v_publishers uuid[];
begin
  select * into v_p from public.scenario_proposals where id = p_proposal_id for update;
  if not found or not coalesce(private.safra_can_approve_proposal(v_p.proposed_by), false) then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_p.status <> 'CONTENT_SUBMITTED' then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_WRONG_STEP';
  end if;
  if not exists (select 1 from public.operational_areas oa where oa.id = p_responsible_area_id) then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_AREA_REQUIRED';
  end if;

  update public.scenario_proposals
     set status = 'APPROVED', responsible_area_id = p_responsible_area_id,
         approved_at = clock_timestamp(), approved_by = v_actor
   where id = v_p.id;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id) values (v_p.id, 'APPROVED', v_actor);

  -- Avisa quem propôs e os admins que podem publicar (nem quem propôs, nem quem aprovou).
  select coalesce(array_agg(p.id), '{}') into v_publishers
  from private.safra_principals p
  where p.id = any (private.safra_role_principals('safra_platform_admin'))
    and p.user_id is distinct from v_p.proposed_by and p.user_id is distinct from v_actor;
  perform private.safra_enqueue_proposal_notice('PROPOSAL_APPROVED', v_p.id,
    jsonb_build_array(jsonb_build_object('email', v_p.proposer_email, 'name', v_p.proposer_name))
      || private.safra_principals_json(v_publishers),
    'PR:' || v_p.id || ':APPROVED');
end;
$$;

-- D-60/D-68/D-128: um admin (que não propôs nem aprovou) publica como SAFRA-NN, CRITICAL, v1.
create or replace function public.safra_publish_proposal(p_proposal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_p public.scenario_proposals%rowtype;
  v_number integer;
  v_code text;
  v_scenario uuid;
  v_version uuid;
begin
  if v_actor is null or not coalesce(public.safra_is_corporate_user(), false)
     or not private.safra_has_role('safra_platform_admin') then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  select * into v_p from public.scenario_proposals where id = p_proposal_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_p.proposed_by = v_actor or v_p.approved_by = v_actor then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_SEPARATION_OF_DUTIES';
  end if;
  if v_p.status <> 'APPROVED' then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_WRONG_STEP';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('safra_new_card_number', 0));
  select coalesce(max(substring(code from '^SAFRA-([0-9]+)$')::integer), 0) + 1 into v_number
  from public.scenarios;
  v_code := 'SAFRA-' || lpad(v_number::text, 2, '0');

  insert into public.scenarios(code, name, lifecycle_status, responsible_area_id)
  values (v_code, v_p.scenario_name, 'ACTIVE', v_p.responsible_area_id)
  returning id into v_scenario;

  insert into public.scenario_versions(scenario_id, version_no, status, trigger_description, detection_description,
                                       protocol_text, expected_impact_summary, criticality, source_reference, created_by)
  values (v_scenario, 1, 'DRAFT', v_p.trigger_description, v_p.detection_description, v_p.protocol_text,
          v_p.expected_impact_summary, 'CRITICAL', 'M10 proposta ' || v_p.id, v_actor)
  returning id into v_version;

  insert into public.scenario_version_impacted_areas(scenario_version_id, operational_area_id)
  select v_version, a from unnest(v_p.impacted_area_ids) a;

  update public.scenario_versions set status = 'PUBLISHED' where id = v_version;
  update public.scenarios set current_version_id = v_version where id = v_scenario;

  insert into public.scenario_owners(scenario_id, owner_id, assigned_by, assignment_reason)
  values (v_scenario, v_p.owner_principal_id, v_actor, 'M10: dono definido na proposta ' || v_p.id || ' (D-126).');

  update public.scenario_proposals
     set status = 'PUBLISHED', published_at = clock_timestamp(), published_by = v_actor, scenario_id = v_scenario
   where id = v_p.id;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id, note)
  values (v_p.id, 'PUBLISHED', v_actor, v_code);

  perform private.safra_enqueue_proposal_notice('PROPOSAL_PUBLISHED', v_p.id,
    jsonb_build_array(jsonb_build_object('email', v_p.proposer_email, 'name', v_p.proposer_name))
      || private.safra_principals_json(array[v_p.owner_principal_id])
      || private.safra_principals_json(private.safra_role_principals('safra_governance_admin')),
    'PR:' || v_p.id || ':PUBLISHED');

  return jsonb_build_object('scenario_id', v_scenario, 'code', v_code, 'version_no', 1);
end;
$$;

-- D-130: recusar com motivo, antes da publicação.
create or replace function public.safra_reject_proposal(p_proposal_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_p public.scenario_proposals%rowtype;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  select * into v_p from public.scenario_proposals where id = p_proposal_id for update;
  if not found or not coalesce(private.safra_can_approve_proposal(v_p.proposed_by), false) then
    raise exception using errcode = '42501', message = 'SAFRA_PROPOSAL_FORBIDDEN';
  end if;
  if v_p.status in ('PUBLISHED', 'REJECTED') then
    raise exception using errcode = 'P0001', message = 'SAFRA_PROPOSAL_WRONG_STEP';
  end if;
  if v_reason is null or length(v_reason) < 10 or length(v_reason) > 1000 then
    raise exception using errcode = '22023', message = 'SAFRA_PROPOSAL_NOTE_REQUIRED';
  end if;

  update public.scenario_proposals
     set status = 'REJECTED', rejected_at = clock_timestamp(), rejected_by = v_actor, rejection_reason = v_reason
   where id = v_p.id
  returning * into v_p;
  insert into public.scenario_proposal_events(proposal_id, event_type, actor_user_id, note)
  values (v_p.id, 'REJECTED', v_actor, v_reason);
  perform private.safra_enqueue_proposal_notice('PROPOSAL_REJECTED', v_p.id,
    jsonb_build_array(jsonb_build_object('email', v_p.proposer_email, 'name', v_p.proposer_name))
      || case when v_p.owner_principal_id is null then '[]'::jsonb else private.safra_principals_json(array[v_p.owner_principal_id]) end,
    'PR:' || v_p.id || ':REJECTED');
end;
$$;

-- 5. Leitura --------------------------------------------------------------------------------
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
        'owner_note', sp.owner_note,
        'scenario_name', sp.scenario_name,
        'trigger_description', sp.trigger_description,
        'detection_description', sp.detection_description,
        'protocol_text', sp.protocol_text,
        'expected_impact_summary', sp.expected_impact_summary,
        'impacted_area_ids', to_jsonb(sp.impacted_area_ids),
        'responsible_area', (select oa.name from public.operational_areas oa where oa.id = sp.responsible_area_id),
        'published_code', (select sc.code from public.scenarios sc where sc.id = sp.scenario_id),
        'rejection_reason', sp.rejection_reason,
        'responses', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', coalesce(nullif(btrim(p.display_name), ''), p.corporate_email),
            'response', r.response, 'note', r.response_note, 'responded_at', r.responded_at) order by r.responded_at)
          from public.scenario_proposal_owner_responses r join private.safra_principals p on p.id = r.candidate_owner_id
          where r.proposal_id = sp.id), '[]'::jsonb),
        'my_response', (select r.response from public.scenario_proposal_owner_responses r
                        where r.proposal_id = sp.id and r.candidate_owner_id = v_me),
        'events', coalesce((
          select jsonb_agg(jsonb_build_object('event_type', e.event_type, 'occurred_at', e.occurred_at,
                   'actor_name', case when e.actor_user_id is null then 'Sistema' else private.safra_user_display_name(e.actor_user_id) end,
                   'note', e.note) order by e.occurred_at, e.id)
          from public.scenario_proposal_events e where e.proposal_id = sp.id), '[]'::jsonb),
        'can_forward', v_governance and sp.status = 'SUBMITTED',
        'can_respond', v_candidate and sp.status = 'OWNER_CONSULTATION',
        'can_define_owner', v_governance and sp.status = 'OWNER_CONSULTATION',
        'can_submit_content', sp.proposed_by = v_actor and sp.status in ('OWNER_DEFINED', 'CONTENT_SUBMITTED'),
        'can_approve', sp.status = 'CONTENT_SUBMITTED' and coalesce(private.safra_can_approve_proposal(sp.proposed_by), false),
        'can_reject', sp.status not in ('PUBLISHED', 'REJECTED') and coalesce(private.safra_can_approve_proposal(sp.proposed_by), false),
        'can_publish', v_admin and sp.status = 'APPROVED' and sp.proposed_by <> v_actor and sp.approved_by is distinct from v_actor
      ) order by sp.submitted_at desc)
      from public.scenario_proposals sp
      where v_all
         or sp.proposed_by = v_actor
         or (v_candidate and sp.status <> 'SUBMITTED')
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.safra_get_operational_areas()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not coalesce(public.safra_is_corporate_user(), false) then
    raise exception using errcode = '42501', message = 'SAFRA_READ_FORBIDDEN';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', oa.id, 'code', oa.code, 'name', oa.name) order by oa.name)
                   from public.operational_areas oa), '[]'::jsonb);
end;
$$;

revoke all on function public.safra_submit_proposal(text, text, text) from public, anon;
revoke all on function public.safra_forward_proposal(uuid) from public, anon;
revoke all on function public.safra_respond_proposal(uuid, boolean, text) from public, anon;
revoke all on function public.safra_define_proposal_owner(uuid, uuid, text) from public, anon;
revoke all on function public.safra_submit_proposal_content(uuid, text, text, text, text, text, uuid[]) from public, anon;
revoke all on function public.safra_approve_proposal(uuid, uuid) from public, anon;
revoke all on function public.safra_publish_proposal(uuid) from public, anon;
revoke all on function public.safra_reject_proposal(uuid, text) from public, anon;
revoke all on function public.safra_get_proposals() from public, anon;
revoke all on function public.safra_get_operational_areas() from public, anon;
grant execute on function public.safra_submit_proposal(text, text, text) to authenticated, service_role;
grant execute on function public.safra_forward_proposal(uuid) to authenticated, service_role;
grant execute on function public.safra_respond_proposal(uuid, boolean, text) to authenticated, service_role;
grant execute on function public.safra_define_proposal_owner(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.safra_submit_proposal_content(uuid, text, text, text, text, text, uuid[]) to authenticated, service_role;
grant execute on function public.safra_approve_proposal(uuid, uuid) to authenticated, service_role;
grant execute on function public.safra_publish_proposal(uuid) to authenticated, service_role;
grant execute on function public.safra_reject_proposal(uuid, text) to authenticated, service_role;
grant execute on function public.safra_get_proposals() to authenticated, service_role;
grant execute on function public.safra_get_operational_areas() to authenticated, service_role;

-- 6. GI-SAFRA-007 resolvida (só onde o login do owner existe) ------------------------------
do $$
declare
  v_owner uuid;
begin
  select u.id into v_owner from auth.users u where lower(u.email) = 'kaue.pastrello@editoradobrasil.com.br';
  if v_owner is not null then
    update public.governance_issues
       set status = 'RESOLVED', resolved_by = v_owner,
           resolution_text = 'D-60/D-68/D-125 a D-129 (02/10/2026): fluxo do 12º card construído; protocolo e conteúdo aprovados pelo Jair (proposta do Jair: Kaue), criticidade CRITICAL, sem SLA, versão 1 publicada por um admin que não propôs nem aprovou.'
     where issue_key = 'GI-SAFRA-007' and status = 'OPEN';
  end if;
end;
$$;

-- 7. Uso das telas (D-124) passa a contar a tela "Novo card" ------------------------------
alter table public.screen_views_daily drop constraint screen_views_route_check;
alter table public.screen_views_daily add constraint screen_views_route_check check (route in (
  '/', '/meus-protocolos', '/protocolos-dos-meus-cards', '/todos-os-protocolos',
  '/cards-e-donos', '/analytics', '/administracao', '/propostas'
));

create or replace function public.safra_log_screen_view(p_route text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_route text := nullif(btrim(coalesce(p_route, '')), '');
begin
  if (select auth.uid()) is null or not coalesce(public.safra_is_corporate_user(), false) then
    return;
  end if;
  if v_route is null or v_route not in (
    '/', '/meus-protocolos', '/protocolos-dos-meus-cards', '/todos-os-protocolos',
    '/cards-e-donos', '/analytics', '/administracao', '/propostas'
  ) then
    return; -- tela desconhecida: ignora, sem erro para a pessoa
  end if;

  insert into public.screen_views_daily(day, route, views)
  values ((clock_timestamp() at time zone 'America/Sao_Paulo')::date, v_route, 1)
  on conflict (day, route) do update set views = public.screen_views_daily.views + 1;
end;
$$;

revoke all on function public.safra_log_screen_view(text) from public, anon;
grant execute on function public.safra_log_screen_view(text) to authenticated, service_role;

commit;
