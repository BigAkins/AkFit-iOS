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
//   1. Supabase Edge Runtime verifies the caller JWT before invocation.
//   2. The function also resolves the Authorization header JWT to a user.
//   3. Apple-backed users must provide a fresh Apple authorization code.
//   4. The function exchanges/revokes that Apple grant before deletion.
//   5. The service-role key exists only in this server-side function and is
//      never exposed to the iOS client.
// =============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2.108.2'

const responseHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
}

export type SupabaseUser = {
  id: string
  app_metadata?: Record<string, unknown>
  identities?: Array<{ provider?: string }>
}

type SupabaseAuthClient = {
  auth: {
    getUser: () => Promise<{
      data: { user: SupabaseUser | null }
      error: { message?: string } | null
    }>
  }
}

type SupabaseAdminClient = {
  auth: {
    admin: {
      deleteUser: (id: string) => Promise<{ error: { message?: string } | null }>
    }
  }
}

type AppleClientSecretConfig = {
  teamId: string
  clientId: string
  keyId: string
  privateKey: string
}

export type DeleteAccountDependencies = {
  env: (name: string) => string | undefined
  fetch: typeof fetch
  createUserClient: (
    supabaseURL: string,
    anonKey: string,
    authHeader: string
  ) => SupabaseAuthClient
  createAdminClient: (
    supabaseURL: string,
    serviceRoleKey: string
  ) => SupabaseAdminClient
  createAppleClientSecret: (
    config: AppleClientSecretConfig
  ) => Promise<string>
}

const defaultDependencies: DeleteAccountDependencies = {
  env: (name) => Deno.env.get(name),
  fetch,
  createUserClient: (supabaseURL, anonKey, authHeader) =>
    createClient(
      supabaseURL,
      anonKey,
      { global: { headers: { Authorization: authHeader } } }
    ) as unknown as SupabaseAuthClient,
  createAdminClient: (supabaseURL, serviceRoleKey) =>
    createClient(supabaseURL, serviceRoleKey) as unknown as SupabaseAdminClient,
  createAppleClientSecret,
}

export function createDeleteAccountHandler(
  deps: DeleteAccountDependencies = defaultDependencies
): (req: Request) => Promise<Response> {
  return async (req: Request) => {
    const debug = deps.env('AKFIT_FUNCTION_DEBUG') === '1'

    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: responseHeaders })
    }

    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed' }, 405)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      console.error('delete-account: missing bearer authorization')
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    const supabaseURL = deps.env('SUPABASE_URL') ?? ''
    const anonKey = deps.env('SUPABASE_ANON_KEY') ?? ''
    const serviceRoleKey = deps.env('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseURL || !anonKey || !serviceRoleKey) {
      console.error(
        `delete-account: missing env config url=${Boolean(supabaseURL)} anon=${Boolean(anonKey)} service=${Boolean(serviceRoleKey)}`
      )
      return jsonResponse({ error: 'Account deletion failed. Please try again.' }, 500)
    }

    if (debug) {
      console.log('delete-account: request received')
    }

    const supabaseClient = deps.createUserClient(supabaseURL, anonKey, authHeader)
    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser()

    if (authError || !user) {
      console.error(
        `delete-account: auth.getUser failed hasError=${Boolean(authError)} missingUser=${!user}`
      )
      return jsonResponse({ error: 'Unauthorized' }, 401)
    }

    if (debug) {
      console.log('delete-account: authenticated Supabase user resolved')
    }

    if (hasAppleProvider(user)) {
      const body = await parseDeleteAccountRequest(req)
      const appleAuthorizationCode = body.appleAuthorizationCode?.trim()
      if (!appleAuthorizationCode) {
        console.error('delete-account: missing apple authorization code')
        return jsonResponse(
          { error: 'Apple confirmation is required before deleting this account.' },
          400
        )
      }

      const revoked = await revokeAppleGrant(appleAuthorizationCode, deps)
      if (!revoked) {
        return jsonResponse(
          { error: 'Apple confirmation failed. Please try again.' },
          502
        )
      }
    }

    const adminClient = deps.createAdminClient(supabaseURL, serviceRoleKey)
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id)

    if (deleteError) {
      console.error('delete-account: deleteUser failed for authenticated user')
      return jsonResponse(
        { error: 'Account deletion failed. Please try again.' },
        500
      )
    }

    console.log('delete-account: successfully deleted authenticated user')
    return jsonResponse({ success: true }, 200)
  }
}

