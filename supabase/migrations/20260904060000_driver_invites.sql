-- Fleet Sprint 1 (explicit user spec, 2026-09-04): unify the two disconnected
-- invite paths ("invite_member_by_email" for existing users -- silent,
-- in-app only, no email sent -- and "claim_driver_slot" for new users --
-- requires a manually-shared one-time code) into a SINGLE link the admin
-- sends, which then branches automatically depending on whether the
-- invited email already has a ControlMiles account. Both older RPCs are
-- left in place unchanged (claim_driver_slot stays as a fallback for
-- admins who prefer handing a code in person; invite_member_by_email is
-- superseded by this flow going forward but not removed).
--
-- Same hash-then-compare token pattern already proven in
-- fleet_driver_slots/claim_driver_slot -- the raw token is only ever
-- returned once (to the caller of create_driver_invite, for the edge
-- function to email out) and never stored in plaintext.

CREATE TABLE public.driver_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  email text NOT NULL,
  token_hash text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired')),
  created_by uuid REFERENCES public.profiles(id),
  accepted_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '7 days'
);

CREATE INDEX idx_driver_invites_token_hash ON public.driver_invites(token_hash);
CREATE INDEX idx_driver_invites_org_status ON public.driver_invites(organization_id, status);

-- Only one live pending invite per (org, email) at a time -- create_driver_invite
-- expires any prior pending row for the same pair before inserting a new one,
-- so this can never actually conflict; it's a backstop against a race.
CREATE UNIQUE INDEX idx_driver_invites_org_email_pending
  ON public.driver_invites(organization_id, lower(email))
  WHERE status = 'pending';

ALTER TABLE public.driver_invites ENABLE ROW LEVEL SECURITY;

-- Admin/owner of the org can see their own org's invites (e.g. a future
-- "pending invites" list in the fleet dashboard). No direct client
-- INSERT/UPDATE policy -- token_hash generation and status transitions are
-- SECURITY DEFINER-only, same "no direct write path" convention already
-- used for pdf_export_log/vehicle_odometer_checkpoints.
CREATE POLICY driver_invites_select_admin ON public.driver_invites
  FOR SELECT TO authenticated
  USING (is_org_admin_or_owner(organization_id));

REVOKE ALL ON public.driver_invites FROM public, anon;
GRANT SELECT ON public.driver_invites TO authenticated;

