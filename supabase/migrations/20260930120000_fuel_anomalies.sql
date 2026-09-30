-- Fuel anomaly alerts (explicit user request, 2026-09-30, after reviewing
-- Control IMS's telematics page: "consumption anomaly alerts" is their
-- headline feature, done with engine hardware). ControlMiles does it with
-- what it already has -- the driver's receipt + the phone's GPS trips --
-- the same checks Samsara/Motive run when they match fuel-card
-- transactions against vehicle location:
--   duplicate        same vehicle, same day, same gallons (or same photo)
--   over_capacity    more gallons in a day than the tank holds
--   location_mismatch  bought in a state the vehicle wasn't in that day
--   no_trip          the vehicle wasn't driven around the purchase date
--   no_miles         a fill-up with no miles driven since the last one
--   low_mpg          fill-to-fill MPG far below the vehicle's own normal
--   price_mismatch   gallons x price doesn't add up to the receipt total
--   price_high       price per gallon well above the fleet's recent norm
-- Each receipt is checked when it's logged (trigger) and again nightly for
-- 14 days (late GPS uploads, the next fill-up), so an alert that stops
-- being true disappears while still open. An admin reviews each one
-- (dismiss = explained, confirm = real problem); reviewed alerts are kept.

-- Optional tank size -- enables the over-capacity check.
alter table public.vehicles
  add column fuel_tank_capacity_gal numeric check (fuel_tank_capacity_gal is null or fuel_tank_capacity_gal > 0);

create table public.fuel_anomalies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  purchase_id uuid not null references public.fuel_purchases(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  kind text not null check (kind in (
    'duplicate', 'over_capacity', 'location_mismatch', 'no_trip',
    'no_miles', 'low_mpg', 'price_mismatch', 'price_high'
  )),
  severity text not null check (severity in ('high', 'medium', 'low')),
  detail text not null,
  metrics jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open', 'dismissed', 'confirmed')),
  review_note text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  notified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (purchase_id, kind)
);

create index fuel_anomalies_org_status_idx on public.fuel_anomalies (organization_id, status, created_at desc);

alter table public.fuel_anomalies enable row level security;

