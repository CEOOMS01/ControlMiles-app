-- Compatibility (2026-10-20): the web still deployed calls ds_portal_book with
-- an instructor. The instructor is ignored; the booking goes through the new
-- random, language-aware version. Drop once the new web is live.
create or replace function public.ds_portal_book(p_token text, p_instructor uuid, p_date date, p_start time without time zone)
returns uuid language sql security definer set search_path to 'public' as $$
  select public.ds_portal_book(p_token, p_date, p_start);
$$;
revoke execute on function public.ds_portal_book(text, uuid, date, time without time zone) from public;
grant execute on function public.ds_portal_book(text, uuid, date, time without time zone) to anon, authenticated;
