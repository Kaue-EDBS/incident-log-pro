begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select ok(
  not has_table_privilege('authenticated','public.scenario_owners','INSERT'),
  'authenticated cannot INSERT scenario_owners directly'
);

select ok(
  not has_table_privilege('authenticated','public.scenario_owners','UPDATE'),
  'authenticated cannot UPDATE scenario_owners directly'
);

select ok(
  not has_table_privilege('authenticated','public.scenario_owners','DELETE'),
  'authenticated cannot DELETE scenario_owners directly'
);

select ok(
  not has_table_privilege('anon','public.scenario_owners','INSERT'),
  'anon cannot INSERT scenario_owners directly'
);

select ok(
  not has_table_privilege('anon','public.scenario_owners','UPDATE'),
  'anon cannot UPDATE scenario_owners directly'
);

select ok(
  not has_table_privilege('anon','public.scenario_owners','DELETE'),
  'anon cannot DELETE scenario_owners directly'
);

select is(
  (select count(*)::bigint
   from information_schema.role_table_grants
   where table_schema='private'
     and grantee in ('anon','authenticated')
     and table_name in ('safra_principals','safra_role_grants')),
  0::bigint,
  'browser roles cannot mutate RBAC sources used to qualify owners'
);

select is(
  (select count(*)::bigint
   from pg_proc p
   join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public'
     and p.prokind='f'
     and (
       lower(p.proname) like '%assign%owner%'
       or lower(p.proname) like '%reassign%owner%'
       or lower(p.proname) like '%set%owner%'
       or lower(p.proname) like '%change%owner%'
     )),
  0::bigint,
  'no public RPC can assign or reassign scenario ownership in C06.1'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'private.safra_guard_scenario_owner_history()',
    'EXECUTE'
  ),
  'authenticated cannot execute private owner-history guard directly'
);

select ok(
  not has_function_privilege(
    'anon',
    'private.safra_guard_scenario_owner_history()',
    'EXECUTE'
  ),
  'anon cannot execute private owner-history guard directly'
);

select ok(
  exists(
    select 1
    from pg_trigger t
    join pg_class c on c.oid=t.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname='scenario_owners'
      and t.tgname='trg_00_scenario_owners_history'
      and not t.tgisinternal
  ),
  'scenario_owners history guard trigger is active'
);

select throws_ok(
  $$
  do $do$
  declare
    v_link uuid;
    v_alt_owner uuid;
  begin
    select so.id
      into v_link
    from public.scenario_owners so
    join public.scenarios sc on sc.id=so.scenario_id
    where sc.code='SAFRA-01'
      and so.valid_to is null;

    select p.id
      into v_alt_owner
    from private.safra_principals p
    where p.corporate_email='jiane.rodrigues@editoradobrasil.com.br';

    update public.scenario_owners
       set owner_id=v_alt_owner
     where id=v_link;
  end
  $do$;
  $$,
  'P0001',
  'scenario_owner identity/history fields are immutable',
  'existing owner cannot be replaced by rewriting the ownership row'
);

select throws_ok(
  $$
  do $do$
  declare
    v_link uuid;
  begin
    select so.id
      into v_link
    from public.scenario_owners so
    join public.scenarios sc on sc.id=so.scenario_id
    where sc.code='SAFRA-01'
      and so.valid_to is null;

    delete from public.scenario_owners
     where id=v_link;
  end
  $do$;
  $$,
  'P0001',
  'scenario_owners history cannot be deleted',
  'ownership history cannot be physically deleted'
);

select * from finish();
rollback;
