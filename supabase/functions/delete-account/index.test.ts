import {
  createDeleteAccountHandler,
  type DeleteAccountDependencies,
  type SupabaseUser,
} from './handler.ts'

Deno.test('rejects unauthenticated requests before deleting anything', async () => {
  const { deps, deletedUserIds } = makeDeps({
    user: nonAppleUser('user-1'),
  })
  const handler = createDeleteAccountHandler(deps)

  const response = await handler(new Request('https://example.test/delete-account', {
    method: 'POST',
  }))

  assertEquals(response.status, 401)
  assertEquals(deletedUserIds, [])
})

Deno.test('deletes non-Apple authenticated users without Apple authorization code', async () => {
  const { deps, deletedUserIds, appleCalls } = makeDeps({
    user: nonAppleUser('user-1'),
  })
  const handler = createDeleteAccountHandler(deps)

  const response = await handler(authenticatedRequest({}))

  assertEquals(response.status, 200)
  assertEquals(deletedUserIds, ['user-1'])
  assertEquals(appleCalls.length, 0)
})

Deno.test('requires Apple authorization code before deleting Apple users', async () => {
  const { deps, deletedUserIds } = makeDeps({
    user: appleUser('apple-user'),
  })
  const handler = createDeleteAccountHandler(deps)

  const response = await handler(authenticatedRequest({}))

  assertEquals(response.status, 400)
  assertEquals(deletedUserIds, [])
})

Deno.test('revokes Apple grant before deleting Apple users', async () => {
  const { deps, deletedUserIds, appleCalls } = makeDeps({
    user: appleUser('apple-user'),
    appleResponses: [
      jsonResponse({ refresh_token: 'apple-refresh-token' }, 200),
      new Response('', { status: 200 }),
    ],
  })
  const handler = createDeleteAccountHandler(deps)

  const response = await handler(authenticatedRequest({
    appleAuthorizationCode: 'apple-code',
  }))

  assertEquals(response.status, 200)
  assertEquals(deletedUserIds, ['apple-user'])
  assertEquals(appleCalls.map((call) => call.url), [
    'https://appleid.apple.com/auth/token',
    'https://appleid.apple.com/auth/revoke',
  ])
  assertEquals(appleCalls[0].body.includes('code=apple-code'), true)
  assertEquals(appleCalls[1].body.includes('token=apple-refresh-token'), true)
})

Deno.test('does not delete Apple users when Apple revocation fails', async () => {
  const { deps, deletedUserIds } = makeDeps({
    user: appleUser('apple-user'),
    appleResponses: [
      jsonResponse({ refresh_token: 'apple-refresh-token' }, 200),
      jsonResponse({ error: 'invalid_token' }, 400),
    ],
  })
  const handler = createDeleteAccountHandler(deps)

  const response = await handler(authenticatedRequest({
    appleAuthorizationCode: 'apple-code',
  }))

  assertEquals(response.status, 502)
  assertEquals(deletedUserIds, [])
})

Deno.test('deletes only the authenticated Supabase user', async () => {
  const { deps, deletedUserIds } = makeDeps({
    user: nonAppleUser('authenticated-user'),
  })
  const handler = createDeleteAccountHandler(deps)

  const response = await handler(authenticatedRequest({
    userId: 'attacker-controlled-id',
  }))

  assertEquals(response.status, 200)
  assertEquals(deletedUserIds, ['authenticated-user'])
})

Deno.test('returns unauthorized when Supabase rejects the JWT', async () => {
  const { deps, deletedUserIds } = makeDeps({
    user: null,
    authError: { message: 'JWT expired' },
  })
  const handler = createDeleteAccountHandler(deps)

  const response = await handler(authenticatedRequest({}))

  assertEquals(response.status, 401)
  assertEquals(deletedUserIds, [])
})

function authenticatedRequest(body: Record<string, unknown>): Request {
  return new Request('https://example.test/delete-account', {
    method: 'POST',
    headers: {
      Authorization: 'Bearer user-jwt',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })
}

function nonAppleUser(id: string): SupabaseUser {
  return {
    id,
    app_metadata: { provider: 'email', providers: ['email'] },
    identities: [{ provider: 'email' }],
  }
}

function appleUser(id: string): SupabaseUser {
  return {
    id,
    app_metadata: { provider: 'apple', providers: ['apple'] },
    identities: [{ provider: 'apple' }],
  }
}

function makeDeps(options: {
  user: SupabaseUser | null
  authError?: { message: string } | null
  appleResponses?: Response[]
}): {
  deps: DeleteAccountDependencies
  deletedUserIds: string[]
  appleCalls: Array<{ url: string; body: string }>
} {
  const deletedUserIds: string[] = []
  const appleCalls: Array<{ url: string; body: string }> = []
  const appleResponses = [...(options.appleResponses ?? [])]

  const deps: DeleteAccountDependencies = {
    env: (name) => ({
      SUPABASE_URL: 'https://project.supabase.co',
      SUPABASE_ANON_KEY: 'anon-key',
      SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
      APPLE_TEAM_ID: 'TEAMID1234',
      APPLE_CLIENT_ID: 'ai.talktoem.AkFit',
      APPLE_KEY_ID: 'KEYID1234',
      APPLE_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\\ntest\\n-----END PRIVATE KEY-----',
    })[name],
    fetch: async (input, init) => {
      appleCalls.push({
        url: String(input),
        body: String(init?.body ?? ''),
      })
      return appleResponses.shift() ?? jsonResponse({}, 500)
    },
    createUserClient: () => ({
      auth: {
        getUser: async () => ({
          data: { user: options.user },
          error: options.authError ?? null,
        }),
      },
    }),
    createAdminClient: () => ({
      auth: {
        admin: {
          deleteUser: async (id) => {
            deletedUserIds.push(id)
            return { error: null }
          },
        },
      },
    }),
    createAppleClientSecret: async () => 'apple-client-secret',
  }

  return { deps, deletedUserIds, appleCalls }
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function assertEquals<T>(actual: T, expected: T) {
  const actualJSON = JSON.stringify(actual)
  const expectedJSON = JSON.stringify(expected)
  if (actualJSON !== expectedJSON) {
    throw new Error(`Expected ${expectedJSON}, got ${actualJSON}`)
  }
}
