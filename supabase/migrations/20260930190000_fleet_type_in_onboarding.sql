-- Fleet type is chosen in onboarding, not at sign-up (explicit user
-- request, 2026-09-30: "no habrá sign up exclusivo, solo debe haber un
-- sign up y en el onboarding allí la empresa elige el tipo de fleet que
-- es, no antes"). The web sign-up no longer carries a fleet type: the
-- organization is created with 'general' and fleet_type_confirmed_at
-- NULL, and the admin panel sends the owner to /onboarding/fleet-type
-- until they pick one. Existing organizations are treated as confirmed.
-- The mobile app's create-organization screen still asks the type in its
-- own flow, and passing it explicitly confirms it.

alter table public.organizations add column fleet_type_confirmed_at timestamptz;
update public.organizations set fleet_type_confirmed_at = coalesce(created_at, now());

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
  v_template text := case when p_industry_template in ('general', 'driving_school')
                          then p_industry_template else 'general' end;
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

  insert into public.organizations (name, created_by, industry_template, fleet_type_confirmed_at)
  values (trim(p_name), auth.uid(), v_template,
          case when p_industry_template in ('general', 'driving_school') then now() end)
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

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_org_name TEXT;
  v_org_id uuid;
BEGIN
  v_first_name := COALESCE(
    NEW.raw_user_meta_data->>'first_name',
    SPLIT_PART(COALESCE(NEW.email, ''), '@', 1)
  );
  v_last_name := NULLIF(COALESCE(NEW.raw_user_meta_data->>'last_name', ''), '');
  v_org_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'pending_org_name', '')), '');

  INSERT INTO public.profiles (id, email, first_name, last_name, account_type)
  VALUES (NEW.id, NEW.email, v_first_name, v_last_name, 'gig')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_onboarding (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  IF v_org_name IS NOT NULL THEN
    -- Fleet type left unconfirmed: chosen in onboarding (see header).
    INSERT INTO public.organizations (name, created_by, industry_template)
    VALUES (v_org_name, NEW.id, 'general')
    RETURNING id INTO v_org_id;

    INSERT INTO public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
    VALUES (v_org_id, NEW.id, 'owner', true, now());

    UPDATE public.profiles
    SET account_type = 'fleet_admin', default_org_id = v_org_id
    WHERE id = NEW.id;

    UPDATE public.user_onboarding
    SET account_type_chosen = true
    WHERE user_id = NEW.id;
  END IF;

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  RAISE LOG '[ControlMiles] handle_new_user FAILED for uid=% email=% | error: %', NEW.id, NEW.email, SQLERRM;

  BEGIN
    INSERT INTO public.auth_signup_errors (user_id, email, error_message)
    VALUES (NEW.id, NEW.email, SQLERRM);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$function$;

-- The onboarding step (and Settings) set the type through this.
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
  if p_industry_template not in ('general', 'driving_school') then
    raise exception 'Unknown fleet type: %', p_industry_template;
  end if;
  update public.organizations
  set industry_template = p_industry_template,
      fleet_type_confirmed_at = coalesce(fleet_type_confirmed_at, now())
  where id = p_organization_id;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.set_fleet_type(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_fleet_type(uuid, text) TO authenticated;