type DeleteAccountRequestBody = {
  appleAuthorizationCode?: string
}

async function parseDeleteAccountRequest(req: Request): Promise<DeleteAccountRequestBody> {
  try {
    const body = await req.json()
    if (!body || typeof body !== 'object') {
      return {}
    }
    const value = (body as Record<string, unknown>).appleAuthorizationCode
    return typeof value === 'string'
      ? { appleAuthorizationCode: value }
      : {}
  } catch {
    return {}
  }
}

export function hasAppleProvider(user: SupabaseUser): boolean {
  const identities = user.identities ?? []
  if (identities.some((identity) => equalsApple(identity.provider))) {
    return true
  }

  const metadata = user.app_metadata ?? {}
  if (equalsApple(metadata.provider)) {
    return true
  }

  const providers = metadata.providers
  return Array.isArray(providers) && providers.some(equalsApple)
}

function equalsApple(value: unknown): boolean {
  return typeof value === 'string' && value.toLowerCase() === 'apple'
}

async function revokeAppleGrant(
  authorizationCode: string,
  deps: DeleteAccountDependencies
): Promise<boolean> {
  const config = appleClientSecretConfig(deps)
  if (!config) {
    console.error('delete-account: missing apple revocation env config')
    return false
  }

  const clientSecret = await deps.createAppleClientSecret(config)
  const tokenBody = new URLSearchParams({
    client_id: config.clientId,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: 'authorization_code',
  })

  const tokenResponse = await deps.fetch('https://appleid.apple.com/auth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: tokenBody,
  })

  if (!tokenResponse.ok) {
    console.error(`delete-account: apple token exchange failed status=${tokenResponse.status}`)
    return false
  }

  const tokenPayload = await tokenResponse.json() as {
    access_token?: string
    refresh_token?: string
  }
  const tokenToRevoke = tokenPayload.refresh_token ?? tokenPayload.access_token
  const tokenTypeHint = tokenPayload.refresh_token ? 'refresh_token' : 'access_token'
  if (!tokenToRevoke) {
    console.error('delete-account: apple token exchange returned no revocable token')
    return false
  }

  const revokeBody = new URLSearchParams({
    client_id: config.clientId,
    client_secret: clientSecret,
    token: tokenToRevoke,
    token_type_hint: tokenTypeHint,
  })

  const revokeResponse = await deps.fetch('https://appleid.apple.com/auth/revoke', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: revokeBody,
  })

  if (!revokeResponse.ok) {
    console.error(`delete-account: apple token revoke failed status=${revokeResponse.status}`)
    return false
  }

  return true
}

function appleClientSecretConfig(
  deps: DeleteAccountDependencies
): AppleClientSecretConfig | null {
  const teamId = deps.env('APPLE_TEAM_ID') ?? ''
  const clientId = deps.env('APPLE_CLIENT_ID') ?? ''
  const keyId = deps.env('APPLE_KEY_ID') ?? ''
  const privateKey = normalizePrivateKey(deps.env('APPLE_PRIVATE_KEY') ?? '')

  if (!teamId || !clientId || !keyId || !privateKey) {
    return null
  }

  return { teamId, clientId, keyId, privateKey }
}

async function createAppleClientSecret(
  config: AppleClientSecretConfig
): Promise<string> {
  const now = Math.floor(Date.now() / 1_000)
  const header = { alg: 'ES256', kid: config.keyId }
  const claims = {
    iss: config.teamId,
    iat: now,
    exp: now + 300,
    aud: 'https://appleid.apple.com',
    sub: config.clientId,
  }
  const signingInput = `${base64URL(JSON.stringify(header))}.${base64URL(JSON.stringify(claims))}`
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(config.privateKey),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  )
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      { name: 'ECDSA', hash: 'SHA-256' },
      key,
      new TextEncoder().encode(signingInput)
    )
  )

  return `${signingInput}.${base64URL(signature)}`
}

function normalizePrivateKey(value: string): string {
  return value.replaceAll('\\n', '\n').trim()
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}

function base64URL(value: string | Uint8Array): string {
  const bytes = typeof value === 'string'
    ? new TextEncoder().encode(value)
    : value
  let binary = ''
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: responseHeaders,
  })
}
