// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/check-email-exists/index.ts
//
// RETIRED (2026-10-22, owner's rule: a public screen must never reveal
// which emails or IDs have an account). This used to tell the "forgot
// password" screen whether an email had an account, which let anyone
// harvest real accounts. The apps no longer call it; builds already
// installed still do, so it stays deployed but no longer looks anything
// up: it always answers "exists", and those builds go on to Supabase's
// own resetPasswordForEmail, which answers the same either way and only
// sends a code to a real account. Delete it once no installed build calls
// it.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve((req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return new Response(JSON.stringify({ exists: true }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
