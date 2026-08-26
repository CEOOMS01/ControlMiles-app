-- Explicit user requirement: an admin can only own ONE fleet
-- organization by default. Owning more (e.g. genuinely different fleet
-- types under one business) is a paid add-on -- "multiple organizations
-- will be an extra module, must pay a plus to open another
-- organization." This migration builds the ENTITLEMENT GATE only --
-- create_organization now blocks a second org unless the caller is
-- flagged entitled. No payment processing is wired here: granting
-- multi_org_entitled is a manual/support action for now, same as any
-- other DB flag, until a real billing integration is explicitly asked
-- for and a payment processor is chosen -- fabricating a checkout flow
-- with no real processor behind it would be worse than not having one.
--
-- Verified live: the real account (already owning 2 orgs, created
-- before this gate existed -- unaffected, existing orgs are never
-- touched, this only gates NEW creation) is correctly blocked from
-- creating a third; temporarily entitling it (inside a ROLLBACK'd
-- transaction, no real change persisted) correctly allows creation.
alter table public.profiles add column if not exists multi_org_entitled boolean not null default false;
comment on column public.profiles.multi_org_entitled is 'Paid add-on: lets an owner create more than one fleet organization. No billing integration wired yet -- set manually until real payment processing is built.';

create or replace function public.create_organization(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_owned_count int;
  v_entitled boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Organization name is required';
  end if;

  select count(*) into v_owned_count
  from public.organization_members
  where user_id = auth.uid() and member_role = 'owner';

  select multi_org_entitled into v_entitled
  from public.profiles where id = auth.uid();

  if v_owned_count >= 1 and not coalesce(v_entitled, false) then
    raise exception 'You already own a fleet organization. Creating more than one requires the multi-fleet add-on.';
  end if;

  insert into public.organizations (name, created_by)
  values (trim(p_name), auth.uid())
  returning id into v_org_id;

  insert into public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
  values (v_org_id, auth.uid(), 'owner', true, now());

  update public.profiles
  set account_type = 'fleet_admin', default_org_id = v_org_id
  where id = auth.uid();

  return v_org_id;
end;
$$;

revoke all on function public.create_organization(text) from public;
revoke all on function public.create_organization(text) from anon;
grant execute on function public.create_organization(text) to authenticated;
