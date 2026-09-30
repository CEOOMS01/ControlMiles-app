-- Fleet profiles (explicit user request, 2026-09-30, approved plan after
-- researching the market: Samsara/Verizon sell by capability tier and
-- present by industry; Azuga has per-industry editions; small fleets are
-- advised to add ELD/DVIR/IFTA only when regulation requires it).
-- Two layers: the PROFILE (chosen in onboarding) hides modules that don't
-- apply -- a car fleet doesn't see IFTA -- and never blocks anything
-- (Settings has "Show all modules"); the PLAN (Starter/Growth/Enterprise)
-- keeps deciding depth.
--   general        mixed / other -- everything visible (existing fleets)
--   delivery       last-mile, couriers, food delivery
--   field_service  HVAC, plumbing, electrical, pest control, landscaping
--   trucking       freight, interstate, heavy trucks (IFTA)
--   construction   pickups + heavy trucks, job sites
--   passenger      shuttles, school buses, medical transport
--   sales          sales reps, company cars
--   driving_school instructors (hourly classes)
-- The pre-trip inspection is now a fleet setting, defaulted by profile:
-- required where a DVIR is the norm (trucking, construction, passenger,
-- driving school, general = today's behavior), optional for car fleets.

alter table public.organizations drop constraint if exists organizations_industry_template_check;
alter table public.organizations add constraint organizations_industry_template_check
  check (industry_template in ('general', 'delivery', 'field_service', 'trucking', 'construction',
                               'passenger', 'sales', 'driving_school'));

alter table public.organizations
  add column show_all_modules boolean not null default false,
  add column require_pretrip_inspection boolean not null default true;

CREATE OR REPLACE FUNCTION public.fn_valid_fleet_profile(p text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $function$
  select p in ('general', 'delivery', 'field_service', 'trucking', 'construction', 'passenger', 'sales', 'driving_school');
$function$;

CREATE OR REPLACE FUNCTION public.fn_profile_requires_pretrip(p text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $function$
  select p in ('general', 'trucking', 'construction', 'passenger', 'driving_school');
$function$;

CREATE OR REPLACE FUNCTION public.create_organization(p_name text, p_industry_template text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_org_id uuid;
  v_owned_count int;
  v_entitled boolean;
  v_explicit boolean := public.fn_valid_fleet_profile(p_industry_template);
  v_template text := case when public.fn_valid_fleet_profile(p_industry_template) then p_industry_template else 'general' end;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Organization name is required';
  end if;
  perform pg_advisory_xact_lock(hashtext('create_organization:' || auth.uid()::text));
  select count(*) into v_owned_count
  from public.organization_members
  where user_id = auth.uid() and member_role = 'owner';
  select multi_org_entitled into v_entitled
  from public.profiles where id = auth.uid();
  if v_owned_count >= 1 and not coalesce(v_entitled, false) then
    raise exception 'You already own a fleet organization. Creating more than one requires the multi-fleet add-on.';
  end if;
  insert into public.organizations (name, created_by, industry_template, fleet_type_confirmed_at, require_pretrip_inspection)
  values (trim(p_name), auth.uid(), v_template,
          case when coalesce(v_explicit, false) then now() end,
          public.fn_profile_requires_pretrip(v_template))
  returning id into v_org_id;
  insert into public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
  values (v_org_id, auth.uid(), 'owner', true, now());
  update public.profiles
  set account_type = 'fleet_admin', default_org_id = v_org_id
  where id = auth.uid();
  insert into public.user_onboarding (user_id, account_type_chosen)
  values (auth.uid(), true)
  on conflict (user_id) do update set account_type_chosen = true;
  return v_org_id;
end;
$function$;

-- Choosing (or changing) the profile applies its inspection default;
-- the admin can override that toggle afterwards in Settings.
CREATE OR REPLACE FUNCTION public.set_fleet_type(p_organization_id uuid, p_industry_template text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if not public.is_org_admin_or_owner(p_organization_id) then
    raise exception 'Not authorized';
  end if;
  if not coalesce(public.fn_valid_fleet_profile(p_industry_template), false) then
    raise exception 'Unknown fleet type: %', p_industry_template;
  end if;
  update public.organizations
  set industry_template = p_industry_template,
      require_pretrip_inspection = public.fn_profile_requires_pretrip(p_industry_template),
      fleet_type_confirmed_at = coalesce(fleet_type_confirmed_at, now())
  where id = p_organization_id;
end;
$function$;
