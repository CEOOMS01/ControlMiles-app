-- Fleet Phase 6, piece 1: real US state boundary polygons for
-- point-in-polygon attribution of GPS breadcrumb points. Loaded server-side
-- from a public-source GeoJSON (PublicaMundi/MappingAPI, itself derived from
-- US Census TIGER data) via the `http` extension -- the actual coordinate
-- data never passes through application code or chat context, where a
-- single mistyped digit could silently corrupt a real geographic boundary.
create table public.ifta_us_state_boundaries (
  fips_code text primary key,
  state_code text not null unique,
  name text not null,
  geom geometry not null
);

create index ifta_us_state_boundaries_geom_idx on public.ifta_us_state_boundaries using gist (geom);

-- Read-only reference data -- every authenticated user can read it (needed
-- client-side for nothing today, but the mileage-attribution RPC runs as
-- the calling user, not a superuser, so it needs SELECT access itself).
alter table public.ifta_us_state_boundaries enable row level security;

create policy ifta_us_state_boundaries_select
on public.ifta_us_state_boundaries
for select
using (true);

-- FIPS -> USPS postal code. Fixed, well-known, 50-state + DC mapping (not
-- geographic coordinate data, so hand-written here is safe unlike the
-- boundary polygons themselves).
create temporary table _fips_postal (fips text, code text) on commit drop;
insert into _fips_postal (fips, code) values
  ('01','AL'),('02','AK'),('04','AZ'),('05','AR'),('06','CA'),('08','CO'),
  ('09','CT'),('10','DE'),('11','DC'),('12','FL'),('13','GA'),('15','HI'),
  ('16','ID'),('17','IL'),('18','IN'),('19','IA'),('20','KS'),('21','KY'),
  ('22','LA'),('23','ME'),('24','MD'),('25','MA'),('26','MI'),('27','MN'),
  ('28','MS'),('29','MO'),('30','MT'),('31','NE'),('32','NV'),('33','NH'),
  ('34','NJ'),('35','NM'),('36','NY'),('37','NC'),('38','ND'),('39','OH'),
  ('40','OK'),('41','OR'),('42','PA'),('44','RI'),('45','SC'),('46','SD'),
  ('47','TN'),('48','TX'),('49','UT'),('50','VT'),('51','VA'),('53','WA'),
  ('54','WV'),('55','WI'),('56','WY');

do $$
declare
  v_resp http_response;
  v_geojson jsonb;
  v_feature jsonb;
  v_count int := 0;
begin
  v_resp := http_get('https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json');
  if v_resp.status != 200 then
    raise exception 'Failed to fetch state boundaries: HTTP %', v_resp.status;
  end if;

  v_geojson := v_resp.content::jsonb;

  for v_feature in select * from jsonb_array_elements(v_geojson->'features')
  loop
    insert into public.ifta_us_state_boundaries (fips_code, state_code, name, geom)
    select
      v_feature->>'id',
      p.code,
      v_feature->'properties'->>'name',
      ST_SetSRID(ST_GeomFromGeoJSON(v_feature->'geometry'), 4326)
    from _fips_postal p
    where p.fips = v_feature->>'id'
    on conflict (fips_code) do nothing;
    v_count := v_count + 1;
  end loop;

  raise notice 'Processed % features', v_count;
end $$;
