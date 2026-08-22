-- Verified live: notification_jobs rows were being created correctly
-- (confirmed by actually booking an appointment and checking the table),
-- but nothing ever invoked the notifications-worker Edge Function to
-- actually send them — pg_cron/pg_net weren't even enabled on this
-- project. Reminders/confirmations were silently never delivered.
--
-- The anon/publishable key is not a secret — it's the same key already
-- shipped inside the Flutter client via --dart-define — so embedding it in
-- this scheduled HTTP call is fine. It only satisfies the Edge Function
-- gateway's JWT check; the worker's own privileged writes still go through
-- SUPABASE_SERVICE_ROLE_KEY read from its Deno environment at runtime
-- (supabase/functions/notifications-worker/index.ts), never from here.
-- Run after 0001..0021.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select cron.unschedule('bookly-notifications-worker')
where exists (select 1 from cron.job where jobname = 'bookly-notifications-worker');

select cron.schedule(
  'bookly-notifications-worker',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://hvhhjzhzswuoskzlkekv.supabase.co/functions/v1/notifications-worker',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_vX-zwwz3yVMR1fmrgsMI9Q_LzTPFVYb'
    ),
    body := '{}'::jsonb
  );
  $$
);
