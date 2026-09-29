-- RULE (user, 2026-09-29): a fleet driver can't delete or edit their
-- trips -- only the fleet's owner or an admin can. Operators can't either.
-- Gig trips (organization_id null) stay the driver's own to delete.
--
-- Editing: closed trips were already frozen for everyone
-- (fn_freeze_closed_session / fn_freeze_closed_session_section), admins
-- included -- recorded miles are immutable evidence; unchanged here.
--
-- Deleting: sessions_delete used to be (user_id = auth.uid()) for every
-- trip. The one fleet-driver exception is the app's own cleanup of a trip
-- that failed while starting (TrackingController.startTripFlow deletes the
-- row it just created): open and with no GPS breadcrumbs yet.

drop policy if exists sessions_delete on public.sessions;
create policy sessions_delete on public.sessions
  for delete to authenticated
  using (
    (organization_id is null and user_id = auth.uid())
    or (organization_id is not null and public.is_org_admin_or_owner(organization_id))
    or (
      organization_id is not null
      and user_id = auth.uid()
      and not coalesce(is_closed, false)
      and not exists (
        select 1 from public.session_gps_breadcrumbs b where b.session_id = sessions.id
      )
    )
  );

drop policy if exists sections_delete on public.session_sections;
create policy sections_delete on public.session_sections
  for delete to authenticated
  using (
    (organization_id is null and user_id = auth.uid())
    or (organization_id is not null and public.is_org_admin_or_owner(organization_id))
  );
