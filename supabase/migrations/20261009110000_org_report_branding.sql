-- Report branding (2026-10-09, user request): each fleet can upload its logo
-- and set the company name printed at the top of its reports (school
-- attendance first). Logos live in a private bucket under the fleet's id;
-- the dashboard shows them through short-lived signed URLs.

alter table public.organizations
  add column if not exists report_display_name text
    check (report_display_name is null or length(report_display_name) <= 120),
  add column if not exists report_logo_path text;

-- Owner/admin only, through this function (organizations' columns are not
-- client-writable one by one).
create or replace function public.set_report_branding(p_organization_id uuid, p_display_name text, p_logo_path text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_org_admin_or_owner(p_organization_id) then
    raise exception 'Not authorized';
  end if;
  if p_logo_path is not null and split_part(p_logo_path, '/', 1) <> p_organization_id::text then
    raise exception 'Logo must be stored under the fleet''s folder';
  end if;
  update public.organizations
     set report_display_name = nullif(trim(p_display_name), ''),
         report_logo_path = p_logo_path
   where id = p_organization_id;
end $$;
revoke execute on function public.set_report_branding(uuid, text, text) from public, anon;
grant execute on function public.set_report_branding(uuid, text, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('org_branding', 'org_branding', false, 2097152, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Path: <organization_id>/<file>. Admins/owners manage; members can read.
drop policy if exists org_branding_select_member on storage.objects;
create policy org_branding_select_member on storage.objects for select to authenticated
  using (bucket_id = 'org_branding'
         and public.is_org_member(((storage.foldername(name))[1])::uuid));
drop policy if exists org_branding_insert_admin on storage.objects;
create policy org_branding_insert_admin on storage.objects for insert to authenticated
  with check (bucket_id = 'org_branding'
              and public.is_org_admin_or_owner(((storage.foldername(name))[1])::uuid));
drop policy if exists org_branding_update_admin on storage.objects;
create policy org_branding_update_admin on storage.objects for update to authenticated
  using (bucket_id = 'org_branding'
         and public.is_org_admin_or_owner(((storage.foldername(name))[1])::uuid));
drop policy if exists org_branding_delete_admin on storage.objects;
create policy org_branding_delete_admin on storage.objects for delete to authenticated
  using (bucket_id = 'org_branding'
         and public.is_org_admin_or_owner(((storage.foldername(name))[1])::uuid));
