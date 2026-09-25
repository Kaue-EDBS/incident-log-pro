begin;

create extension if not exists pgtap with schema extensions;

select plan(7);

-- Migration replay evidence: the latest C05 guard migration must be in local history.
select is(
  (
    select count(*)::bigint
    from supabase_migrations.schema_migrations
    where version = '20260925210500'
  ),
  1::bigint,
  'latest C05 migration is recorded after replay'
);

-- Constraint behavior: criticality cannot accept invented values.
select ok(
  (
    select pg_get_constraintdef(oid) ilike '%CRITICAL%'
       and pg_get_constraintdef(oid) ilike '%HIGH%'
       and pg_get_constraintdef(oid) ilike '%MODERATE%'
    from pg_constraint
    where conrelid = 'public.scenario_versions'::regclass
      and conname = 'scenario_versions_criticality_check'
  ),
  'criticality constraint keeps only the approved vocabulary'
);

-- Constraint behavior: CANCEL reason remains mandatory at the persistence layer.
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.treatments'::regclass
      and conname = 'treatments_cancel_reason_required'
  ),
  'CANCEL reason constraint exists'
);

-- Double-submit/idempotency: same logical notification cannot be persisted twice.
create or replace function pg_temp.double_submit_is_blocked()
returns boolean
language plpgsql
as $$
declare
  v_key text := 'ci-double-submit-' || gen_random_uuid()::text;
  v_corr uuid := gen_random_uuid();
begin
  insert into public.notifications_log(
    notification_type,
    recipient_email,
    delivery_status,
    idempotency_key,
    correlation_id
  )
  values (
    'CI_DOUBLE_SUBMIT',
    'ci@example.invalid',
    'QUEUED',
    v_key,
    v_corr
  );

  begin
    insert into public.notifications_log(
      notification_type,
      recipient_email,
      delivery_status,
      idempotency_key,
      correlation_id
    )
    values (
      'CI_DOUBLE_SUBMIT',
      'ci@example.invalid',
      'QUEUED',
      v_key,
      v_corr
    );
  exception
    when unique_violation then
      return true;
  end;

  return false;
end;
$$;

select ok(
  pg_temp.double_submit_is_blocked(),
  'double submit is rejected by idempotency key'
);

-- RLS must still deny rows even if a table grant is temporarily added.
insert into public.scenarios(code, name, lifecycle_status)
values ('CI-RLS-VISIBILITY', 'CI RLS visibility fixture', 'ACTIVE');

grant select on public.scenarios to anon, authenticated;

set local role anon;
select is(
  (select count(*)::bigint from public.scenarios where code = 'CI-RLS-VISIBILITY'),
  0::bigint,
  'RLS hides SAFRA rows from anon even when SELECT is temporarily granted'
);
reset role;

set local role authenticated;
select is(
  (select count(*)::bigint from public.scenarios where code = 'CI-RLS-VISIBILITY'),
  0::bigint,
  'RLS hides SAFRA rows from authenticated when no governed policy exists'
);
reset role;

-- Direct grants must remain absent outside this test transaction.
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.scenarios'::regclass
  ),
  'RLS remains enabled on scenarios'
);

select * from finish();
rollback;
