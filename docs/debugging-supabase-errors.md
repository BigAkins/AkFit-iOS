# Debugging Supabase Errors in AkFit

Map from the error codes AkFit logs (os.log `classification` /
`postgrest_code` / `auth_code` fields, Sentry `akfit.*` tags) to their likely
cause and the next diagnostic step.

## Where to look first

1. **Sentry** (`talktoem` org): non-fatal events tagged `akfit.operation`
   (`onboarding_save`, `edit_goal_save`, `edit_profile_save`, `quick_log`,
   `user_data_fetch`, `delete_account`) with `akfit.classification` and
   `akfit.postgrest_code` tags, plus release attribution.
2. **Console.app / Xcode console**: os.log categories `Onboarding`; DEBUG
   builds also print `[OnboardingSave]`, `[AuthWrite]`, `[DeleteAccount]`.
3. **Supabase dashboard → Logs → API**: filter non-2xx; the request path tells
   you the table.

## PostgREST / Postgres codes

| Code | Meaning | First suspect in AkFit | Next step |
|---|---|---|---|
| `23514` | check_violation | **Live-vs-migration constraint drift** (the 2026-06 `lean_bulk` incident) or an app payload outside the allowed set | Run the drift check in `supabase/README.md` → compare `pg_get_constraintdef` against the migration files |
| `42501` | insufficient_privilege (RLS denial) | A write verb with no policy — note `food_logs` and `bodyweight_logs` intentionally have **no UPDATE policy**; an `.update()` on them is a bug | Dump `pg_policies` for the table; check the app sends the session user's id |
| `23502` | not_null_violation | Payload omitted a NOT NULL column (encoder drops nil optionals) | Compare the Encodable payload struct against live `information_schema.columns.is_nullable` |
| `23503` | foreign_key_violation | `user_id` not present in `auth.users` (deleted account writing from a stale session) | Check whether the user still exists; expect auto-signout soon after |
| `23505` | unique_violation | `favorite_foods (user_id, food_name, serving_label)` or `daily_notes (user_id, note_date)` duplicates | Usually benign double-submit; check in-flight guards |
| `PGRST116` | zero/multiple rows where one expected (`.single()`) | Fetch found no row (treated as not-found in `AuthManager`) — or an UPDATE matched 0 rows (stale id, RLS filter) | Verify the row exists and the `eq` filters |
| `PGRST204` | column not in schema cache | App payload references a column the DB doesn't have (schema drift / unapplied migration) | `supabase migration list --linked`; apply pending migrations |
| `PGRST301` | JWT invalid/expired at PostgREST | Token expired mid-flight; classified as session-expired | The SDK refresh normally handles it; persistent → check device clock skew |

## Auth (GoTrue) failures

| Symptom | Meaning | Next step |
|---|---|---|
| `auth_session_missing` | No session when a write demanded one (`requireAuthenticatedUserIDForWrite` with `userState != .authenticated`) | Routing bug or guest-path leak — check `userState` transitions |
| `auth_api_error` + 401, codes `invalid_jwt`/`bad_jwt` | Server rejected the JWT | Device clock skew, or key rotation on the project |
| `refresh_token_already_used` / `session_not_found` in SDK logs | Fatal refresh failure | supabase-swift destroys the session and emits `.signedOut` → user lands on AuthView; expected recovery, no action |
| 401 on `/auth/v1/token` in API logs | Refresh token revoked/rotated | Check Auth → Sessions in the dashboard; user must sign in again |

## 401/403 quick triage

- **401 on `/rest/v1/*`**: expired/invalid JWT → PGRST301 path above.
- **403 / `42501` with a valid session**: RLS denial — the verb has no policy
  or `auth.uid()` ≠ the row's `user_id`/`id`. Dump policies:
  ```sql
  select tablename, policyname, cmd, qual, with_check
  from pg_policies where schemaname = 'public' and tablename = '<table>';
  ```
- **Failure that retries can't fix and local testing can't reproduce**:
  assume schema drift until proven otherwise — run the drift check in
  `supabase/README.md`.
