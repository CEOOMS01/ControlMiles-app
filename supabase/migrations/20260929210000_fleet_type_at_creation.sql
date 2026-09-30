-- Fleet type asked when the fleet is created (user request 2026-09-29,
-- following the industry-template research: ask the business type up
-- front, like HubSpot/Jobber, instead of hiding it in Settings).
-- Every path that creates a fleet passes it: the web email sign-up (via
-- raw_user_meta_data.pending_industry_template, read by handle_new_user),
-- and create_organization (web Google onboarding / dashboard, the app).
-- Anything missing or unknown falls back to 'general'.

drop function if exists public.create_organization(text);

create or replace function public.create_organization(p_name text, p_industry_template text default 'general')
returns uuid language plpgsql security definer set search_path = public as $$
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

  insert into public.organizations (name, created_by, industry_template)
  values (trim(p_name), auth.uid(), v_template)
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
$$;

revoke execute on function public.create_organization(text, text) from public, anon;
grant execute on function public.create_organization(text, text) to authenticated, service_role;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
DECLARE
  v_first_name TEXT;
  v_last_name TEXT;
  v_org_name TEXT;
  v_template TEXT;
  v_org_id uuid;
BEGIN
  v_first_name := COALESCE(
    NEW.raw_user_meta_data->>'first_name',
    SPLIT_PART(COALESCE(NEW.email, ''), '@', 1)
  );
  v_last_name := NULLIF(COALESCE(NEW.raw_user_meta_data->>'last_name', ''), '');
  v_org_name := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'pending_org_name', '')), '');
  v_template := CASE WHEN NEW.raw_user_meta_data->>'pending_industry_template' IN ('general', 'driving_school')
                     THEN NEW.raw_user_meta_data->>'pending_industry_template' ELSE 'general' END;

  INSERT INTO public.profiles (id, email, first_name, last_name, account_type)
  VALUES (NEW.id, NEW.email, v_first_name, v_last_name, 'gig')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_onboarding (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  IF v_org_name IS NOT NULL THEN
    INSERT INTO public.organizations (name, created_by, industry_template)
    VALUES (v_org_name, NEW.id, v_template)
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
$$;
