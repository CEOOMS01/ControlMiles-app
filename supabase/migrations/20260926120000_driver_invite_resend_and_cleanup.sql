-- Driver invitations, zero-friction roster (explicit user request, 2026-09-26:
-- "Add driver" and "Invite driver" become ONE flow that emails the invitation,
-- with Invited / Resend on the roster, like Motive's Fleet Users list).
--
-- Fixes two real bugs found while unifying, plus the missing pieces:
--
-- 1. RE-SENDING an invite minted a brand-new fleet_driver_slots row (another
--    CM-D#### id) every time and left the previous one orphaned as
--    "Unclaimed" -- the roster filled with ghost drivers. create_driver_invite
--    now REUSES the slot of an earlier, still-unclaimed invite to the same
--    email in the same org.
-- 2. Removing an unclaimed slot that had been invited FAILED with a foreign
--    key error (driver_invites.slot_id had no ON DELETE action). The slot can
--    now be removed; its pending invite is cancelled first (status 'expired',
--    so the emailed link stops working) and the invite row keeps its history.
-- 3. resend_driver_invite: issues a fresh link (and expires the old one) for
--    the SAME slot. Same authority hierarchy as create_driver_invite.
-- 4. Operators can now SEE invites (they could already create them): the
--    roster shows Invited/Expired per driver, and operators use the roster.
--
-- No client can read a token_hash or write these tables directly; the raw
-- token is returned once, to the caller, to be emailed by send-driver-invite
-- (unchanged), which re-resolves it server-side.

-- ------------------------------------------------------------------
-- 2. FK: never block removing a slot; cancel its pending invite instead
-- ------------------------------------------------------------------
do $$
declare c text;
begin
  select conname into c
  from pg_constraint
  where conrelid = 'public.driver_invites'::regclass
    and contype = 'f'
    and confrelid = 'public.fleet_driver_slots'::regclass;
  if c is not null then
    execute format('alter table public.driver_invites drop constraint %I', c);
  end if;
  alter table public.driver_invites
    add constraint driver_invites_slot_id_fkey
    foreign key (slot_id) references public.fleet_driver_slots(id) on delete set null;
end $$;

create or replace function public.trg_slot_delete_cancels_invite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.driver_invites
     set status = 'expired'
   where slot_id = old.id and status = 'pending';
  return old;
end;
$$;

drop trigger if exists trg_slot_delete_cancels_invite on public.fleet_driver_slots;
create trigger trg_slot_delete_cancels_invite
  before delete on public.fleet_driver_slots
  for each row execute function public.trg_slot_delete_cancels_invite();

-- ------------------------------------------------------------------
-- 1. create_driver_invite: reuse the slot of an earlier unclaimed invite
--    (identical to the previous version in every other respect)
-- ------------------------------------------------------------------
create or replace function public.create_driver_invite(
  p_org_id uuid,
  p_email text,
  p_first_name text,
  p_last_name text,
  p_intended_role text default 'driver'
)
returns text
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_email text := lower(trim(p_email));
  v_first_name text := trim(p_first_name);
  v_last_name text := trim(p_last_name);
  v_target_id uuid;
  v_target_account_type text;
  v_existing_membership uuid;
  v_token text;
  v_hash text;
  v_allowed boolean;
  v_slot_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_intended_role not in ('driver', 'operator', 'admin') then
    raise exception 'Invalid role: %', p_intended_role;
  end if;

  if p_intended_role = 'admin' and not public.is_org_owner(p_org_id) then
    raise exception 'Only the organization owner can invite someone directly as an admin';
  end if;

  if p_intended_role = 'operator' and not public.is_org_admin_or_owner(p_org_id) then
    raise exception 'Only an org admin or owner can invite someone directly as an operator';
  end if;

  if not public.is_org_operator_or_above(p_org_id) then
    raise exception 'Only an org admin, owner, or operator can invite drivers';
  end if;

  select public.check_rate_limit('create_driver_invite', auth.uid()::text, 20, 3600) into v_allowed;
  if not v_allowed then
    raise exception 'Too many invites created recently. Try again later.';
  end if;

  if v_email = '' or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'A valid email is required';
  end if;

  if v_first_name = '' or v_last_name = '' then
    raise exception 'First and last name are required';
  end if;

  select id, account_type into v_target_id, v_target_account_type
  from public.profiles
  where lower(email) = v_email
  limit 1;

  if v_target_id is not null then
    if v_target_account_type = 'fleet_admin' then
      raise exception 'This person already owns their own fleet and cannot be invited as a driver';
    end if;

    select id into v_existing_membership
    from public.organization_members
    where organization_id = p_org_id and user_id = v_target_id and is_active = true;

    if v_existing_membership is not null then
      raise exception 'This person is already a member of this organization';
    end if;
  end if;

  -- Reuse this person's slot when they were already invited and never
  -- accepted: a re-send must not mint another CM-D#### id.
  select s.id into v_slot_id
  from public.driver_invites i
  join public.fleet_driver_slots s on s.id = i.slot_id
  where i.organization_id = p_org_id
    and lower(i.email) = v_email
    and s.claimed_by is null
  order by i.created_at desc
  limit 1;

  update public.driver_invites
  set status = 'expired'
  where organization_id = p_org_id and lower(email) = v_email and status = 'pending';

  if v_slot_id is not null then
    update public.fleet_driver_slots
       set first_name = v_first_name, last_name = v_last_name
     where id = v_slot_id;
  else
    insert into public.fleet_driver_slots (organization_id, first_name, last_name, claim_code_hash, created_by)
    values (p_org_id, v_first_name, v_last_name, encode(gen_random_bytes(24), 'hex'), auth.uid())
    returning id into v_slot_id;
  end if;

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := encode(digest(v_token, 'sha256'), 'hex');

  insert into public.driver_invites (organization_id, email, token_hash, created_by, first_name, last_name, slot_id, intended_role)
  values (p_org_id, v_email, v_hash, auth.uid(), v_first_name, v_last_name, v_slot_id, p_intended_role);

  return v_token;
end;
$function$;

revoke execute on function public.create_driver_invite(uuid, text, text, text, text) from public, anon;
grant execute on function public.create_driver_invite(uuid, text, text, text, text) to authenticated;

-- ------------------------------------------------------------------
-- 3. resend_driver_invite: a fresh link for the SAME driver row
-- ------------------------------------------------------------------
create or replace function public.resend_driver_invite(p_invite_id uuid)
returns text
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_inv record;
  v_allowed boolean;
  v_token text;
  v_hash text;
  v_target_id uuid;
  v_target_account_type text;
  v_existing_membership uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select id, organization_id, email, first_name, last_name, slot_id, intended_role, status
    into v_inv
  from public.driver_invites
  where id = p_invite_id;

  if not found then
    raise exception 'Invitation not found';
  end if;

  if v_inv.status = 'accepted' then
    raise exception 'This invitation was already accepted';
  end if;

  if not public.is_org_operator_or_above(v_inv.organization_id) then
    raise exception 'Only an org admin, owner, or operator can resend invitations';
  end if;

  -- Same hierarchy as create_driver_invite: an admin/operator invitation can
  -- only be re-issued by someone who could have created it.
  if v_inv.intended_role = 'admin' and not public.is_org_owner(v_inv.organization_id) then
    raise exception 'Only the organization owner can resend an admin invitation';
  end if;
  if v_inv.intended_role = 'operator' and not public.is_org_admin_or_owner(v_inv.organization_id) then
    raise exception 'Only an org admin or owner can resend an operator invitation';
  end if;

  -- The driver row was removed (or claimed some other way): nothing to resend.
  if v_inv.slot_id is null then
    raise exception 'This driver was removed. Add them again to send a new invitation';
  end if;
  if exists (
    select 1 from public.fleet_driver_slots
    where id = v_inv.slot_id and claimed_by is not null
  ) then
    raise exception 'This driver already joined';
  end if;

  select public.check_rate_limit('resend_driver_invite', auth.uid()::text, 20, 3600) into v_allowed;
  if not v_allowed then
    raise exception 'Too many invitations sent recently. Try again later.';
  end if;

  select id, account_type into v_target_id, v_target_account_type
  from public.profiles
  where lower(email) = lower(v_inv.email)
  limit 1;

  if v_target_id is not null then
    if v_target_account_type = 'fleet_admin' then
      raise exception 'This person already owns their own fleet and cannot be invited as a driver';
    end if;
    select id into v_existing_membership
    from public.organization_members
    where organization_id = v_inv.organization_id and user_id = v_target_id and is_active = true;
    if v_existing_membership is not null then
      raise exception 'This person is already a member of this organization';
    end if;
  end if;

  update public.driver_invites
     set status = 'expired'
   where organization_id = v_inv.organization_id
     and lower(email) = lower(v_inv.email)
     and status = 'pending';

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := encode(digest(v_token, 'sha256'), 'hex');

  insert into public.driver_invites
    (organization_id, email, token_hash, created_by, first_name, last_name, slot_id, intended_role)
  values
    (v_inv.organization_id, v_inv.email, v_hash, auth.uid(), v_inv.first_name, v_inv.last_name, v_inv.slot_id, v_inv.intended_role);

  return v_token;
end;
$function$;

revoke execute on function public.resend_driver_invite(uuid) from public, anon;
grant execute on function public.resend_driver_invite(uuid) to authenticated;

-- ------------------------------------------------------------------
-- 4. Operators can see invitations (create_driver_invite already lets them
--    create them); token_hash is never exposed to the client by the roster.
-- ------------------------------------------------------------------
drop policy if exists driver_invites_select_admin on public.driver_invites;
drop policy if exists driver_invites_select_operator_up on public.driver_invites;
create policy driver_invites_select_operator_up on public.driver_invites
  for select to authenticated
  using (public.is_org_operator_or_above(organization_id));
