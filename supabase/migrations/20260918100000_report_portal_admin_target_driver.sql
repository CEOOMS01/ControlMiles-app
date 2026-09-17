-- Real fix, not a pricing-copy edit (explicit user request, 2026-09-18):
-- the public pricing page has promised "Report Portal for any driver" on
-- the Starter tier since it shipped, but generate_report_access_code has
-- always hardcoded v_user_id := auth.uid() -- there was never a way for an
-- org admin to generate a report for anyone but themselves. Audited before
-- touching anything: confirmed via the function's live source in this
-- project (20260909180000_report_portal_checkpoints_and_deduction.sql)
-- that no p_target_user_id parameter has ever existed.
--
-- New optional p_target_user_id: null (or equal to the caller) preserves
-- the existing self-service behavior byte-for-byte. A different value
-- requires the caller to be an active owner/admin of an organization the
-- target driver also actively belongs to -- checked directly against
-- organization_members, the same table every other org-admin gate in this
-- schema (is_org_admin_or_owner, assign_vehicle_to_driver, etc.) is built
-- on, rather than trusting a client-supplied org id.
--
-- reports.user_id now correctly means "whose trip data this covers" and
-- reports.generated_by means "who triggered the generation" -- both
-- columns already existed, they were just never allowed to differ before.
-- Rate limit moves from reports.user_id to generated_by: an admin
-- generating codes for five different drivers shouldn't get blocked by
-- one busy driver's own self-service usage, but the admin's own total
-- output still has a real ceiling.
--
-- SECOND real bug caught live, only by testing end-to-end (not by reading
-- the SQL back): reports.organization_id was never set by this function,
-- for ANY call, ever. Harmless for pure self-service gig drivers (no org
-- to begin with), but for a cross-driver admin-generated report it meant
-- the inserted row was invisible to EVERYONE afterward under
-- reports_select_own's RLS (user_id = auth.uid() OR (organization_id IS
-- NOT NULL AND is_org_member(organization_id))) -- not the admin who
-- generated it, not any other org member. The insert itself always
-- succeeded (SECURITY DEFINER, owned by postgres which has BYPASSRLS) so
-- this produced no error at all, just a real row nobody could ever query
-- back. Now sets organization_id from the same org membership row the
-- authorization check already found, so an org-generated report is
-- visible to the org going forward, matching the RLS policy's own intent.
create or replace function public.generate_report_access_code(
  p_start_date date,
  p_end_date date,
  p_vehicle_id uuid default null,
  p_weekly_checkpoints jsonb default '[]'::jsonb,
  p_target_user_id uuid default null
)
returns table(code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_caller uuid := auth.uid();
  v_user_id uuid;
  v_organization_id uuid;
  v_recent_count int;
  v_plain_code text;
  v_alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- no 0/O/1/I
  v_expires timestamptz := now() + interval '15 minutes';
  v_metadata jsonb;
  v_deduction numeric;
  i int;
begin
  if v_caller is null then
    raise exception 'Authentication required';
  end if;

  if p_target_user_id is null or p_target_user_id = v_caller then
    v_user_id := v_caller;
  else
    select caller_m.organization_id into v_organization_id
    from public.organization_members caller_m
    join public.organization_members target_m
      on target_m.organization_id = caller_m.organization_id
    where caller_m.user_id = v_caller
      and caller_m.member_role in ('owner', 'admin')
      and caller_m.is_active = true
      and target_m.user_id = p_target_user_id
      and target_m.is_active = true
    limit 1;

    if v_organization_id is null then
      raise exception 'Not authorized to generate a report for that driver';
    end if;
    v_user_id := p_target_user_id;
  end if;

  if p_end_date < p_start_date then
    raise exception 'Invalid date range';
  end if;

  select count(*) into v_recent_count
  from public.reports
  where generated_by = v_caller
    and generated_at > now() - interval '1 hour';

  if v_recent_count >= 5 then
    raise exception 'Too many report codes generated recently. Try again later.';
  end if;

  select coalesce(sum(
    case when s.date_key < date '2026-07-01'
      then s.total_miles * 72.5 / 100.0
      else s.total_miles * 76.0 / 100.0
    end
  ), 0) into v_deduction
  from public.sessions s
  where s.user_id = v_user_id
    and s.date_key between p_start_date and p_end_date
    and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id);

  with vehicles_in_range as (
    select distinct v.id, v.nickname, v.make, v.model, v.year, v.plate
    from public.sessions s
    join public.vehicles v on v.id = s.vehicle_id
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
  ),
  purpose_breakdown as (
    select
      ss.gig_app,
      ss.irs_purpose,
      sum(ss.total_miles) as miles
    from public.session_sections ss
    join public.sessions s on s.id = ss.session_id
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
    group by ss.gig_app, ss.irs_purpose
  ),
  totals as (
    select
      coalesce(sum(s.total_miles), 0) as total_miles,
      count(distinct s.id) as total_sessions
    from public.sessions s
    where s.user_id = v_user_id
      and s.date_key between p_start_date and p_end_date
      and (p_vehicle_id is null or s.vehicle_id = p_vehicle_id)
  )
  select jsonb_build_object(
    'driver_display_name', p.full_name,
    'driver_display_id', p.display_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'generated_at', now(),
    'total_miles', t.total_miles,
    'total_sessions', t.total_sessions,
    'total_deduction_estimate', v_deduction,
    'vehicles', coalesce((select jsonb_agg(jsonb_build_object(
        'nickname', vr.nickname, 'make', vr.make, 'model', vr.model,
        'year', vr.year, 'plate', vr.plate
      )) from vehicles_in_range vr), '[]'::jsonb),
    'gig_app_breakdown', coalesce((select jsonb_agg(jsonb_build_object(
        'gig_app', pb.gig_app, 'irs_purpose', pb.irs_purpose, 'miles', pb.miles
      )) from purpose_breakdown pb), '[]'::jsonb),
    'weekly_checkpoints', coalesce(p_weekly_checkpoints, '[]'::jsonb)
  )
  into v_metadata
  from public.profiles p, totals t
  where p.id = v_user_id;

  v_plain_code := '';
  for i in 1..8 loop
    v_plain_code := v_plain_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
  end loop;

  insert into public.reports (
    report_type, user_id, organization_id, vehicle_id, start_date, end_date,
    total_miles, total_sessions, generated_by, metadata,
    qr_token, qr_expires_at, qr_uses, qr_max_uses
  ) values (
    'custom', v_user_id, v_organization_id, p_vehicle_id, p_start_date, p_end_date,
    coalesce((v_metadata->>'total_miles')::float8, 0),
    coalesce((v_metadata->>'total_sessions')::int, 0),
    v_caller, v_metadata,
    encode(digest(v_plain_code, 'sha256'), 'hex'), v_expires, 0, 2
  );

  return query select v_plain_code, v_expires;
end;
$$;

drop function if exists public.generate_report_access_code(date, date, uuid, jsonb);

revoke all on function public.generate_report_access_code(date, date, uuid, jsonb, uuid) from public;
revoke execute on function public.generate_report_access_code(date, date, uuid, jsonb, uuid) from anon;
grant execute on function public.generate_report_access_code(date, date, uuid, jsonb, uuid) to authenticated;
