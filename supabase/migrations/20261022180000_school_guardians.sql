-- School bus parents / guardians, step 1 (2026-10-22, owner's spec).
--   * Only an org admin or owner authorizes a parent, by email, for one or
--     more students of a School transportation fleet. The parent gets an ID
--     (CM-######) and signs in with that ID and a password.
--   * A guardian is NOT an organization member: membership opens fleet
--     data (trips, vehicles, people) through is_org_member() policies. A
--     guardian only ever reaches their own children, through the functions
--     and policies below.
--   * Student data shown to a guardian stays minimal (first name, last
--     initial, their stop); everything else stays with the fleet.

set local lock_timeout = '5s';

insert into ops.domain_tables (tbl, domain) values
  ('school_guardians', 'school_bus'),
  ('student_guardians', 'school_bus'),
  ('guardian_invites', 'school_bus')
on conflict (tbl) do update set domain = excluded.domain;

create table if not exists public.school_guardians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  first_name text not null check (length(btrim(first_name)) between 1 and 60),
  last_name text not null check (length(btrim(last_name)) between 1 and 60),
  email text not null check (email = lower(btrim(email))),
  display_id text unique,
  user_id uuid references auth.users(id) on delete set null,
  claimed_at timestamptz,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (organization_id, email)
);
create index if not exists school_guardians_user_idx on public.school_guardians (user_id) where user_id is not null;

create table if not exists public.student_guardians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  guardian_id uuid not null references public.school_guardians(id) on delete cascade,
  -- Unlinking keeps the row (is_active false, removed_at): the history of
  -- who could see a child stays on record.
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  removed_at timestamptz,
  unique (student_id, guardian_id)
);
create index if not exists student_guardians_guardian_idx on public.student_guardians (guardian_id);

create table if not exists public.guardian_invites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  guardian_id uuid not null references public.school_guardians(id) on delete cascade,
  email text not null,
  token_hash text not null unique,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'expired', 'revoked')),
  expires_at timestamptz not null default now() + interval '7 days',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);
create index if not exists guardian_invites_guardian_idx on public.guardian_invites (guardian_id);

-- CM-###### (six digits), unique among guardians.
create or replace function public.fn_assign_guardian_display_id()
returns trigger language plpgsql set search_path to 'public' as $$
declare
  v_new_id text;
  v_attempts int := 0;
begin
  if new.display_id is null or btrim(new.display_id) = '' then
    loop
      v_new_id := 'CM-' || lpad(floor(random() * 1000000)::text, 6, '0');
      exit when not exists (select 1 from public.school_guardians where display_id = v_new_id);
      v_attempts := v_attempts + 1;
      if v_attempts >= 200 then
        raise exception '[ControlMiles] Could not generate a unique guardian ID after % attempts.', v_attempts;
      end if;
    end loop;
    new.display_id := v_new_id;
  end if;
  return new;
end $$;
revoke execute on function public.fn_assign_guardian_display_id() from public, anon, authenticated;

create or replace trigger tr_school_guardians_display_id
  before insert on public.school_guardians
  for each row execute function public.fn_assign_guardian_display_id();

-- Reads: the fleet's admins/owners/operators see its guardians; a guardian
-- sees only their own row and their own links. No direct writes: every
-- change goes through the functions below.
alter table public.school_guardians enable row level security;
alter table public.student_guardians enable row level security;
alter table public.guardian_invites enable row level security;

create policy school_guardians_select on public.school_guardians for select
  using (public.is_org_operator_or_above(organization_id) or user_id = (select auth.uid()));
create policy student_guardians_select on public.student_guardians for select
  using (
    public.is_org_operator_or_above(organization_id)
    or (is_active and exists (select 1 from public.school_guardians g
                where g.id = guardian_id and g.user_id = (select auth.uid()) and g.is_active))
  );
create policy guardian_invites_select on public.guardian_invites for select
  using (public.is_org_admin_or_owner(organization_id));

