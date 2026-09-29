-- Age (18+) + Terms/Privacy acceptance, recorded (user rule 2026-09-29:
-- "ya está en los términos y condiciones, tanto la app como la web lo debe
-- mostrar"). The Terms already require 18+; until now the web sign-up had
-- no checkbox at all, Google sign-ups never saw the age line, and nothing
-- recorded when (or to which version) anyone agreed.
--
-- legal_accepted_at / legal_terms_version are written only by
-- accept_legal_terms() (SECURITY DEFINER), never directly by a client: the
-- existing profile guard now protects them too, so the record is evidence.

alter table public.profiles
  add column if not exists legal_accepted_at timestamptz,
  add column if not exists legal_terms_version text;

create or replace function public.fn_guard_profile_protected_columns()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') then
    if new.id                     is distinct from old.id
       or new.display_id          is distinct from old.display_id
       or new.email               is distinct from old.email
       or new.account_type        is distinct from old.account_type
       or new.is_active           is distinct from old.is_active
       or new.default_org_id      is distinct from old.default_org_id
       or new.base_entitled       is distinct from old.base_entitled
       or new.premium_entitled    is distinct from old.premium_entitled
       or new.multi_org_entitled  is distinct from old.multi_org_entitled
       or new.tier_enforcement_exempt is distinct from old.tier_enforcement_exempt
       or new.created_at          is distinct from old.created_at
       or new.legal_accepted_at   is distinct from old.legal_accepted_at
       or new.legal_terms_version is distinct from old.legal_terms_version
    then
      raise exception 'PROTECTED_PROFILE_COLUMN: this field cannot be changed directly';
    end if;
  end if;
  return new;
end;
$$;

-- The caller confirms they are 18+ and accept the Terms/Privacy of
-- p_version (the documents' "Last updated" date, e.g. '2026-09-09').
create or replace function public.accept_legal_terms(p_version text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_version is null or p_version !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'Invalid terms version';
  end if;
  update public.profiles
     set legal_accepted_at = now(), legal_terms_version = p_version
   where id = auth.uid();
end;
$$;

revoke execute on function public.accept_legal_terms(text) from public, anon;
grant execute on function public.accept_legal_terms(text) to authenticated;
