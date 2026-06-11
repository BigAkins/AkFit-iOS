# Onboarding Save Flow

How the final onboarding step ("Start tracking") persists the user's profile
and goal, what happens when it partially fails, and how recovery works.

Code: `AkFit/AkFit/Views/Onboarding/OnboardingView.swift` (`ResultsStepView.save()`),
`AkFit/Services/Supabase/ProfileService.swift`, `GoalService.swift`,
`AkFit/AkFit/Auth/AuthManager.swift` (`requireAuthenticatedUserIDForWrite`).

## Sequence (authenticated path)

```text
Start tracking tap
  │
  ├─ 1. requireAuthenticatedUserIDForWrite()
  │      AuthManager resolves a valid session via auth.session
  │      (auto-refreshes an expired token; 2 attempts, 350ms apart).
  │      Returns session.user.id — the ONLY user id used for the writes.
  │
  ├─ 2. ProfileService.upsert  →  POST /rest/v1/profiles (on_conflict=id)
  │      Writes display_name, height_cm, weight_kg, birthdate, sex,
  │      activity_level, updated_at. IDEMPOTENT — safe to repeat.
  │
  ├─ 3. GoalService.insert     →  POST /rest/v1/goals
  │      Writes user_id, goal_type, target_pace (nil for maintenance),
  │      daily_calories/protein/carbs/fat. Creates a NEW row each time
  │      (goal history by design; fetchActiveGoal reads newest by created_at).
  │
  └─ 4. authManager.markOnboarded(goal:profile:)
         Sets in-memory state → isOnboarded == true → RootView routes to
         MainTabView. No extra network round-trip.
```

Guest path: steps 1–3 are replaced by local `GuestDataStore` writes (UserDefaults).
No Supabase calls are made.

## Partial-failure matrix

The two writes are **not atomic**. This is intentional and safe:

| Failure point | DB state afterwards | What the user sees | Recovery |
|---|---|---|---|
| Session resolution (step 1) | nothing written | "Session expired…" (fatal session failures also auto-sign-out via the SDK → AuthView) | Sign in again; onboarding restarts |
| Profile upsert (step 2) | nothing written | classified error message | Retry on the same screen |
| Goal insert (step 3) | **profile row exists, no goal** | classified error message | Retry re-upserts the profile (idempotent no-op) and re-attempts the insert |
| Decode of returned row | row IS written | error message despite saved data | Next app launch fetches the saved rows; if both exist the user routes straight to the dashboard |

Key invariant: **`isOnboarded` is driven solely by the existence of a goal
row.** A user with a profile but no goal re-enters onboarding on next launch —
they are never stranded half-onboarded on the dashboard.

## Error classification

All three save surfaces (onboarding results, EditGoalView, EditProfileView)
share `SaveErrorClassification` (`AkFit/Services/Supabase/SaveErrorClassification.swift`):

- `sessionExpired` → "Session expired. Please sign out and sign back in."
- `nonRetryable` (23502/23503/23514/42501/PGRST204) → "…server problem. Please
  update to the latest version of AkFit, or contact support…" — **never** "try
  again", because retrying a deterministic server reject cannot succeed
- `retryable` (everything else) → "…check your connection and try again."

Unit tests: `AkFitTests/SaveErrorClassificationTests.swift`.

## Observability

On failure the results step:

1. Logs a structured line via os.log (subsystem = bundle id, category
   `Onboarding`): `step`, `table`, `action`, `session_validated`,
   `classification`, `postgrest_code`, `auth_code` — all `privacy: .public`
   (codes only, no PII). Filter in Console.app by category `Onboarding`.
2. Captures the error to Sentry via `SentryMonitoring.captureNonFatal`
   (operation `onboarding_save`, same fields as tags).

See `docs/debugging-supabase-errors.md` for the code → cause → next-step map.

## The 2026-06 incident (why this doc exists)

From launch until 2026-06-11, the live `goals_goal_type_check` constraint only
allowed `'muscle_gain'` (legacy hand-created table) while the app sends
`'lean_bulk'`. Every Lean Bulk user failed at step 3 with 23514 — profile
saved, goal rejected, "Please try again" shown, retry failed identically.
10 of 54 users were stuck in that state; none recovered. Fixed by migration
`20260611054748_fix_goals_goal_type_check`. Guards added since:

- `supabase/tests/database/goals_constraint_shape.test.sql` (CI)
- `GoalTypeDatabaseContractTests` (app-side raw-value tripwire)
- the drift-check procedure in `supabase/README.md`
- non-retryable error copy + Sentry capture (this flow)
