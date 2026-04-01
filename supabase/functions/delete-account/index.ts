// =============================================================================
// Edge Function: delete-account
// Triggered by: POST /functions/v1/delete-account
//
// Permanently deletes the calling user's account from Supabase Auth.
// All user-owned rows are removed automatically via ON DELETE CASCADE:
//   public.profiles, public.user_goals (goals), public.food_logs,
//   public.bodyweight_logs, public.favorite_foods, public.daily_notes,
//   public.grocery_items
//
// Security model:
//   1. Caller must supply a valid Supabase JWT in the Authorization header.
//   2. The anon-key client resolves the JWT → user identity.
//   3. The service-role admin client performs the deletion (bypasses RLS).
//      The service-role key exists only in this server-side function and is
//      never exposed to the iOS client.
//
// Sign in with Apple:
//   Full Apple ID token revocation (POST to https://appleid.apple.com/auth/revoke)
//   requires an Apple private key to sign a client_secret JWT. That key is
//   not available in this function. The account and all user data are
//   permanently deleted here; the Apple token becomes orphaned and will not
//   grant access to any AkFit resource. Revocation can be added post-launch.
// =============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  // CORS preflight — included for completeness; iOS clients don't require it.
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers':
          'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  // ── 1. Authenticate the caller ────────────────────────────────────────────

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401)
  }

  // Resolve the JWT to a Supabase user using the anon-key client.
  // This is the canonical pattern for authenticating Edge Function callers.
  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } }
  )
  const {
    data: { user },
    error: authError,
  } = await supabaseClient.auth.getUser()

  if (authError || !user) {
    return jsonResponse({ error: 'Unauthorized' }, 401)
  }

  // ── 2. Delete the user via the admin (service-role) client ────────────────

  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id)

  if (deleteError) {
    // Log server-side only — never expose internal Supabase error details to
    // the client.
    console.error(
      `delete-account: deleteUser failed for ${user.id}: ${deleteError.message}`
    )
    return jsonResponse(
      { error: 'Account deletion failed. Please try again.' },
      500
    )
  }

  console.log(`delete-account: successfully deleted user ${user.id}`)
  return jsonResponse({ success: true }, 200)
})

// ── Helpers ──────────────────────────────────────────────────────────────────

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
