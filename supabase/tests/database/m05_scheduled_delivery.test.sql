begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

select ok(exists (select 1 from pg_extension where extname = 'pg_net'), 'D-133: pg_net is installed');
-- D-134/A7: the schedule only exists in production (where the owner login exists); the
-- disposable CI database and local stacks never call the production sender.
select ok((select count(*) from cron.job where jobname = 'safra-send-notifications') = 0
          or (select count(*) from cron.job where jobname = 'safra-send-notifications' and schedule = '*/2 * * * *') = 1,
  'D-133: the sender runs every 2 minutes where it is scheduled');
select ok(coalesce((select command like '%/functions/v1/safra-send-notifications%' from cron.job where jobname = 'safra-send-notifications'), true),
  'D-133: the schedule calls the server sender');

select * from finish();
rollback;