-- Owner or admin: authorize a parent for some students, by email.
-- Returns the invite token (the email with the link is sent by
-- send-guardian-invite) and the parent's ID.
create or replace function public.create_guardian_invite(
  p_organization_id uuid, p_email text, p_first_name text, p_last_name text, p_student_ids uuid[]
)
returns table (token text, display_id text)
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_guardian public.school_guardians;
  v_token text;
  v_allowed boolean;
begin
  if not public.is_org_admin_or_owner(p_organization_id) then
    raise exception 'Only an admin or the owner can authorize a parent';
  end if;
  if not exists (select 1 from public.organizations where id = p_organization_id and industry_template = 'school_transport') then
    raise exception 'Parents are only available for School transportation fleets';
  end if;
  select public.check_rate_limit('create_guardian_invite', auth.uid()::text, 30, 3600) into v_allowed;
  if not v_allowed then
    raise exception 'Too many invites created recently. Try again later.';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'A valid email is required';
  end if;
  if length(btrim(coalesce(p_first_name, ''))) = 0 or length(btrim(coalesce(p_last_name, ''))) = 0 then
    raise exception 'First and last name are required';
  end if;
  if coalesce(array_length(p_student_ids, 1), 0) = 0 then
    raise exception 'Choose at least one student';
  end if;
  if exists (
    select 1 from unnest(p_student_ids) s(id)
     where not exists (select 1 from public.students st
                        where st.id = s.id and st.organization_id = p_organization_id and st.is_active)
  ) then
    raise exception 'A student does not belong to this fleet';
  end if;

  insert into public.school_guardians (organization_id, first_name, last_name, email, created_by)
  values (p_organization_id, btrim(p_first_name), btrim(p_last_name), v_email, auth.uid())
  on conflict (organization_id, email) do update
    set first_name = excluded.first_name, last_name = excluded.last_name,
        is_active = true, revoked_at = null
  returning * into v_guardian;

  insert into public.student_guardians (organization_id, student_id, guardian_id)
  select p_organization_id, s.id, v_guardian.id from unnest(p_student_ids) s(id)
  on conflict (student_id, guardian_id) do update set is_active = true, removed_at = null;

  update public.guardian_invites set status = 'expired'
   where guardian_id = v_guardian.id and status = 'pending';

  v_token := encode(gen_random_bytes(24), 'hex');
  insert into public.guardian_invites (organization_id, guardian_id, email, token_hash, created_by)
  values (p_organization_id, v_guardian.id, v_email, encode(digest(v_token, 'sha256'), 'hex'), auth.uid());

  return query select v_token, v_guardian.display_id;
end $$;
revoke execute on function public.create_guardian_invite(uuid, text, text, text, uuid[]) from public, anon;
grant execute on function public.create_guardian_invite(uuid, text, text, text, uuid[]) to authenticated;

-- Public landing for the invite link (no session yet): is it valid, for
-- which fleet and email, and does that email already have an account.
create or replace function public.resolve_guardian_invite(p_token text)
returns table (valid boolean, org_name text, email text, display_id text, has_account boolean)
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare
  v_hash text := encode(digest(coalesce(p_token, ''), 'sha256'), 'hex');
  v_allowed boolean;
  r record;
begin
  select public.check_rate_limit('resolve_guardian_invite', v_hash, 20, 60) into v_allowed;
  if not v_allowed then
    return query select false, null::text, null::text, null::text, null::boolean; return;
  end if;
  select o.name, i.email, g.display_id into r
    from public.guardian_invites i
    join public.school_guardians g on g.id = i.guardian_id and g.is_active
    join public.organizations o on o.id = i.organization_id
   where i.token_hash = v_hash and i.status = 'pending' and i.expires_at > now();
  if not found then
    return query select false, null::text, null::text, null::text, null::boolean; return;
  end if;
  return query select true, r.name::text, r.email::text, r.display_id::text,
    exists (select 1 from public.profiles p where lower(p.email) = lower(r.email));
end $$;
revoke execute on function public.resolve_guardian_invite(text) from public;
grant execute on function public.resolve_guardian_invite(text) to anon, authenticated;

