begin;
create extension if not exists pgtap with schema extensions;
select plan(32);

-- P = proposer (regular), X = another regular person, J = Jair, K = Kaue, M = Amanda (admin),
-- D/R/I = Daniel, Renato, Jiane (card owners consulted).
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
values
  ('a0100000-0000-4000-8000-00000000000a','m10.proposer@editoradobrasil.com.br','{"provider":"azure"}','{"full_name":"Paula Proposta"}',true,false,clock_timestamp(),clock_timestamp()),
  ('a0100000-0000-4000-8000-00000000000b','m10.other@editoradobrasil.com.br','{"provider":"azure"}','{}',true,false,clock_timestamp(),clock_timestamp());
insert into auth.users(id,email,raw_app_meta_data,is_sso_user,is_anonymous,created_at,updated_at)
select v.id::uuid, p.corporate_email, '{"provider":"azure"}', true, false, clock_timestamp(), clock_timestamp()
from (values
  ('a0100000-0000-4000-8000-00000000000c', 'Jair Silva'),
  ('a0100000-0000-4000-8000-00000000000d', 'Kaue Pastrello'),
  ('a0100000-0000-4000-8000-00000000000e', 'Amanda Bueno'),
  ('a0100000-0000-4000-8000-0000000000d1', 'Daniel Garcia'),
  ('a0100000-0000-4000-8000-0000000000d2', 'Renato de Paulo'),
  ('a0100000-0000-4000-8000-0000000000d3', 'Jiane Rodrigues')
) as v(id, who)
join private.safra_principals p on p.display_name = v.who;

insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
select u.id::text, u.id, '{"custom_claims":{"tid":"45ba725f-d260-45c3-ac85-11f433471277"}}', 'azure', clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0100000-%';

insert into auth.sessions(id,user_id,created_at,updated_at)
select ('a0100000-0000-4000-8000-0000000001' || right(u.id::text, 2))::uuid, u.id, clock_timestamp(), clock_timestamp()
from auth.users u where u.id::text like 'a0100000-%';

create function pg_temp.act_as(p_who text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', u.id, 'email', u.email,
    'session_id', 'a0100000-0000-4000-8000-0000000001' || right(u.id::text, 2),
    'is_anonymous', false, 'app_metadata', json_build_object('provider','azure'),
    'exp', extract(epoch from now() + interval '1 hour')::bigint)::text, true)::text
  from auth.users u
  where u.id = ('a0100000-0000-4000-8000-0000000000' || p_who)::uuid;
$$;

create temp table ctx(k text primary key, v text);
create function pg_temp.t(p_k text) returns uuid language sql as $$ select v::uuid from ctx where k = p_k $$;
create function pg_temp.principal(p_who text) returns uuid language sql as $$
  select id from private.safra_principals where display_name = p_who
$$;
create function pg_temp.status(p_k text) returns text language sql as $$
  select status from public.scenario_proposals where id = pg_temp.t(p_k)
$$;
create function pg_temp.area(p_n integer) returns uuid language sql as $$
  select id from public.operational_areas order by code offset p_n limit 1
$$;
create function pg_temp.notices(p_k text, p_type text) returns integer language sql as $$
  select count(*)::int from public.notifications_log where proposal_id = pg_temp.t(p_k) and notification_type = p_type
$$;

-- 1. Proposal with name and e-mail from the session (D-125) ----------------------------
select pg_temp.act_as('0a');
insert into ctx values ('p1', public.safra_submit_proposal('Atraso na separação de pedidos de escola',
  'Pedidos de escola ficam parados na separação por falta de etiqueta.', 'Atrasa a entrega para as escolas no pico da Safra.')::text);
select ok((select proposer_name = 'Paula Proposta' and proposer_email = 'm10.proposer@editoradobrasil.com.br'
           from public.scenario_proposals where id = pg_temp.t('p1')),
  'D-125: name and e-mail come from the Microsoft session');
select is(pg_temp.status('p1'), 'SUBMITTED', 'the proposal starts SUBMITTED');
select is(pg_temp.notices('p1', 'PROPOSAL_SUBMITTED'), 1, 'D-129: Jair is told about the new proposal');
select throws_ok($$ select public.safra_submit_proposal('ab', 'curto', 'curto') $$, '22023', 'SAFRA_PROPOSAL_TITLE_REQUIRED',
  'the form needs a title');

select pg_temp.act_as('0b');
select is(jsonb_array_length(public.safra_get_proposals()->'items'), 0, 'another person does not see the proposal');
select throws_ok($$ select public.safra_forward_proposal(pg_temp.t('p1')) $$, '42501', 'SAFRA_PROPOSAL_FORBIDDEN',
  'only governance forwards');

