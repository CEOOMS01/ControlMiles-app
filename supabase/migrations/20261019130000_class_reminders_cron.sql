-- Driving school class reminders (2026-10-19): send-class-reminders every
-- hour at :05, same pattern and shared secret (Vault 'ifta_sync_shared_secret')
-- as the nightly fuel alerts. The function only emails what's due inside
-- each school's reminder window and only once per recipient.
select cron.unschedule('class-reminders-hourly')
 where exists (select 1 from cron.job where jobname = 'class-reminders-hourly');
select cron.schedule(
  'class-reminders-hourly',
  '5 * * * *',
  $cron$
  select net.http_post(
    url := 'https://zuujwmcftycmdaxesdya.supabase.co/functions/v1/send-class-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Sync-Secret', (select decrypted_secret from vault.decrypted_secrets where name = 'ifta_sync_shared_secret')
    ),
    body := '{}'::jsonb
  );
  $cron$
);
