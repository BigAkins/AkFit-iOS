# AkFit Release Checklist

Operational sequence for shipping an App Store build. Principles live in
`CLAUDE.md` (App Store / release rules); this is the step-by-step list.

## 1. Pre-flight (before bumping anything)

- [ ] `main` is green in CI (`.github/workflows/ci.yml` — unit tests + Supabase
      RLS/constraint tests)
- [ ] **Supabase drift check** (see `supabase/README.md` → "Verifying live
      schema matches migrations"):
  - [ ] `supabase migration list --linked` — every local migration applied
        remotely, no remote-only orphans
  - [ ] `supabase db diff --linked` — no unexpected live objects
  - [ ] CHECK-constraint dump matches the migration files (especially
        `goals_goal_type_check`)
- [ ] Any migration the new binary depends on is **pushed to prod before the
      binary ships** (the app has no schema-version negotiation)
- [ ] Supabase Security Advisors reviewed (dashboard → Advisors)

## 2. Version bump

- [ ] Bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION` for each upload)
      in `AkFit/AkFit.xcodeproj` — both live in build settings, one place each
- [ ] Commit on a release branch (`Ak/app-store-update-x-y-z` pattern)

## 3. Archive & upload

- [ ] Xcode → Product → Archive (Any iOS Device, Release config)
- [ ] Organizer → Distribute → App Store Connect → Upload
- [ ] Confirm the build appears in App Store Connect → TestFlight

## 4. Manual smoke test (TestFlight build, real device when possible)

Core loop:
- [ ] Fresh install → onboarding end-to-end → **"Start tracking" saves**
      (test all three goal types — fat loss, maintenance, **lean bulk**)
- [ ] Dashboard loads targets; calories/macros render
- [ ] Food search → log a food → totals update
- [ ] Swipe quick-log from Recents/Favorites (and once in airplane mode —
      expect the "Couldn't log food" alert, not silence)
- [ ] Water quick-add; bodyweight log

Auth:
- [ ] Sign in with Apple — new account AND returning account (Apple omits
      name/email on return; must not block)
- [ ] Email sign-up / sign-in; sign out
- [ ] Kill + relaunch → session persists, routes straight to dashboard

Settings:
- [ ] Edit targets (switch goal type, incl. to Lean Bulk) → saves
- [ ] Edit profile (body stats) → macros recalculate
- [ ] HealthKit Connect on a device without a prior grant — no crash
- [ ] Delete account → confirm → routed to auth screen; re-sign-in creates a
      clean slate

Appearance:
- [ ] Dark mode pass over dashboard, search, onboarding
- [ ] iPad layout sanity check if the change touched shared views

## 5. Submission

- [ ] Release notes / "what to test" via the `akfit-write-release-notes` skill
- [ ] Submit for review; answer App Review messages from the reviewer-response
      playbook (minimal, factual, screenshots)

## 6. Post-release monitoring (first 48h)

- [ ] Sentry (`talktoem` org): new crash signatures, and non-fatal
      `akfit.operation` events (`onboarding_save` failures = highest priority)
- [ ] Supabase dashboard → Logs → API: non-2xx rate on `/rest/v1/goals`,
      `/rest/v1/profiles`
- [ ] Quick SQL health check (read-only):
  ```sql
  -- Users stuck mid-onboarding (profile but no goal) — should not grow:
  select count(*) from public.profiles p
  where not exists (select 1 from public.goals g where g.user_id = p.id);
  ```
