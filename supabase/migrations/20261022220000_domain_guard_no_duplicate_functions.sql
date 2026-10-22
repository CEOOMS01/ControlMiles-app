-- No duplicate functions (2026-10-22, owner's rule: "siempre asegurate que
-- no haya ninguna funcion duplicada"). New rule R7 in the domain check: a
-- public function name with more than one version (same name, other
-- arguments). It happens when a migration changes a function's arguments
-- with CREATE OR REPLACE: Postgres keeps the old one next to the new one,
-- with its old grants and old logic, still callable.
--   * The DDL guard (ops.fn_domain_guard) stops the CREATE FUNCTION that
--     would make the second version; the migration has to remove the old
--     signature first.
--   * The daily check (ops.fn_domain_check_daily) reports any that exist.
-- R1-R6 are unchanged.

set local lock_timeout = '5s';

create or replace function ops.domain_violations(p_full boolean default true, p_fn oid default null::oid,
                                                 p_tg oid default null::oid, p_tbl oid default null::oid)
returns table(rule text, object text, detail text)
language plpgsql stable set search_path to 'pg_catalog' as $function$
begin
  return query
  with fns as (
    select p.oid, p.proname::text as fn, p.prosrc,
           regexp_replace(regexp_replace(p.prosrc, '--[^\n]*', '', 'g'), '''[^'']*''', '', 'g') as code
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.prokind = 'f'
       and not exists (select 1 from pg_depend e where e.classid = 'pg_proc'::regclass and e.objid = p.oid and e.deptype = 'e')
       and p.proname not in (select a.fn from ops.domain_allowed_functions a)
       and (p_full or p.oid = p_fn)
  ),
  touches as (
    select f.fn, array_agg(distinct d.domain order by d.domain) as domains
      from fns f
      join ops.domain_tables d
        on f.code ~* ('(^|[^a-z0-9_])(public\.)?' || d.tbl || '([^a-z0-9_]|$)')
     group by f.fn
  ),
  core_triggers as (
    select t.oid, c.relname::text as tbl, t.tgname::text as tg
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid and c.relnamespace = 'public'::regnamespace
      join ops.domain_tables d on d.tbl = c.relname and d.domain = 'core'
     where not t.tgisinternal and (p_full or t.oid = p_tg)
  )
  select 'R1', x.fn, array_to_string(x.domains, ', ')
    from touches x
   where 'gig' = any(x.domains) and x.domains && array['fleet', 'school_bus', 'driving_school']
  union all
  select 'R2', x.fn, array_to_string(x.domains, ', ')
    from touches x
   where x.domains @> array['school_bus', 'driving_school']
  union all
  select 'R3', ct.tbl || '.' || ct.tg, 'trigger on a core table is not in ops.domain_triggers'
    from core_triggers ct
   where not exists (select 1 from ops.domain_triggers r where r.tbl = ct.tbl and r.tg = ct.tg)
  union all
  select 'R4', ct.tbl || '.' || ct.tg, r.domain || ' trigger needs WHEN (' || r.guard || ')'
    from core_triggers ct
    join ops.domain_triggers r on r.tbl = ct.tbl and r.tg = ct.tg
   where r.guard is not null
     and position(upper(r.guard) in upper(pg_get_triggerdef(ct.oid))) = 0
  union all
  select 'R5', f.fn, 'builds SQL at run time; allow it in ops.domain_allowed_functions with a reason'
    from fns f
   where f.prosrc ~* '(^|[^a-z0-9_])execute\s+(?!function|procedure)'
  union all
  select 'R6', c.relname::text, 'table is not in ops.domain_tables'
    from pg_class c
   where c.relnamespace = 'public'::regnamespace
     and c.relkind in ('r', 'p')
     and not c.relispartition
     and not exists (select 1 from pg_depend e where e.classid = 'pg_class'::regclass and e.objid = c.oid and e.deptype = 'e')
     and not exists (select 1 from ops.domain_tables d where d.tbl = c.relname)
     and (p_full or c.oid = p_tbl)
  union all
  select 'R7', p.proname::text,
         count(*) || ' versions of this function: ' || string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
           || '; remove the old one'
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and p.prokind = 'f'
     and not exists (select 1 from pg_depend e where e.classid = 'pg_proc'::regclass and e.objid = p.oid and e.deptype = 'e')
     and (p_full or p.proname = (select q.proname from pg_proc q where q.oid = p_fn))
   group by p.proname
  having count(*) > 1;
end $function$;
