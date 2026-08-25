// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/delete-account/index.ts
//
// Primera Edge Function del proyecto (pedido explícito: account deletion).
// Borrar un usuario de auth.users es una operación admin-only -- el cliente
// Flutter jamás puede hacerlo directo con el anon key, así que esta función
// corre server-side con la service role key (que nunca se expone al app).
//
// Verificado en DB antes de escribir esto (pg_constraint sobre
// confrelid = profiles/auth.users): profiles.id -> auth.users(id) ON
// DELETE CASCADE, y desde profiles todo lo demás (vehicles, sessions,
// session_sections, audit_events, vehicle_maintenance_records, reports,
// organization_members, user_onboarding) también es ON DELETE CASCADE.
// Borrar auth.users limpia TODO solo -- no hace falta borrar tabla por
// tabla acá.
//
// Excepción conocida: reports.generated_by -> profiles(id) NO tiene
// ON DELETE explícito (default RESTRICT). Si esta cuenta generó un
// reporte que quedó asociado a OTRO usuario (caso org/bookkeeper), el
// delete puede fallar con foreign_key_violation. Se captura abajo y se
// devuelve un mensaje claro en vez de un 500 críptico.
//
// Seguridad: el user_id a borrar NUNCA se lee del body de la request --
// se deriva del JWT verificado en el header Authorization. Así un
// usuario solo puede borrarse a sí mismo, nunca a otro.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Cliente "de usuario": usa el JWT que vino en el header para saber
    // quién está llamando. El user_id sale de acá, nunca del body.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired session' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const userId = userData.user.id;

    // Cliente admin: única forma de borrar de auth.users. La service
    // role key vive solo acá (env var inyectada por Supabase), jamás en
    // el cliente Flutter.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId);

    if (deleteError) {
      console.error('[delete-account] deleteUser failed:', deleteError);
      const isFkViolation = deleteError.message?.toLowerCase().includes('foreign key');
      return new Response(
        JSON.stringify({
          error: isFkViolation
            ? 'This account has records shared with another user (e.g. a team/org report) and could not be deleted automatically. Contact support.'
            : deleteError.message,
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('[delete-account] Unexpected error:', e);
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
