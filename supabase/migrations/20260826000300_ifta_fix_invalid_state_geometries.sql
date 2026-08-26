-- 3 of 51 boundaries (AK, MD, VA) had self-intersecting rings from the
-- source data (complex coastlines -- Chesapeake Bay, Alaska's islands).
-- ST_MakeValid repairs them without changing the boundary's real shape
-- meaningfully; left unfixed, ST_Contains/ST_Within can throw or silently
-- misbehave on an invalid geometry.
update public.ifta_us_state_boundaries
set geom = ST_MakeValid(geom)
where not ST_IsValid(geom);
