begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

-- Mapa fixo de quem chama o quê (D-141): qualquer grant esquecido, retirado ou novo quebra o CI.
select is(
  (select string_agg(p.proname, ',' order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'safra\_%' and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  'safra_admin_get_notifications_queue,safra_admin_get_ops_summary,safra_admin_get_owner_treatments,safra_admin_get_people,safra_admin_get_screen_usage,safra_approve_proposal,safra_can_use_chameleon,safra_cancel_treatment,safra_close_my_part,safra_define_proposal_owner,safra_end_season,safra_forward_proposal,safra_get_all_treatments,safra_get_cards_overview,safra_get_my_treatments,safra_get_operational_areas,safra_get_owner_treatments,safra_get_proposals,safra_get_reliability_metrics,safra_get_season,safra_get_start_catalog,safra_get_treatment_timeline,safra_get_weekly_governance,safra_has_role,safra_is_corporate_user,safra_log_ops_event,safra_log_screen_view,safra_notifications_claim_for_session,safra_notifications_report_for_session,safra_publish_proposal,safra_register_governance_action,safra_reject_proposal,safra_respond_proposal,safra_session_is_live,safra_start_season,safra_start_treatment,safra_submit_proposal,safra_submit_proposal_content,safra_undo_end_season,safra_undo_my_part',
  'D-141: the exact set of Painel functions a logged-in person can call');

select is(
  (select string_agg(p.proname, ',' order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'safra\_%' and has_function_privilege('anon', p.oid, 'EXECUTE')),
  null,
  'D-141: anon calls no Painel function');

select is(
  (select string_agg(p.proname, ',' order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'safra\_%'
     and has_function_privilege('service_role', p.oid, 'EXECUTE')
     and not has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  'safra_notifications_claim,safra_notifications_report,safra_sender_token_valid',
  'D-141: only the server sender functions are service_role-only');

select is(
  (select string_agg(n.nspname || '.' || p.proname, ',' order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'private') and p.prosecdef
     and not (coalesce(p.proconfig, '{}') @> array['search_path=""'])),
  null,
  'D-141: every SECURITY DEFINER function pins an empty search_path');

select is(
  (select string_agg(n.nspname || '.' || p.proname, ',' order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private' and has_function_privilege('anon', p.oid, 'EXECUTE')),
  null,
  'D-141: anon calls no private helper');

select * from finish();
rollback;
