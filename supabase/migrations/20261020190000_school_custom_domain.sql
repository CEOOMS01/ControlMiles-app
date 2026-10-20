-- Driving school website integration, level 3 (user request 2026-10-20):
-- the school's own address, e.g. book.yourschool.com, shows its CMFleet
-- enrollment page. The school adds two DNS records: a TXT record that
-- proves it owns the name (_cmfleet.<host> = cmfleet-verify=<token>) and a
-- CNAME to Vercel. Only after the TXT check does the web app add the name
-- to the Vercel project, so nobody can claim another school's address.
-- Everything is reversible: the address can be removed at any time.
--
-- The domain columns are written only through the functions below; the
-- office's own page settings keep their column grants.

alter table public.ds_public_pages
  add column if not exists custom_domain text unique
    check (custom_domain is null or (custom_domain ~ '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.){2,}[a-z0-9]([a-z0-9-]*[a-z0-9])?$' and length(custom_domain) <= 253)),
  add column if not exists domain_token text,
  add column if not exists domain_status text not null default 'none'
    check (domain_status in ('none', 'pending', 'verified', 'error')),
  add column if not exists domain_message text check (domain_message is null or length(domain_message) <= 300),
  add column if not exists domain_checked_at timestamptz,
  add column if not exists domain_verified_at timestamptz;

revoke insert, update on public.ds_public_pages from authenticated;
grant insert (organization_id, slug, enabled, intro, min_age, terms_url, allowed_origins, updated_at)
  on public.ds_public_pages to authenticated;
grant update (slug, enabled, intro, min_age, terms_url, allowed_origins, updated_at)
  on public.ds_public_pages to authenticated;

-- Set (or change) the address: a new token, waiting for DNS.
create or replace function public.ds_set_custom_domain(p_org uuid, p_domain text)
returns text language plpgsql security definer set search_path to 'public' as $$
declare
  v_domain text := lower(btrim(p_domain));
  v_token text := replace(gen_random_uuid()::text, '-', '');
begin
  if not public.is_org_admin_or_owner(p_org) or not public.fn_org_has_feature(p_org, 'student_portal') then
    raise exception 'Not authorized';
  end if;
  if v_domain !~ '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.){2,}[a-z0-9]([a-z0-9-]*[a-z0-9])?$' or length(v_domain) > 253 then
    raise exception 'Use a subdomain like book.yourschool.com' using errcode = 'P0001';
  end if;
  if v_domain like '%controlmiles.com' or v_domain like '%vercel.app' then
    raise exception 'Use an address on your own domain' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.ds_public_pages where custom_domain = v_domain and organization_id <> p_org) then
    raise exception 'That address is already connected to another school' using errcode = 'P0001';
  end if;
  update public.ds_public_pages
     set custom_domain = v_domain, domain_token = v_token, domain_status = 'pending',
         domain_message = null, domain_checked_at = null, domain_verified_at = null, updated_at = now()
   where organization_id = p_org;
  if not found then raise exception 'Save your page settings first' using errcode = 'P0001'; end if;
  return v_token;
end $$;

-- Record the result of a check (the web app looks at DNS and Vercel).
create or replace function public.ds_mark_custom_domain(p_org uuid, p_status text, p_message text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.is_org_admin_or_owner(p_org) or not public.fn_org_has_feature(p_org, 'student_portal') then
    raise exception 'Not authorized';
  end if;
  if p_status not in ('pending', 'verified', 'error') then raise exception 'Bad status'; end if;
  update public.ds_public_pages
     set domain_status = p_status,
         domain_message = left(p_message, 300),
         domain_checked_at = now(),
         domain_verified_at = case when p_status = 'verified' then coalesce(domain_verified_at, now()) else null end
   where organization_id = p_org and custom_domain is not null;
end $$;

-- Remove the address (the web app also removes it from Vercel).
create or replace function public.ds_clear_custom_domain(p_org uuid)
returns text language plpgsql security definer set search_path to 'public' as $$
declare
  v_old text;
begin
  if not public.is_org_admin_or_owner(p_org) or not public.fn_org_has_feature(p_org, 'student_portal') then
    raise exception 'Not authorized';
  end if;
  select custom_domain into v_old from public.ds_public_pages where organization_id = p_org;
  update public.ds_public_pages
     set custom_domain = null, domain_token = null, domain_status = 'none', domain_message = null,
         domain_checked_at = null, domain_verified_at = null, updated_at = now()
   where organization_id = p_org;
  return v_old;
end $$;

revoke execute on function public.ds_set_custom_domain(uuid, text) from public, anon;
revoke execute on function public.ds_mark_custom_domain(uuid, text, text) from public, anon;
revoke execute on function public.ds_clear_custom_domain(uuid) from public, anon;
grant execute on function public.ds_set_custom_domain(uuid, text) to authenticated;
grant execute on function public.ds_mark_custom_domain(uuid, text, text) to authenticated;
grant execute on function public.ds_clear_custom_domain(uuid) to authenticated;

-- Which school page a verified address serves (the web proxy).
create or replace function public.ds_public_slug_for_host(p_host text)
returns text language sql stable security definer set search_path to 'public' as $$
  select pg.slug
    from public.ds_public_pages pg
   where pg.custom_domain = lower(p_host) and pg.domain_status = 'verified' and pg.enabled
     and public.fn_org_feature_internal(pg.organization_id, 'student_portal');
$$;
revoke execute on function public.ds_public_slug_for_host(text) from public;
grant execute on function public.ds_public_slug_for_host(text) to anon, authenticated;
