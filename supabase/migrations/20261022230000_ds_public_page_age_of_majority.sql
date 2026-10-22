-- The public enrollment page knows the school's age of majority
-- (2026-10-22), so the form asks for a parent at the same age the database
-- requires one (ds_public_enroll, 20261022210000). Before, the form used a
-- fixed 18: in a state where majority is 19 or 21 a 19-year-old saw no parent
-- fields and then got "a parent is required". Only 'age_of_majority' is new.

set local lock_timeout = '5s';

create or replace function public.ds_public_page(p_slug text)
returns jsonb language sql stable security definer set search_path to 'public' as $function$
  select jsonb_build_object(
           'school', coalesce(nullif(btrim(o.report_display_name), ''), o.name),
           'intro', pg.intro,
           'min_age', pg.min_age,
           'age_of_majority', coalesce((select s.age_of_majority from public.ds_settings s where s.organization_id = o.id), 18),
           'terms_url', pg.terms_url,
           'programs', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name) order by p.sort, p.name)
                                   from public.ds_programs p where p.organization_id = o.id and p.is_active), '[]'::jsonb),
           'branches', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name) order by b.name)
                                   from public.branches b where b.organization_id = o.id and not b.is_archived), '[]'::jsonb))
    from public.ds_public_pages pg
    join public.organizations o on o.id = pg.organization_id
   where pg.slug = lower(p_slug) and pg.enabled
     and public.fn_org_feature_internal(o.id, 'student_portal');
$function$;