-- The invited parent, signed in with the invited email, accepts: their
-- account is tied to the guardian record (and its ID).
create or replace function public.accept_guardian_invite(p_token text)
returns text
language plpgsql security definer set search_path to 'public', 'extensions' as $$
declare
  v_hash text := encode(digest(coalesce(p_token, ''), 'sha256'), 'hex');
  v_email text;
  v_invite public.guardian_invites;
  v_display_id text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select email into v_email from public.profiles where id = auth.uid();
  select * into v_invite from public.guardian_invites
   where token_hash = v_hash and status = 'pending' and expires_at > now();
  if not found then raise exception 'Invalid or expired invite'; end if;
  if lower(coalesce(v_email, '')) <> lower(v_invite.email) then
    raise exception 'This invite was sent to a different email address';
  end if;
  update public.school_guardians
     set user_id = auth.uid(), claimed_at = coalesce(claimed_at, now())
   where id = v_invite.guardian_id and is_active
     and (user_id is null or user_id = auth.uid())
  returning display_id into v_display_id;
  if v_display_id is null then raise exception 'Invalid or expired invite'; end if;
  update public.guardian_invites set status = 'accepted', accepted_at = now() where id = v_invite.id;
  return v_display_id;
end $$;
revoke execute on function public.accept_guardian_invite(text) from public, anon;
grant execute on function public.accept_guardian_invite(text) to authenticated;

-- Owner or admin: take a parent's access away (or give one student back).
create or replace function public.revoke_guardian(p_guardian_id uuid)
returns void
language plpgsql security definer set search_path to 'public' as $$
declare v_org uuid;
begin
  select organization_id into v_org from public.school_guardians where id = p_guardian_id;
  if v_org is null or not public.is_org_admin_or_owner(v_org) then raise exception 'Not authorized'; end if;
  update public.school_guardians set is_active = false, revoked_at = now() where id = p_guardian_id;
  update public.guardian_invites set status = 'revoked' where guardian_id = p_guardian_id and status = 'pending';
end $$;
revoke execute on function public.revoke_guardian(uuid) from public, anon;
grant execute on function public.revoke_guardian(uuid) to authenticated;

create or replace function public.unlink_guardian_student(p_guardian_id uuid, p_student_id uuid)
returns void
language plpgsql security definer set search_path to 'public' as $$
declare v_org uuid;
begin
  select organization_id into v_org from public.school_guardians where id = p_guardian_id;
  if v_org is null or not public.is_org_admin_or_owner(v_org) then raise exception 'Not authorized'; end if;
  update public.student_guardians set is_active = false, removed_at = now()
   where guardian_id = p_guardian_id and student_id = p_student_id and is_active;
end $$;
revoke execute on function public.unlink_guardian_student(uuid, uuid) from public, anon;
grant execute on function public.unlink_guardian_student(uuid, uuid) to authenticated;

-- The signed-in parent's children (only theirs, only active links).
create or replace function public.my_guardian_children()
returns table (student_id uuid, organization_id uuid, org_name text, first_name text, last_initial text)
language sql stable security definer set search_path to 'public' as $$
  select st.id, st.organization_id, o.name, st.first_name, st.last_initial
    from public.school_guardians g
    join public.student_guardians sg on sg.guardian_id = g.id and sg.is_active
    join public.students st on st.id = sg.student_id and st.is_active
    join public.organizations o on o.id = st.organization_id
   where g.user_id = auth.uid() and g.is_active
   order by st.first_name;
$$;
revoke execute on function public.my_guardian_children() from public, anon;
grant execute on function public.my_guardian_children() to authenticated;

-- For ID sign-in (resolve-driver-login, service role only): the account
-- behind an active, claimed guardian ID.
create or replace function public.guardian_login_user(p_display_id text)
returns uuid
language sql stable security definer set search_path to 'public' as $$
  select user_id from public.school_guardians
   where display_id = upper(btrim(p_display_id)) and is_active and user_id is not null;
$$;
revoke execute on function public.guardian_login_user(text) from public, anon, authenticated;
