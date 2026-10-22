-- Domain guard follow-up (2026-10-22): nothing slips past it unseen.
--   * Every DDL run with the bypass (set local cm.skip_domain_check = 'on')
--     is written to ops.domain_check_log, with what it changed.
--   * A daily cron job runs the full check and logs the result, so a break
--     made with the bypass, or by a role the guard does not watch, shows up
--     within a day (one row a day; no cleanup needed).
-- Read it with:
--   select * from ops.domain_check_log order by checked_at desc limit 20;

set local lock_timeout = '5s';

create table if not exists ops.domain_check_log (
  id bigint generated always as identity primary key,
  checked_at timestamptz not null default now(),
  source text not null check (source in ('daily', 'bypass')),
  violation_count int,
  detail text
);
create index if not exists domain_check_log_checked_at_idx on ops.domain_check_log (checked_at desc);

create or replace function ops.fn_domain_guard()
returns event_trigger language plpgsql set search_path to 'pg_catalog' as $$
declare
  v text;
begin
  if current_user <> 'postgres' then
    return;
  end if;
  if coalesce(current_setting('cm.skip_domain_check', true), '') = 'on' then
    begin
      insert into ops.domain_check_log (source, detail)
      select 'bypass', string_agg(c.command_tag || ' ' || coalesce(c.object_identity, '?'), E'\n')
        from pg_event_trigger_ddl_commands() c;
    exception when others then
      raise warning 'domain guard bypass not logged: %', sqlerrm;
    end;
    return;
  end if;
  begin
    select string_agg(x.rule || '  ' || x.object || ': ' || x.detail, E'\n')
      into v
      from pg_event_trigger_ddl_commands() c
      cross join lateral ops.domain_violations(
        false,
        case when c.classid = 'pg_proc'::regclass then c.objid end,
        case when c.classid = 'pg_trigger'::regclass then c.objid end,
        case when c.classid = 'pg_class'::regclass then c.objid end
      ) x
     where c.command_tag in ('CREATE FUNCTION', 'ALTER FUNCTION', 'CREATE TRIGGER', 'CREATE TABLE')
       and c.classid in ('pg_proc'::regclass, 'pg_trigger'::regclass, 'pg_class'::regclass);
  exception when others then
    -- A bug in the check must never block a migration.
    raise warning 'domain guard skipped: %', sqlerrm;
    return;
  end;
  if v is not null then
    raise exception 'Domain boundary check failed'
      using detail = v,
            hint = 'Register the table or trigger in ops.domain_tables / ops.domain_triggers before creating it, '
                   'add the WHEN guard, or allow the function in ops.domain_allowed_functions. '
                   'See supabase/checks/domain_boundaries.sql.';
  end if;
end $$;
revoke execute on function ops.fn_domain_guard() from public, anon, authenticated;

create or replace function ops.fn_domain_check_daily()
returns void language plpgsql set search_path to 'pg_catalog' as $$
begin
  insert into ops.domain_check_log (source, violation_count, detail)
  select 'daily', count(*), string_agg(v.rule || '  ' || v.object || ': ' || v.detail, E'\n')
    from ops.domain_violations() v;
end $$;
revoke execute on function ops.fn_domain_check_daily() from public, anon, authenticated;

select cron.schedule('domain-boundaries-daily', '43 7 * * *', 'select ops.fn_domain_check_daily()');
