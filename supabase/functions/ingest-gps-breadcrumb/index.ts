// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/ingest-gps-breadcrumb/index.ts
//
// Live trip-route drawing (explicit user request, 2026-09-20): "que se
// vea en vivo el dibujo del viaje... esta imagen vivirá solo en el
// reporte web" -- and, on how to extend GPS-trail capture from
// Fleet-only to every driver: "lo que haremos es lanzar un servidor, que
// es el que recibirá estas coordenadas limpias y de allí se enviará a
// Supabase para no forzar la base de datos". This function IS that
// server: tracking_controller.dart now calls it instead of inserting
// into session_gps_breadcrumbs directly.
//
// Two things this buys over a direct client insert:
//   1. Identity is never trusted from the request body. The caller's
//      JWT is verified server-side (userClient.auth.getUser()) and
//      organization_id/vehicle_id are looked up from the session row
//      itself (RLS-scoped to that same caller) rather than accepted as
//      client-supplied fields -- a modified client can't stuff a
//      breadcrumb into someone else's session or a different org.
//   2. "Coordenadas limpias": basic validity gating before a row is ever
//      written -- finite numbers, real lat/lng ranges, not (0,0) (the
//      classic "GPS fix failed" null-island sentinel some devices emit).
//      This is intentionally NOT full smoothing/deduplication (no
//      Kalman filter, no distance-based dedup) -- the client already
//      throttles to one call per 60s per active trip, so volume is
//      already low; heavier cleaning can be layered in later without
//      changing the contract this function exposes.
//
// Writes with the service-role key (bypasses RLS by design, same as
// every other service-role write in this project) -- the RLS policies
// on session_gps_breadcrumbs are kept correct anyway for defense in
// depth, not because this function depends on them.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

// Generous relative to the client's own 60s-per-trip throttle
// (tracking_controller.dart's _lastBreadcrumbTime gate) -- this only
// needs to catch a genuinely misbehaving/modified client, not shape
// normal traffic.
const RATE_LIMIT_MAX = 20;
const RATE_LIMIT_WINDOW_SECONDS = 60;

async function isRateLimited(
  serviceClient: ReturnType<typeof createClient>,
  clientId: string,
): Promise<boolean> {
  // SECURITY: check_rate_limit is EXECUTE-revoked from anon/authenticated
  // (see 20260828100000_create_edge_function_rate_limiter.sql) -- only
  // callable with the service-role key, which never leaves this function.
  const { data, error } = await serviceClient.rpc('check_rate_limit', {
    p_fn_name: 'ingest-gps-breadcrumb',
    p_client_key: clientId,
    p_max_requests: RATE_LIMIT_MAX,
    p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
  });
  if (error) {
    // Fails open, same discipline as every other guard in this project's
    // edge functions -- a broken rate-limit check must never drop a real
    // trip's GPS point.
    console.warn('[ingest-gps-breadcrumb] rate limit check failed (failing open):', error);
    return false;
  }
  return !data;
}

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

interface BreadcrumbBody {
  session_id: string;
  section_id?: string | null;
  latitude: number;
  longitude: number;
  recorded_at: string;
}

function isValidCoordinate(lat: unknown, lng: unknown): lat is number {
  if (typeof lat !== 'number' || typeof lng !== 'number') return false;
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  // (0,0) is open ocean off West Africa, not anywhere a real trip
  // happens -- devices emit it as a "no fix yet" sentinel far more often
  // than a genuine reading, same reasoning AntifraudEngine already
  // applies to raw GPS ticks client-side.
  if (lat === 0 && lng === 0) return false;
  return true;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return respond({ accepted: false, reason: 'Missing Authorization header' }, 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const serviceClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return respond({ accepted: false, reason: 'Invalid or expired session' }, 401);
    }
    const userId = userData.user.id;

    if (await isRateLimited(serviceClient, userId)) {
      return respond({ accepted: false, reason: 'rate_limited' }, 429);
    }

    let body: BreadcrumbBody;
    try {
      body = await req.json();
    } catch {
      return respond({ accepted: false, reason: 'Invalid JSON body' }, 400);
    }

    if (!body.session_id || typeof body.session_id !== 'string') {
      return respond({ accepted: false, reason: 'Missing required field: session_id' }, 400);
    }
    if (!body.recorded_at || typeof body.recorded_at !== 'string') {
      return respond({ accepted: false, reason: 'Missing required field: recorded_at' }, 400);
    }
    if (!isValidCoordinate(body.latitude, body.longitude)) {
      // Not an error the caller needs to retry or log loudly -- an
      // occasional bad fix is normal GPS noise, silently dropped exactly
      // like a rejected tick already is client-side.
      return respond({ accepted: false, reason: 'invalid_coordinate' }, 200);
    }

    // Ownership + org/vehicle lookup in one query, scoped by the CALLER's
    // own RLS (sessions_select_own or equivalent) -- if this returns
    // nothing, either the session doesn't exist or it isn't this user's,
    // and either way nothing gets written.
    const { data: session, error: sessionError } = await userClient
      .from('sessions')
      .select('id, organization_id, vehicle_id')
      .eq('id', body.session_id)
      .eq('user_id', userId)
      .maybeSingle();

    if (sessionError || !session) {
      return respond({ accepted: false, reason: 'Session not found or not yours' }, 404);
    }

    const { error: insertError } = await serviceClient
      .from('session_gps_breadcrumbs')
      .insert({
        session_id: session.id,
        section_id: body.section_id ?? null,
        organization_id: session.organization_id,
        vehicle_id: session.vehicle_id,
        user_id: userId,
        latitude: body.latitude,
        longitude: body.longitude,
        recorded_at: body.recorded_at,
      });

    if (insertError) {
      console.error('[ingest-gps-breadcrumb] insert error:', insertError);
      return respond({ accepted: false, reason: 'insert_failed' }, 500);
    }

    return respond({ accepted: true }, 200);
  } catch (err: any) {
    console.error('[ingest-gps-breadcrumb] Unexpected error:', err);
    // Swallow -- a broken breadcrumb pipe must never surface as an error
    // to the caller mid-trip (same discipline tracking_controller.dart's
    // own try/catch around this call already applies).
    return respond({ accepted: false, reason: err?.message ?? 'unknown error' }, 200);
  }
});