-- Fleet management only (owner/admin/operator see it; drivers don't).
create policy fuel_anomalies_select on public.fuel_anomalies
for select using (
  exists (
    select 1 from public.organization_members m
    where m.organization_id = fuel_anomalies.organization_id
      and m.user_id = auth.uid()
      and m.is_active
      and m.member_role in ('owner', 'admin', 'operator')
  )
);
-- Writes only through the functions below.

-- Receipt photos: an org owner/admin can view the receipts logged for
-- their fleet (the bucket was driver-own-folder only, so the web couldn't
-- show them). Matched through the purchase row, via a stored path column.
alter table public.fuel_purchases
  add column receipt_path text generated always as
    (nullif(split_part(receipt_image_url, '/object/public/fuel_receipts/', 2), '')) stored;
create index fuel_purchases_receipt_path_idx on public.fuel_purchases (receipt_path);

create policy fuel_receipts_select_org_admin
on storage.objects for select
using (
  bucket_id = 'fuel_receipts'
  and exists (
    select 1 from public.fuel_purchases fp
    where fp.receipt_path = storage.objects.name
      and fp.organization_id is not null
      and public.is_org_admin_or_owner(fp.organization_id)
  )
);

-- ── The checks ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_evaluate_fuel_purchase(p_purchase_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  p public.fuel_purchases;
  v public.vehicles;
  found_kinds text[] := '{}';
  v_day_total numeric;
  v_dup boolean;
  v_points int;
  v_in_state boolean;
  v_states text;
  v_trips int;
  v_prev public.fuel_purchases;
  v_miles numeric;
  v_mpg numeric;
  v_baseline numeric;
  v_floor numeric;
  v_median_ppg numeric;
  v_samples int;
  v_checked_location boolean;
begin
  select * into p from public.fuel_purchases where id = p_purchase_id;
  if not found or p.organization_id is null then
    return;
  end if;
  select * into v from public.vehicles where id = p.vehicle_id;

  -- Each check below upserts its alert: a reviewed alert keeps its review,
  -- only the detail/metrics refresh.

  -- 1. duplicate
  select exists (
    select 1 from public.fuel_purchases o
    where o.vehicle_id = p.vehicle_id and o.id <> p.id
      and (o.file_hash = p.file_hash
           or (o.purchase_date = p.purchase_date and abs(o.gallons - p.gallons) < 0.01))
  ) into v_dup;
  if v_dup then
    found_kinds := array_append(found_kinds, 'duplicate');
    insert into public.fuel_anomalies (organization_id, purchase_id, vehicle_id, kind, severity, detail, metrics)
    values (p.organization_id, p.id, p.vehicle_id, 'duplicate', 'high',
      format('Looks like a duplicate: another receipt for this vehicle has the same %s.',
        case when exists (select 1 from public.fuel_purchases o where o.vehicle_id = p.vehicle_id and o.id <> p.id and o.file_hash = p.file_hash)
             then 'photo' else 'date and gallons' end),
      jsonb_build_object('gallons', p.gallons))
    on conflict (purchase_id, kind) do update set detail = excluded.detail, metrics = excluded.metrics;
  end if;

  -- 2. over_capacity (needs the tank size)
  if v.fuel_tank_capacity_gal is not null then
    select sum(gallons) into v_day_total from public.fuel_purchases
    where vehicle_id = p.vehicle_id and purchase_date = p.purchase_date;
    if v_day_total > v.fuel_tank_capacity_gal * 1.05 then
      found_kinds := array_append(found_kinds, 'over_capacity');
      insert into public.fuel_anomalies (organization_id, purchase_id, vehicle_id, kind, severity, detail, metrics)
      values (p.organization_id, p.id, p.vehicle_id, 'over_capacity', 'high',
        format('%s gal bought on %s, but the tank holds %s gal.',
          round(v_day_total, 1), p.purchase_date, round(v.fuel_tank_capacity_gal, 1)),
        jsonb_build_object('day_gallons', v_day_total, 'tank_gallons', v.fuel_tank_capacity_gal))
      on conflict (purchase_id, kind) do update set detail = excluded.detail, metrics = excluded.metrics;
    end if;
  end if;

  -- 3/4. location (only once the day is over, so the day's GPS is in).
  -- Window is the purchase date +-1 day: purchase_date is the driver's
  -- local date, breadcrumbs are UTC.
  v_checked_location := p.purchase_date < (now() at time zone 'utc')::date;
  if v_checked_location then
    select count(*) into v_points from public.session_gps_breadcrumbs b
    where b.vehicle_id = p.vehicle_id
      and b.recorded_at >= (p.purchase_date - 1)::timestamptz
      and b.recorded_at < (p.purchase_date + 2)::timestamptz;

    select count(*) into v_trips from public.sessions s
    where s.vehicle_id = p.vehicle_id
      and s.date_key between p.purchase_date - 1 and p.purchase_date + 1;

    if v_points = 0 and v_trips = 0 then
      found_kinds := array_append(found_kinds, 'no_trip');
      insert into public.fuel_anomalies (organization_id, purchase_id, vehicle_id, kind, severity, detail, metrics)
      values (p.organization_id, p.id, p.vehicle_id, 'no_trip', 'medium',
        format('No trips were recorded for this vehicle between %s and %s.', p.purchase_date - 1, p.purchase_date + 1),
        '{}'::jsonb)
      on conflict (purchase_id, kind) do update set detail = excluded.detail;
    elsif v_points > 0 and p.state_code is not null then
      -- Sample at most ~500 points; a state visit spans many of them.
      with pts as (
        select b.latitude, b.longitude,
               row_number() over (order by b.recorded_at) rn, count(*) over () n
        from public.session_gps_breadcrumbs b
        where b.vehicle_id = p.vehicle_id
          and b.recorded_at >= (p.purchase_date - 1)::timestamptz
          and b.recorded_at < (p.purchase_date + 2)::timestamptz
      ),
      sampled as (select * from pts where rn % greatest(1, n / 500) = 0),
      visited as (
        select distinct sb.state_code from sampled s
        join public.ifta_us_state_boundaries sb
          on ST_Contains(sb.geom, ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326))
      )
      select bool_or(state_code = p.state_code), string_agg(state_code, ', ' order by state_code)
      into v_in_state, v_states from visited;

      if v_states is not null and not coalesce(v_in_state, false) then
        found_kinds := array_append(found_kinds, 'location_mismatch');
        insert into public.fuel_anomalies (organization_id, purchase_id, vehicle_id, kind, severity, detail, metrics)
        values (p.organization_id, p.id, p.vehicle_id, 'location_mismatch', 'high',
          format('Receipt says %s, but the vehicle''s GPS around %s was only in %s.', p.state_code, p.purchase_date, v_states),
          jsonb_build_object('receipt_state', p.state_code, 'gps_states', v_states))
        on conflict (purchase_id, kind) do update set detail = excluded.detail, metrics = excluded.metrics;
      end if;
    end if;
  end if;

  -- 5/6. fill-to-fill consumption: this fill-up's gallons cover the miles
  -- driven since the previous one. Small top-offs (< 5 gal) are noise.
  select * into v_prev from public.fuel_purchases o
  where o.vehicle_id = p.vehicle_id and o.id <> p.id
    and (o.purchase_date < p.purchase_date
         or (o.purchase_date = p.purchase_date and o.created_at < p.created_at))
  order by o.purchase_date desc, o.created_at desc
  limit 1;

  if v_prev.id is not null and p.gallons >= 5 and v_checked_location then
    select coalesce(sum(s.total_miles), 0) into v_miles from public.sessions s
    where s.vehicle_id = p.vehicle_id
      and s.date_key > v_prev.purchase_date and s.date_key <= p.purchase_date;

    if v_miles < 1 and p.purchase_date > v_prev.purchase_date then
      found_kinds := array_append(found_kinds, 'no_miles');
      insert into public.fuel_anomalies (organization_id, purchase_id, vehicle_id, kind, severity, detail, metrics)
      values (p.organization_id, p.id, p.vehicle_id, 'no_miles', 'high',
        format('%s gal bought, but no miles were driven since the last fill-up on %s.', round(p.gallons, 1), v_prev.purchase_date),
        jsonb_build_object('gallons', p.gallons, 'previous_purchase_date', v_prev.purchase_date))
      on conflict (purchase_id, kind) do update set detail = excluded.detail, metrics = excluded.metrics;
    elsif v_miles >= 1 then
      v_mpg := v_miles / p.gallons;
      -- The vehicle's own normal: median fill-to-fill MPG over 180 days.
      with fills as (
        select o.purchase_date, o.gallons,
               lag(o.purchase_date) over (order by o.purchase_date, o.created_at) prev_date
        from public.fuel_purchases o
        where o.vehicle_id = p.vehicle_id
          and o.purchase_date between p.purchase_date - 180 and p.purchase_date
          and o.id <> p.id
      ),
      intervals as (
        select (select sum(s.total_miles) from public.sessions s
                where s.vehicle_id = p.vehicle_id and s.date_key > f.prev_date and s.date_key <= f.purchase_date) / f.gallons as mpg
        from fills f
        where f.prev_date is not null and f.gallons >= 5
      )
      select percentile_cont(0.5) within group (order by mpg), count(*)
      into v_baseline, v_samples
      from intervals where mpg > 0;

      v_floor := case when coalesce(v.ifta_fuel_type, p.fuel_type) = 'gasoline' then 8 else 3.5 end;
      if (v_samples >= 3 and v_mpg < v_baseline * 0.6) or v_mpg < v_floor then
        found_kinds := array_append(found_kinds, 'low_mpg');
        insert into public.fuel_anomalies (organization_id, purchase_id, vehicle_id, kind, severity, detail, metrics)
        values (p.organization_id, p.id, p.vehicle_id, 'low_mpg', 'medium',
          case when v_samples >= 3
            then format('%s MPG since the last fill-up (%s mi on %s gal) — this vehicle normally does %s MPG.',
                   round(v_mpg, 1), round(v_miles), round(p.gallons, 1), round(v_baseline, 1))
            else format('%s MPG since the last fill-up (%s mi on %s gal) — unusually low.',
                   round(v_mpg, 1), round(v_miles), round(p.gallons, 1))
          end,
          jsonb_build_object('mpg', round(v_mpg, 2), 'miles', round(v_miles, 1), 'gallons', p.gallons,
                             'baseline_mpg', round(v_baseline, 2), 'samples', v_samples))
        on conflict (purchase_id, kind) do update set detail = excluded.detail, metrics = excluded.metrics;
      end if;
    end if;
  end if;

  -- 7. receipt arithmetic
  if p.price_per_gallon_usd is not null and p.total_cost_usd is not null
     and abs(p.gallons * p.price_per_gallon_usd - p.total_cost_usd) > greatest(1, p.total_cost_usd * 0.02) then
    found_kinds := array_append(found_kinds, 'price_mismatch');
    insert into public.fuel_anomalies (organization_id, purchase_id, vehicle_id, kind, severity, detail, metrics)
    values (p.organization_id, p.id, p.vehicle_id, 'price_mismatch', 'low',
      format('%s gal × $%s = $%s, but the receipt total is $%s.',
        round(p.gallons, 3), round(p.price_per_gallon_usd, 3),
        round(p.gallons * p.price_per_gallon_usd, 2), round(p.total_cost_usd, 2)),
      jsonb_build_object('expected_total', round(p.gallons * p.price_per_gallon_usd, 2), 'receipt_total', p.total_cost_usd))
    on conflict (purchase_id, kind) do update set detail = excluded.detail, metrics = excluded.metrics;
  end if;

  -- 8. price well above the fleet's recent norm (same fuel, 60 days)
  if p.price_per_gallon_usd is not null then
    select percentile_cont(0.5) within group (order by o.price_per_gallon_usd), count(*)
    into v_median_ppg, v_samples
    from public.fuel_purchases o
    where o.organization_id = p.organization_id and o.id <> p.id
      and o.fuel_type = p.fuel_type and o.price_per_gallon_usd > 0
      and o.purchase_date between p.purchase_date - 60 and p.purchase_date + 60;
    if v_samples >= 5 and p.price_per_gallon_usd > v_median_ppg * 1.25 then
      found_kinds := array_append(found_kinds, 'price_high');
      insert into public.fuel_anomalies (organization_id, purchase_id, vehicle_id, kind, severity, detail, metrics)
      values (p.organization_id, p.id, p.vehicle_id, 'price_high', 'low',
        format('$%s/gal, %s%% above the fleet''s usual $%s/gal for %s.',
          round(p.price_per_gallon_usd, 3), round((p.price_per_gallon_usd / v_median_ppg - 1) * 100),
          round(v_median_ppg, 3), p.fuel_type),
        jsonb_build_object('price', p.price_per_gallon_usd, 'median_price', round(v_median_ppg, 3)))
      on conflict (purchase_id, kind) do update set detail = excluded.detail, metrics = excluded.metrics;
    end if;
  end if;

  -- Open alerts that no longer apply go away (e.g. the GPS arrived late,
  -- or an admin fixed the state). Reviewed ones stay as a record.
  delete from public.fuel_anomalies a
  where a.purchase_id = p.id and a.status = 'open' and not (a.kind = any (found_kinds));
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_evaluate_fuel_purchase(uuid) FROM PUBLIC, anon, authenticated;

-- On insert / IFTA correction: check this receipt and the vehicle's next
-- one (its fill-to-fill MPG depends on this one).
CREATE OR REPLACE FUNCTION public.fn_fuel_purchase_evaluate_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_next uuid;
begin
  -- A failing check must never block a driver from logging a receipt:
  -- errors are logged and the nightly re-check tries again.
  begin
    perform public.fn_evaluate_fuel_purchase(new.id);
    select o.id into v_next from public.fuel_purchases o
    where o.vehicle_id = new.vehicle_id and o.id <> new.id
      and (o.purchase_date > new.purchase_date
           or (o.purchase_date = new.purchase_date and o.created_at > new.created_at))
    order by o.purchase_date, o.created_at
    limit 1;
    if v_next is not null then
      perform public.fn_evaluate_fuel_purchase(v_next);
    end if;
  exception when others then
    raise warning 'fuel anomaly check failed for %: %', new.id, sqlerrm;
  end;
  return null;
end;
$function$;

create trigger fuel_purchases_evaluate
after insert or update of state_code, fuel_type, gallons on public.fuel_purchases
for each row execute function public.fn_fuel_purchase_evaluate_trigger();

-- Nightly: re-check the last 14 days of receipts.
CREATE OR REPLACE FUNCTION public.fn_reevaluate_recent_fuel_purchases()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  r record;
  n integer := 0;
begin
  for r in
    select id from public.fuel_purchases
    where organization_id is not null
      and purchase_date >= (now() at time zone 'utc')::date - 14
  loop
    begin
      perform public.fn_evaluate_fuel_purchase(r.id);
      n := n + 1;
    exception when others then
      raise warning 'fuel anomaly check failed for %: %', r.id, sqlerrm;
    end;
  end loop;
  return n;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_reevaluate_recent_fuel_purchases() FROM PUBLIC, anon, authenticated;

-- ── Review ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.review_fuel_anomaly(
  p_anomaly_id uuid,
  p_status text,
  p_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.fuel_anomalies where id = p_anomaly_id;
  if v_org is null or not public.is_org_admin_or_owner(v_org) then
    raise exception 'Not authorized';
  end if;
  if p_status not in ('open', 'dismissed', 'confirmed') then
    raise exception 'Unknown status: %', p_status;
  end if;
  update public.fuel_anomalies
  set status = p_status,
      review_note = nullif(btrim(p_note), ''),
      reviewed_by = case when p_status = 'open' then null else auth.uid() end,
      reviewed_at = case when p_status = 'open' then null else now() end
  where id = p_anomaly_id;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.review_fuel_anomaly(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.review_fuel_anomaly(uuid, text, text) TO authenticated;

-- Tank size (admin/owner), used by the over-capacity check.
CREATE OR REPLACE FUNCTION public.set_vehicle_tank_capacity(p_vehicle_id uuid, p_gallons numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.vehicles where id = p_vehicle_id;
  if v_org is null or not public.is_org_admin_or_owner(v_org) then
    raise exception 'Not authorized';
  end if;
  if p_gallons is not null and (p_gallons <= 0 or p_gallons > 1000) then
    raise exception 'Tank capacity must be between 1 and 1000 gallons';
  end if;
  update public.vehicles set fuel_tank_capacity_gal = p_gallons where id = p_vehicle_id;
  -- Re-check this vehicle's recent receipts against the new size.
  perform public.fn_evaluate_fuel_purchase(fp.id)
  from public.fuel_purchases fp
  where fp.vehicle_id = p_vehicle_id and fp.purchase_date >= current_date - 90;
end;
$function$;

REVOKE EXECUTE ON FUNCTION public.set_vehicle_tank_capacity(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_vehicle_tank_capacity(uuid, numeric) TO authenticated;

-- Realtime, so the web's alert list updates live (same as geofence alerts).
alter publication supabase_realtime add table public.fuel_anomalies;

-- Nightly at 09:00 UTC (early morning in US time zones): re-check the
-- last 14 days, then email admins what's new (send-fuel-alerts).
select cron.schedule(
  'fuel-anomalies-nightly',
  '0 9 * * *',
  $$
  select public.fn_reevaluate_recent_fuel_purchases();
  select net.http_post(
    url := 'https://zuujwmcftycmdaxesdya.supabase.co/functions/v1/send-fuel-alerts',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Sync-Secret', (select decrypted_secret from vault.decrypted_secrets where name = 'ifta_sync_shared_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
