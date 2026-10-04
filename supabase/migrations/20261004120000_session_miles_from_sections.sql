-- Trip miles = the sum of its gig-app segments (2026-10-04).
--
-- The PDF report showed Business-use 102.8%: its total used
-- sessions.total_miles while the business-use summary added up
-- session_sections.total_miles, and 6 closed trips disagreed:
--  * multi-app trips stored only their LAST segment's miles (the app's
--    background checkpoint saved section miles as trip miles -- fixed in
--    app 1.1.16, AppLifecycleObserver -> TrackingController.saveCheckpoint);
--  * trips from before 2026-09-16 stored 0 for the trip while their segment
--    had the miles.
-- The segments are what the app measured. From now on the database sets a
-- trip's miles to the sum of its segments when the trip closes, whatever
-- app version closed it, and the 6 stored trips are repaired once.

create or replace function public.fn_session_miles_from_sections()
returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_sum double precision;
begin
  if coalesce(new.is_closed, false) and not coalesce(old.is_closed, false) then
    select sum(total_miles) into v_sum from public.session_sections where session_id = new.id;
    if v_sum is not null and v_sum > 0 then
      new.total_miles := v_sum;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_session_miles_from_sections on public.sessions;
create trigger trg_session_miles_from_sections
  before update on public.sessions
  for each row execute function public.fn_session_miles_from_sections();

-- One-time repair of closed trips that disagree with their segments. Closed
-- trips are frozen (trg_freeze_closed_session), so the freeze is lifted for
-- this statement only, inside this migration's transaction.
alter table public.sessions disable trigger trg_freeze_closed_session;

update public.sessions s
   set total_miles = x.sum_miles
  from (
    select session_id, sum(total_miles) as sum_miles
      from public.session_sections
     group by session_id
  ) x
 where x.session_id = s.id
   and s.is_closed
   and x.sum_miles > 0
   and abs(x.sum_miles - coalesce(s.total_miles, 0)) > 0.05;

alter table public.sessions enable trigger trg_freeze_closed_session;