-- 2. Jair forwards to the card owners; exactly one accepts (D-126) --------------------------
select pg_temp.act_as('0c');
select public.safra_forward_proposal(pg_temp.t('p1'));
select is(pg_temp.status('p1'), 'OWNER_CONSULTATION', 'D-126: forwarded to the card owners');
select is(pg_temp.notices('p1', 'PROPOSAL_OWNER_REQUEST'), 3, 'D-129: Daniel, Renato and Jiane are asked');

select pg_temp.act_as('d1');
select ok((select (x->>'can_respond')::boolean from jsonb_array_elements(public.safra_get_proposals()->'items') x
           where x->>'proposal_id' = pg_temp.t('p1')::text), 'a consulted owner sees the proposal and can answer');
select public.safra_respond_proposal(pg_temp.t('p1'), true, 'Assumo, é da minha área.');
select pg_temp.act_as('d2');
select public.safra_respond_proposal(pg_temp.t('p1'), false, null);
select is(pg_temp.status('p1'), 'OWNER_CONSULTATION', 'D-126: the owner is only defined when everyone answered');
select pg_temp.act_as('d3');
select public.safra_respond_proposal(pg_temp.t('p1'), false, null);
select ok((select status = 'OWNER_DEFINED' and owner_decision = 'SINGLE_ACCEPT' and owner_principal_id = pg_temp.principal('Daniel Garcia')
           from public.scenario_proposals where id = pg_temp.t('p1')),
  'D-126: exactly one accept -> that person is the owner');
select is(pg_temp.notices('p1', 'PROPOSAL_OWNER_DEFINED'), 2, 'D-129: proposer and new owner are told');

-- 3. The proposer writes the content (D-127) ------------------------------------------------
select pg_temp.act_as('0c');
select throws_ok($$ select public.safra_submit_proposal_content(pg_temp.t('p1'), 'Nome', 'gatilho x', 'deteccao', 'protocolo', 'impacto', '{}') $$,
  '42501', 'SAFRA_PROPOSAL_FORBIDDEN', 'D-60: only the proposer writes the content');
select pg_temp.act_as('0a');
select throws_ok($$ select public.safra_submit_proposal_content(pg_temp.t('p1'), 'Separação parada por etiqueta',
    'Pedido de escola sem etiqueta impressa', 'Fila de separação acima de 50 pedidos', 'Acionar a expedição e liberar impressora reserva',
    'Entregas de escola atrasam', '{}') $$,
  '22023', 'SAFRA_PROPOSAL_AREAS_REQUIRED', 'D-127: impacted areas are required');
select public.safra_submit_proposal_content(pg_temp.t('p1'), 'Separação parada por etiqueta',
  'Pedido de escola sem etiqueta impressa', 'Fila de separação acima de 50 pedidos', 'Acionar a expedição e liberar impressora reserva',
  'Entregas de escola atrasam', array[pg_temp.area(0), pg_temp.area(1)]);
select is(pg_temp.status('p1'), 'CONTENT_SUBMITTED', 'D-127: content complete');

-- 4. Approval (Jair, with the responsible area) and separation of duties (D-60/D-68) ---------
select throws_ok($$ select public.safra_approve_proposal(pg_temp.t('p1'), pg_temp.area(0)) $$,
  '42501', 'SAFRA_PROPOSAL_FORBIDDEN', 'D-68: the proposer cannot approve');
select pg_temp.act_as('0c');
select public.safra_approve_proposal(pg_temp.t('p1'), pg_temp.area(0));
select is(pg_temp.status('p1'), 'APPROVED', 'D-60: Jair approves');
select throws_ok($$ select public.safra_publish_proposal(pg_temp.t('p1')) $$,
  '42501', 'SAFRA_PROPOSAL_FORBIDDEN', 'D-60: Jair does not publish (platform admins publish)');

-- 5. Publication as SAFRA-12, CRITICAL, version 1 (D-128) -----------------------------------
select pg_temp.act_as('0e');
insert into ctx select 'pub', public.safra_publish_proposal(pg_temp.t('p1'))->>'scenario_id';
select is((select code from public.scenarios where id = pg_temp.t('pub')), 'SAFRA-12', 'D-128: the new card is SAFRA-12');
select ok((select sv.status = 'PUBLISHED' and sv.version_no = 1 and sv.criticality = 'CRITICAL'
                  and sv.protocol_text = 'Acionar a expedição e liberar impressora reserva'
           from public.scenarios sc join public.scenario_versions sv on sv.id = sc.current_version_id
           where sc.id = pg_temp.t('pub')),
  'D-60/D-128: version 1, PUBLISHED, CRITICAL, with the proposer''s content');
