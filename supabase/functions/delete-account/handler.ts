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
//   4. The function exchanges that Apple grant and verifies the linked Apple
//      identity before revocation/deletion.
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
  identities?: Array<{
    id?: string
    provider?: string
    identity_data?: Record<string, unknown>
    identityData?: Record<string, unknown>
  }>
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

      const linkedAppleSubject = appleIdentitySubject(user)
      if (!linkedAppleSubject) {
        console.error('delete-account: apple revocation failed reason=missing_linked_identity')
        return jsonResponse(
          { error: 'Apple confirmation failed. Please try again.' },
          502
        )
      }

      const revoked = await revokeAppleGrant(appleAuthorizationCode, linkedAppleSubject, deps)
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

function appleIdentitySubject(user: SupabaseUser): string | null {
  for (const identity of user.identities ?? []) {
    if (!equalsApple(identity.provider)) {
      continue
    }

    const identityData = identity.identity_data ?? identity.identityData
    const subject = nonEmptyString(identityData?.sub)
    if (subject) {
      return subject
    }

    const directId = nonEmptyString(identity.id)
    if (directId) {
      return directId
    }
  }

  return null
}

function equalsApple(value: unknown): boolean {
  return typeof value === 'string' && value.toLowerCase() === 'apple'
}

function nonEmptyString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null
  }

  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : null
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

async function revokeAppleGrant(
  authorizationCode: string,
  expectedAppleSubject: string,
  deps: DeleteAccountDependencies
): Promise<boolean> {
  const config = appleClientSecretConfig(deps)
  if (!config) {
    console.error('delete-account: apple revocation failed reason=missing_config')
    return false
  }

  try {
    let clientSecret: string
    try {
      clientSecret = await deps.createAppleClientSecret(config)
    } catch {
      console.error('delete-account: apple revocation failed reason=client_secret')
      return false
    }

    const tokenBody = new URLSearchParams({
      client_id: config.clientId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: 'authorization_code',
    })

    let tokenResponse: Response
    try {
      tokenResponse = await deps.fetch('https://appleid.apple.com/auth/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: tokenBody,
      })
    } catch {
      console.error('delete-account: apple revocation failed reason=token_fetch')
      return false
    }

    if (!tokenResponse.ok) {
      console.error(`delete-account: apple token exchange failed status=${tokenResponse.status}`)
      return false
    }

    let tokenPayload: Record<string, unknown>
    try {
      const tokenJSON = await tokenResponse.json()
      if (!isObject(tokenJSON)) {
        console.error('delete-account: apple revocation failed reason=token_json')
        return false
      }
      tokenPayload = tokenJSON
    } catch {
      console.error('delete-account: apple revocation failed reason=token_json')
      return false
    }

    const appleSubject = appleSubjectFromToken(tokenPayload.id_token, config.clientId)
    if (!appleSubject) {
      return false
    }

    if (appleSubject !== expectedAppleSubject) {
      console.error('delete-account: apple revocation failed reason=identity_mismatch')
      return false
    }

    const refreshToken = nonEmptyString(tokenPayload.refresh_token)
    const accessToken = nonEmptyString(tokenPayload.access_token)
    const tokenToRevoke = refreshToken ?? accessToken
    const tokenTypeHint = refreshToken ? 'refresh_token' : 'access_token'
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

    let revokeResponse: Response
    try {
      revokeResponse = await deps.fetch('https://appleid.apple.com/auth/revoke', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: revokeBody,
      })
    } catch {
      console.error('delete-account: apple revocation failed reason=revoke_fetch')
      return false
    }

    if (!revokeResponse.ok) {
      console.error(`delete-account: apple token revoke failed status=${revokeResponse.status}`)
      return false
    }

    return true
  } catch {
    console.error('delete-account: apple revocation failed reason=unexpected')
    return false
  }
}

function appleSubjectFromToken(idToken: unknown, expectedAudience: string): string | null {
  if (typeof idToken !== 'string') {
    console.error('delete-account: apple revocation failed reason=missing_id_token')
    return null
  }

  const payload = jwtPayload(idToken)
  if (!payload) {
    console.error('delete-account: apple revocation failed reason=invalid_id_token')
    return null
  }

  if (payload.iss !== 'https://appleid.apple.com') {
    console.error('delete-account: apple revocation failed reason=issuer_mismatch')
    return null
  }

  if (!audienceMatches(payload.aud, expectedAudience)) {
    console.error('delete-account: apple revocation failed reason=audience_mismatch')
    return null
  }

  const subject = nonEmptyString(payload.sub)
  if (!subject) {
    console.error('delete-account: apple revocation failed reason=missing_subject')
    return null
  }

  return subject
}

function jwtPayload(token: string): Record<string, unknown> | null {
  const parts = token.split('.')
  if (parts.length !== 3) {
    return null
  }

  const payloadText = base64URLDecodeToString(parts[1])
  if (!payloadText) {
    return null
  }

  try {
    const payload = JSON.parse(payloadText)
    return isObject(payload) ? payload : null
  } catch {
    return null
  }
}

function audienceMatches(audience: unknown, expectedAudience: string): boolean {
  if (typeof audience === 'string') {
    return audience === expectedAudience
  }

  return Array.isArray(audience) && audience.some((value) => value === expectedAudience)
}

function base64URLDecodeToString(value: string): string | null {
  if (value.length % 4 === 1) {
    return null
  }

  const base64 = value.replaceAll('-', '+').replaceAll('_', '/')
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=')

  try {
    const binary = atob(padded)
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0))
    return new TextDecoder().decode(bytes)
  } catch {
    return null
  }
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
