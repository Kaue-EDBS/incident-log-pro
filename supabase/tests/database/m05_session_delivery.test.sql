begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select ok(not has_function_privilege('anon', 'public.safra_notifications_claim_for_session(integer)', 'execute'),
  'anon cannot claim the queue');
select ok(not has_function_privilege('anon', 'public.safra_notifications_report_for_session(uuid,boolean,text)', 'execute'),
  'anon cannot report deliveries');
select ok(has_function_privilege('authenticated', 'public.safra_notifications_claim_for_session(integer)', 'execute'),
  'authenticated may call the gated claim');
select ok(not has_function_privilege('authenticated', 'public.safra_notifications_claim(integer)', 'execute'),
  'original claim stays service_role only');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000099","role":"authenticated","email":"x@gmail.com"}', true);
select throws_ok('select public.safra_notifications_claim_for_session(5)', '42501', null,
  'non-corporate user is refused');
select throws_ok($$select public.safra_notifications_report_for_session(gen_random_uuid(), true, null)$$, '42501', null,
  'non-corporate user cannot report');
reset role;

select * from finish();
rollback;
