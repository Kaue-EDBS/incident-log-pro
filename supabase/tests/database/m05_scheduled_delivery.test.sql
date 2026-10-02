begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

select ok(exists (select 1 from pg_extension where extname = 'pg_net'), 'D-133: pg_net is installed');
select is((select count(*)::int from cron.job where jobname = 'safra-send-notifications' and schedule = '*/2 * * * *'), 1,
  'D-133: the sender runs every 2 minutes');
select ok((select command like '%/functions/v1/safra-send-notifications%' from cron.job where jobname = 'safra-send-notifications'),
  'D-133: the schedule calls the server sender');

select * from finish();
rollback;
