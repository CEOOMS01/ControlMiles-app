-- Fleet Phase 6 (IFTA, piece 1: miles-per-state). Needed for point-in-polygon
-- attribution of GPS breadcrumb points to US states. `http` lets the
-- boundary-loading migration fetch real Census boundary data server-side
-- rather than embedding tens of thousands of coordinate values through
-- application code/chat context, where a single mistyped digit would
-- silently corrupt a real geographic boundary.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS http;