select is((select count(*)::int from public.scenario_version_impacted_areas svia
           join public.scenarios sc on sc.current_version_id = svia.scenario_version_id where sc.id = pg_temp.t('pub')), 2,
  'the impacted areas go with the version');
select is((select owner_id from public.scenario_owners where scenario_id = pg_temp.t('pub') and valid_to is null),
  pg_temp.principal('Daniel Garcia'), 'D-126: the chosen owner owns the new card');
select throws_ok(
  $$ update public.scenario_versions set protocol_text = 'reescrito' where id = (select current_version_id from public.scenarios where id = pg_temp.t('pub')) $$,
  'P0001', 'PUBLISHED scenario_version content is immutable', 'D-128: a published version is never rewritten');
select is(pg_temp.notices('p1', 'PROPOSAL_PUBLISHED'), 3, 'D-129: proposer, owner and Jair are told');

-- The new card can receive protocols.
select pg_temp.act_as('0b');
select ok((select count(*) = 1 from jsonb_array_elements(public.safra_get_start_catalog()) c where c->>'code' = 'SAFRA-12'),
  'the new card appears in the catalog');
select lives_ok($$ select public.safra_start_treatment(pg_temp.t('pub'), 'a0100000-0000-4000-8000-000000000999'::uuid,
    'Separação parada: fila de 80 pedidos', '{}'::uuid[]) $$, 'a protocol can be opened on the new card');

-- 6. Two accepts: the owners meet outside the Painel and Jair records it (D-126) ----------
select pg_temp.act_as('0a');
insert into ctx values ('p2', public.safra_submit_proposal('Falha no envio de notas fiscais', 'Notas fiscais não chegam ao cliente por e-mail.', 'Cliente não recebe a nota e trava o pagamento.')::text);
select pg_temp.act_as('0c');
select public.safra_forward_proposal(pg_temp.t('p2'));
select pg_temp.act_as('d1'); select public.safra_respond_proposal(pg_temp.t('p2'), true, null);
select pg_temp.act_as('d2'); select public.safra_respond_proposal(pg_temp.t('p2'), true, null);
select pg_temp.act_as('d3'); select public.safra_respond_proposal(pg_temp.t('p2'), false, null);
select is(pg_temp.status('p2'), 'OWNER_CONSULTATION', 'D-126: two accepts do not define the owner by themselves');
select pg_temp.act_as('0c');
select throws_ok($$ select public.safra_define_proposal_owner(pg_temp.t('p2'), pg_temp.principal('Renato de Paulo'), '') $$,
  '22023', 'SAFRA_PROPOSAL_NOTE_REQUIRED', 'D-126: Jair records how the meeting decided');
select public.safra_define_proposal_owner(pg_temp.t('p2'), pg_temp.principal('Renato de Paulo'), 'Decidido em reunião dos donos em 02/10.');
select ok((select owner_decision = 'GOVERNANCE_DECISION' and owner_principal_id = pg_temp.principal('Renato de Paulo')
           from public.scenario_proposals where id = pg_temp.t('p2')), 'D-126: the owner chosen in the meeting is recorded');

-- 7. Jair's own proposal is approved by Kaue (D-68) -------------------------------------------
select pg_temp.act_as('0c');
insert into ctx values ('p3', public.safra_submit_proposal('Proposta do Jair', 'Problema descrito pelo Jair para teste.', 'Impacto descrito pelo Jair para teste.')::text);
update public.scenario_proposals
   set status = 'CONTENT_SUBMITTED', owner_principal_id = pg_temp.principal('Daniel Garcia'), scenario_name = 'Card do Jair',
       trigger_description = 'gatilho do Jair', detection_description = 'detecção do Jair', protocol_text = 'protocolo do Jair',
       expected_impact_summary = 'impacto do Jair', impacted_area_ids = array[pg_temp.area(0)]
 where id = pg_temp.t('p3');
select ok(not coalesce(private.safra_can_approve_proposal('a0100000-0000-4000-8000-00000000000c'), false),
  'D-68: Jair cannot approve his own proposal');
select pg_temp.act_as('0d');
select lives_ok($$ select public.safra_approve_proposal(pg_temp.t('p3'), pg_temp.area(0)) $$, 'D-68: Kaue approves Jair''s proposal');
select throws_ok($$ select public.safra_publish_proposal(pg_temp.t('p3')) $$,
  '42501', 'SAFRA_PROPOSAL_SEPARATION_OF_DUTIES', 'D-68: who approved does not publish');

select * from finish();
rollback;