-- ============================================================
-- 1. Admin creates the invite, gets back the raw token to email out
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_driver_invite(p_org_id uuid, p_email text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_email text := lower(trim(p_email));
  v_target_id uuid;
  v_target_account_type text;
  v_existing_membership uuid;
  v_token text;
  v_hash text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.is_org_admin_or_owner(p_org_id) THEN
    RAISE EXCEPTION 'Only an org admin or owner can invite drivers';
  END IF;

  IF v_email = '' OR v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'A valid email is required';
  END IF;

  -- Same checks invite_member_by_email already makes -- kept identical so
  -- behavior doesn't silently diverge between the two entry points.
  SELECT id, account_type INTO v_target_id, v_target_account_type
  FROM public.profiles
  WHERE lower(email) = v_email
  LIMIT 1;

  IF v_target_id IS NOT NULL THEN
    IF v_target_account_type = 'fleet_admin' THEN
      RAISE EXCEPTION 'This person already owns their own fleet and cannot be invited as a driver';
    END IF;

    SELECT id INTO v_existing_membership
    FROM public.organization_members
    WHERE organization_id = p_org_id AND user_id = v_target_id AND is_active = true;

    IF v_existing_membership IS NOT NULL THEN
      RAISE EXCEPTION 'This person is already a member of this organization';
    END IF;
  END IF;

  -- Expire any stale pending invite for the same org+email before issuing
  -- a new one, rather than erroring -- an admin re-sending an invite is
  -- the common case, not an exceptional one.
  UPDATE public.driver_invites
  SET status = 'expired'
  WHERE organization_id = p_org_id AND lower(email) = v_email AND status = 'pending';

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := encode(digest(v_token, 'sha256'), 'hex');

  INSERT INTO public.driver_invites (organization_id, email, token_hash, created_by)
  VALUES (p_org_id, v_email, v_hash, auth.uid());

  RETURN v_token;
END;
$$;

REVOKE ALL ON FUNCTION public.create_driver_invite(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_driver_invite(uuid, text) TO authenticated;

-- ============================================================
-- 2. Public (pre-login) resolve -- powers the invite landing screen's
--    Case A / Case B branch. No auth required: this is the whole point,
--    the invited person hasn't necessarily signed in yet.
-- ============================================================
CREATE OR REPLACE FUNCTION public.resolve_driver_invite(p_token text)
RETURNS TABLE(valid boolean, organization_name text, email text, account_exists boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_hash text := encode(digest(coalesce(p_token, ''), 'sha256'), 'hex');
  v_invite record;
BEGIN
  SELECT i.email, i.organization_id, o.name AS org_name
  INTO v_invite
  FROM public.driver_invites i
  JOIN public.organizations o ON o.id = i.organization_id
  WHERE i.token_hash = v_hash
    AND i.status = 'pending'
    AND i.expires_at > now()
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::text, NULL::text, NULL::boolean;
    RETURN;
  END IF;

  RETURN QUERY SELECT
    true,
    v_invite.org_name,
    v_invite.email,
    EXISTS(SELECT 1 FROM public.profiles WHERE lower(profiles.email) = lower(v_invite.email));
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_driver_invite(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_driver_invite(text) TO anon, authenticated;

-- ============================================================
-- 3. Accept -- ONE atomic RPC for both Case A (just signed up) and Case B
--    (already had an account), since by the time this is called the
--    caller is authenticated either way; the only difference between the
--    two cases already happened client-side (signup vs login) before this
--    runs. Mirrors claim_driver_slot/respond_to_invite's atomicity: org
--    membership + account_type + default_org_id + account_type_chosen all
--    move together in one transaction.
-- ============================================================
CREATE OR REPLACE FUNCTION public.accept_driver_invite(p_token text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_caller_email text;
  v_caller_account_type text;
  v_hash text := encode(digest(coalesce(p_token, ''), 'sha256'), 'hex');
  v_invite record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT email, account_type INTO v_caller_email, v_caller_account_type
  FROM public.profiles WHERE id = v_caller;

  IF v_caller_account_type = 'fleet_admin' THEN
    RAISE EXCEPTION 'You already manage your own fleet and cannot join another as a driver';
  END IF;

  SELECT id, organization_id, email INTO v_invite
  FROM public.driver_invites
  WHERE token_hash = v_hash AND status = 'pending' AND expires_at > now()
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired invite';
  END IF;

  -- Critical: the token proves someone with access to that inbox got the
  -- link, but the RPC still only trusts the CALLER's own verified email --
  -- a different logged-in user can never hijack someone else's invite by
  -- guessing/forwarding a token that isn't theirs.
  IF lower(v_caller_email) != lower(v_invite.email) THEN
    RAISE EXCEPTION 'This invite was sent to a different email address';
  END IF;

  INSERT INTO public.organization_members (organization_id, user_id, member_role, is_active, joined_at)
  VALUES (v_invite.organization_id, v_caller, 'driver', true, now())
  ON CONFLICT (organization_id, user_id) DO UPDATE
    SET is_active = true, joined_at = now();

  UPDATE public.profiles
  SET account_type = 'fleet_driver', default_org_id = v_invite.organization_id
  WHERE id = v_caller;

  INSERT INTO public.user_onboarding (user_id, account_type_chosen)
  VALUES (v_caller, true)
  ON CONFLICT (user_id) DO UPDATE SET account_type_chosen = true;

  UPDATE public.driver_invites
  SET status = 'accepted', accepted_by = v_caller
  WHERE id = v_invite.id;

  RETURN v_invite.organization_id;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_driver_invite(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_driver_invite(text) TO authenticated;
