# AkFit Codebase Audit — Security, Stability & Scalability

**Date:** 2026-06-11 · **Branch:** `audit/codebase-security-stability` · **Phase:** audit-only (no fixes implemented)
**Method:** 8-domain parallel deep audit (architecture, performance, tests/CI, App Store, offline/state, Supabase scale, HealthKit, UX edges) with adversarial verification of every P0/P1 candidate (14/14 survived, 0 refuted), plus direct verification against the **live production database**, **production API logs**, **Supabase advisors** (20 performance lints), and **Sentry**. ~22 agents, 362 file/tool inspections.
**Out of scope (already fixed, verified live):** the `lean_bulk` goal_type constraint drift, save-error classification/copy, Sentry non-fatal capture at onboarding/edit sites, guest-mode auth race, quick-log silent failure.

---

## Executive Summary — Top 10

| # | Sev | Finding | Area | Effort |
|---|-----|---------|------|--------|
| 1 | **P0** | **Password reset is a complete dead end** — `resetPasswordForEmail` has no `redirectTo`, no `onOpenURL` handler exists, `.passwordRecovery` event explicitly ignored, no set-new-password UI anywhere. AuthView tells the user "A reset link has been sent — check your inbox," but the link lands on the project Site URL with a token nothing consumes. **Every email/password user who forgets their password is permanently locked out.** Two independent auditors converged on this. | auth | M |
| 2 | **P1** | **Sign-out never resets per-user store state** — `SettingsView.signOut()` and `DataFetchErrorView` sign-out call only `authManager.signOut()`; the 6 stores keep user A's food logs, recents, favorites, grocery list, and daily note in memory. User B on the same device can see A's data and `NoteEditorSheet` can upsert A's note text into B's account. Manual reset lists in SettingsView have already drifted (exitGuestMode resets 5 stores, clearUserOwnedState 6). | security/privacy | S |
| 3 | **P1** | **No `PrivacyInfo.xcprivacy`** — app code calls UserDefaults in 7 files (required-reason API, CA92.1). ITMS-91053 enforcement can block any future upload, including an urgent crash hotfix, at archive time. SDK manifests don't cover app code. | App Store | XS |
| 4 | **P1** | **Progress 30/90-day fetch silently truncates at PostgREST max_rows (1000), dropping the *newest* days first** — `refreshWeek` has no `.limit()`, orders ascending; a user logging 11+/day exceeds 1000 rows in 90 days and the chart shows zero-calorie recent days with no error. Wrong data for exactly the most-engaged users. | data correctness | S |
| 5 | **P1** | **Search tab refetch storm** — `.task` re-runs on every appearance (comment claims "fetched once"); each Search visit re-downloads the full 1500-row type-ahead corpus + 4 more queries. Production logs confirm 6 corpus fetches in one session. ~4–5× redundant request volume per session; the dominant egress cost as DAU grows. | performance | XS |
| 6 | **P1** | **No automated prod drift check** — CI validates migration *files* against a local stack only; the worst incident to date (goal_type drift) lived exclusively in prod and would still be invisible to CI today. Drift check exists only as a documented manual step. | CI | S |
| 7 | **P1** | **Grocery list loses data offline and resurrects deleted items** — typed item vanishes silently (field cleared before the network call, empty catch), offline deletes/clear-checked come back next session. The feature fails precisely in its primary context (supermarkets). | stability | S |
| 8 | **P1** | **GuestDataStore silently wipes ALL guest data on any schema evolution** — `try?` decode returns nil → `?? []` → next append persists the empty array permanently. `FoodLog.mealSlot` is non-optional with no decode default, so this mechanism has already fired in principle once. Zero tests. Guests are the pre-conversion funnel. | data loss | S |
| 9 | **P1** | **Enum↔CHECK-constraint contract tests cover only goal_type/pace** — `meal_slot`, `sex`, `activity_level` have DB CHECK constraints with no Swift-side tripwire. This is the exact lean_bulk incident class, unguarded on three more columns. | tests | S |
| 10 | **P1** | **Account deletion doesn't revoke Sign in with Apple tokens** — explicit Apple requirement (since June 2022, tied to 5.1.1(v)). The edge function's header honestly documents the gap; `admin.deleteUser` does not call `/auth/revoke`. Low detection probability, real written requirement. | App Store | M |

Also P1 (just outside top 10): **food-log orchestration duplicated 3× and already diverged** — the *primary* log path (FoodDetailView) has no Sentry capture while the rarer swipe path does; HealthKit export semantics differ between copies (S). **AuthManager (694 lines) has zero tests**, including no regression pin on the already-fixed guest race (M).

---

## Scores

| Dimension | Score | Rationale |
|---|---|---|
| **Security** | **8/10** | Fundamentals verified strong: live RLS owner-scoped with WITH CHECK on every table, no service_role client-side, secrets gitignored, JWTs masked + DEBUG-gated, edge function derives identity solely from verified JWT, zero force-unwrap/`try!` crash surface. Deductions: sign-out in-memory residue (#2), `verify_jwt=false` on delete-account, Sentry network breadcrumbs leak search text + user_id in URLs, password policy weak (min 6, leaked-password protection off). |
| **Stability** | **6/10** | No crash-prone patterns; MainActor everywhere; double-submit guards near-complete. But: every offline write is permanently lost (no queue), grocery/note/water/HK failures still silent, day-rollover bug, retry-after-timeout can duplicate rows (no client-generated IDs), Progress truncation (#4), store/DB desyncs on partial edit saves. |
| **Maintainability** | **6/10** | Consistent store+DI pattern, honest small services, no dead abstractions (AppRouter and the search protocol earn their keep). But the core-loop orchestration is triplicated and has drifted (telemetry hole on the main path), the maintenance-pace rule exists 4× with live data drift, six stores follow divergent error conventions (the root of the recurring silent-failure class), and the glue layer is structured in a way that resists testing. |
| **Test coverage confidence** | **4/10** | What exists is good and incident-driven: ~64 pure-logic tests + a real pgTAP suite (39 RLS asserts + constraint-shape regression). But 100% of the glue layer — AuthManager, all 7 stores, both Supabase services, 3 search services, OFF normalization, GuestDataStore persistence — has zero coverage, and **every production bug so far lived in that untested glue**. No decode fixtures, no coverage signal, no Release build in CI, UI tests are launch-only and weekly. |
| **App Store readiness** | **6.5/10** | Five successful reviews; usage strings accurate (HealthKit "does not read" claim verified true — read set is empty), entitlements minimal, 4.8 satisfied (Apple+Google+guest), in-app deletion discoverable. Gaps: missing privacy manifest (#3) is a future upload-blocker; Apple token revocation (#10); privacy nutrition label has no in-repo source of truth while the binary observably sends health data, email, and Sentry diagnostics; iPad is universal+all-orientations with zero adaptive code and no documented testing; password reset (#1) is reviewer-visible. |

---

## 1. Security Audit

**Verified clean (evidence-backed):** RLS live-dumped and owner-scoped everywhere incl. WITH CHECK; `generic_foods` write-denied by default; no service_role/`SUPABASE_SERVICE` anywhere in app code; Secrets.xcconfig gitignored, template-only tracked; delete-account derives user solely from JWT via `auth.getUser()` (verified byte-identical live, v8); Apple sign-in nonce handling correct; zero `try!`/`as!`/risky force unwraps in app code; all sensitive prints `#if DEBUG`-gated with masked tokens.

| Sev | Finding | File | Exploitability | Recommendation |
|---|---|---|---|---|
| P1 | Sign-out keeps previous user's data in 6 stores (Top-10 #2) | `SettingsView.swift:522`, `AkFitApp.swift:179` | Shared-device local access; B can read A's health-adjacent data and overwrite A's note into B's account | One `.onChange(of: authManager.userState)` reset hook for all stores; delete the drifted manual lists |
| P2 | `delete-account` deployed `verify_jwt=false`; unpinned `supabase-js@2` (carried forward) | `supabase/config.toml:372`, `functions/delete-account/index.ts:26` | Unauthenticated invocation spam (fails closed); supply-chain drift into the service-role path | `verify_jwt=true` + pin exact version |
| P2 | Sentry auto network breadcrumbs attach full Supabase URLs: `search_text=ilike.*<user query>*`, `user_id=eq.<uuid>` — violates the app's own no-user-data-in-Sentry rule | `SentryMonitoring.swift:9-22` | n/a (data governance) | `beforeBreadcrumb` strips query strings, or disable network breadcrumbs |
| P2 | Password policy: min length 6, empty requirements, leaked-password protection off | `config.toml` + dashboard | Credential stuffing/weak passwords | Min 8+, enable HIBP check (dashboard toggle) |

## 2. Stability Audit

| Sev | Finding | File |
|---|---|---|
| P0 | Password reset dead end (Top-10 #1) | `AuthManager.swift:375`, `AuthView.swift:303` |
| P1 | Progress 90-day silent truncation (Top-10 #4) | `FoodLogStore.swift:242` |
| P1 | Grocery offline data loss + resurrection (Top-10 #7) | `GroceryListStore.swift:124,182,212`, `SearchView.swift:422` |
| P1 | GuestDataStore silent total wipe (Top-10 #8) | `GuestDataStore.swift:284` |
| P2 | No write queued for retry — every offline write permanently lost (verifier-confirmed; L effort, deliberate scope call) | all stores |
| P2 | Food/water/bodyweight inserts lack client-generated IDs → commit-then-timeout + "try again" = duplicate rows (Grocery already does it right) | `FoodLogStore.swift:417` |
| P2 | EditGoal/EditProfile: two sequential non-atomic writes; partial failure desyncs DB vs memory while the alert claims nothing saved | `EditGoalView.swift:202` |
| P2 | Goal/profile fetched only at auth events — multi-device staleness is unbounded; the only scenePhase handler reschedules notifications | `AuthManager.swift:219`, `AkFitApp.swift:57` |
| P2 | Water card shows "0 oz" as fact on failed fetch, then under-reports after first successful add (`updateInMemory` adopts a lone entry as the day total) | `DashboardView.swift:102`, `WaterStore.swift:175` |
| P2 | Daily note: failed fetch opens blank editor; Done **overwrites the server note** — silent destruction of user content | `DailyNoteStore.swift:74`, `DashboardView.swift:1171` |
| P2 | HealthKit export one-shot, error fully swallowed (no log, no Sentry) — Health silently diverges from app | `HealthKitService.swift:200` |
| P2 | WeightLogSheet cancellable/swipe-dismissible mid-save (same class as known EditGoal/EditProfile gap) | `ProgressTabView.swift:642` |
| P2 | Decode brittleness: unknown enum value in `profiles.sex/activity_level` or `food_logs.meal_slot` bricks the whole fetch → onboarded user locked behind DataFetchErrorView | `UserProfile.swift:78` |

## 3. Architecture Audit

Honest framing: this is **View → @Observable Store → static Service**, not MVVM — and that's fine. Constructor injection from `AkFitApp.init` is sound and preview-friendly; AppRouter is a 40-line fully-used carrier; the search protocol has three real conformers. **Do not introduce a ViewModel layer, a store base class, or split AkFitApp wiring** — no payoff.

Real problems:
- **P1** Food-log orchestration (insert → HK export → reminder cancel → banner → telemetry) copy-pasted 3× (SearchView ×2, FoodDetailView) and already diverged: primary path lost Sentry capture, HK export awaited vs fire-and-forget. → extract one `FoodLogStore.logAndSync(...)`.
- **P2** "Maintenance has no pace" rule implemented 4× with **live drift**: `GoalService.update` always writes a pace; onboarding/guest write NULL. Same action → different stored data by path.
- **P2** Guest UserGoal/UserProfile construction hand-rolled in 3 views with field-level differences (EditGoalView fabricates an empty profile).
- **P2** Six stores, divergent error/refresh conventions (`refreshFailed` vs `isLoading` vs nothing) — the recurring silent-failure UX class traces directly to this missing contract. Fix by convention note + aligning flags, not abstraction.
- DashboardView (1299 lines) is internally well-decomposed; splitting files is nice-to-have only.

## 4. Performance Audit

| Sev | Finding | Estimated impact |
|---|---|---|
| P1 | Search `.task` refetch storm (Top-10 #5) | ~30 requests/session for a 3-log session; 40–60KB static corpus per refetch; linear egress cost with DAU; fix is a 2-line `isEmpty` guard |
| P2 | Per-keystroke type-ahead rebuilds + re-sorts + re-stems the full ~1500-term pool on MainActor, Levenshtein on typo path | est. 5–25ms/keystroke (30–60ms on iPhone XR/11 class) → precompute normalized pool once |
| P2 | Progress fetches raw `select(*)` rows for 90 days on every tab appearance | ~300–500KB/visit for engaged users; grows with account age → project 5 columns now, daily-SUM RPC later |
| P2 | Dashboard refetches day logs+water+note on every tab appearance, no staleness window | ~3 redundant calls per bounce; with Search, ~40–50 req/session where ~10 carry information |
| P2 | GuestDataStore decodes entire history at init and re-encodes the whole array per log | month-6 guest: every tap rewrites multi-MB plist; launch decode grows unbounded → cap at 90 days |
| P2 | Sentry replay buffers frames on 100% of sessions (`onErrorSampleRate=1.0`) | constant CPU/memory/battery tax on a many-short-sessions app — deliberate tradeoff to revisit |
| P2 | ProgressTabView recomputes chart aggregation ~5× per render pass | low ms today; compounds with raw-row fetches → memoize into @State |
| P2 | 20 live `auth_rls_initplan` advisor warnings — every policy re-evaluates `auth.uid()` per row | negligible at 54 users; real tax on food_logs at scale; one migration `(select auth.uid())` fixes all |

Startup and render-layer are healthy (cached formatters, scoped animations, light init).

## 5. Testing Audit

Top 5 highest-risk untested paths, with exact tests:
1. **Enum↔CHECK contracts** (`meal_slot`, `sex`, `activity_level`): `MealSlotDatabaseContractTests` asserting `Set(MealSlot.allCases.map(\.rawValue)) == ["breakfast","lunch","dinner","snack"]` + Sex/ActivityLevel equivalents + pgTAP `matches(pg_get_constraintdef)` for the three checks.
2. **GuestDataStore round-trip/backward-compat**: inject `UserDefaults(suiteName:)` (one-line seam); round-trip every persisted type; frozen legacy-JSON fixture (FoodLog without `meal_slot`) asserting old data loads — make it pass via `decodeIfPresent` + `.snack` default.
3. **AuthManager state machine**: make `handle()` internal; drive `.signedOut`/`.tokenRefreshed`/no-session `.initialSession` with a Session JSON fixture; pin the guest-race re-check; pure tests for `setPendingAppleCredentials`/`isInvalidJWTError`.
4. **PostgREST decode fixtures**: frozen real JSON for profiles (numeric-as-string, nulls), goals (null pace), food_logs (timestamps with/without fractional seconds); plus tolerant-decode policy for enum columns.
5. **FoodLogStore in-memory routing** via the guest seam: past-day insert absent from `todayLogs`, present in `weekLogs`/`dayLogs`-when-viewing; delete removes everywhere; `asFoodItem` back-calculation.

Also: OFF `toFoodItem` is `private` — one-word visibility change unlocks testing the function that decides every scanned macro. pgTAP behavioral suite skips 3 of 8 user tables + never proves generic_foods write-denial. CI: no coverage signal (`"codeCoverage": true` in the testplan + `xccov` print), no Release build job, no SPM cache, zero functional UI smoke (recommend ONE hermetic guest-mode test: launch → guest → onboarding defaults → dashboard visible).

## 6. Documentation Audit

Post-June-11 docs (release checklist, save flow, drift check, error map) are current. Remaining gaps:
- No in-repo record of the App Privacy nutrition label (what was declared vs what the binary sends) — add to release checklist.
- No documented path for shipping new seed files to production (`seeds/food/` README ends at local reset); migrations/seeds parity asserted only for historical files.
- `docs/ui-reference/00_index.md` + `05_notes/` still referenced by CLAUDE.md/AGENTS.md/README but don't exist (carried).
- Password-reset/auth-recovery flow has no doc because the flow doesn't exist (see #1).
- Local `config.toml` silently diverges from prod auth (confirmations off locally, on in prod; SMTP unconfigured — if prod still uses built-in SMTP, auth emails cap at ~2/hr project-wide and sign-ups stall) — verify dashboard SMTP and record it.

## 7. UX Edge Cases

P2 set, all evidence-backed: same-day macro totals **disagree between Dashboard and Progress** (sum-of-rounded vs rounded-sum — up to ±4g; trust killer in a macro app) · water card "0 oz" on failed fetch · blank-note-overwrites-server-note · grocery silent loss/resurrection · WeightLogSheet mid-save dismissal · unbounded `display_name` rendered into the 34pt results title and dashboard greeting · HealthKit denied state renders a blank Settings row with no remediation path · HK partial grants misreport via bodyMass-proxy status ("Connected" while food export silently fails).

## 8. Supabase / Scalability

- Type-ahead `limit(1500)`: silent alphabetical truncation as seeds grow past 1500 (late-alphabet brands vanish first, no error, no test); dominant egress driver → device cache + count guard, server prefix query later.
- `generic_foods` has no uniqueness constraint; 0/30 seed files use `ON CONFLICT`; seed 026 already cleans up duplicates that happened once → unique index + idempotent seeds + a prod-apply procedure.
- food_logs indexes cover current query shapes; revisit with the daily-aggregate RPC.
- At ~10k users the first pressure points: egress (type-ahead corpus), auth email throughput (if built-in SMTP), then RLS initplan on food_logs.

---

## Roadmap

**Next 3 (do before the next release):**
1. `PrivacyInfo.xcprivacy` (XS) — removes the binary upload-blocker risk from every future submission.
2. Search `.task` isEmpty guard + Dashboard staleness window (XS–S) — kills the #1 perf/cost bug with two tiny guards.
3. Sign-out store reset via a single `.onChange(of: userState)` hook (S) — closes the cross-account data exposure.

**Next 10 (in order):**
4. Password reset recovery flow: `redirectTo: akfit://`, `onOpenURL` → `auth.session(from:)`, `.passwordRecovery` → set-new-password sheet (M)
5. Progress fetch: column projection + explicit limit/desc now; daily-SUM RPC later (S)
6. Scheduled read-only prod drift job in CI (constraints + policies diff vs snapshot) (S)
7. Grocery offline: restore typed text + alert; revert optimistic deletes on failure (S)
8. GuestDataStore: tolerant legacy decode (`meal_slot` default) + round-trip/fixture tests (S)
9. Contract tests for `meal_slot`/`sex`/`activity_level` + pgTAP constraint pins (S)
10. Extract `FoodLogStore.logAndSync` — one orchestration, Sentry on the primary path (S)
11. Daily-note fetch-failed guard (stop blank-editor overwrites) + water card error state (S)
12. AuthManager state-machine tests (internal `handle()` + Session fixture) (M)
13. Apple token revocation in delete-account (capture authorizationCode → store refresh token → `/auth/revoke`) (M)

**Intentionally not fixing (called out so nobody burns time):**
- General offline write queue / sync engine — L effort; revisit only if retention data shows dead-zone loss matters; a food-log-only pending queue is the eventual middle ground.
- ViewModel layer, store base class, generic mutation abstraction — no payoff at this size; the store convention note + flag alignment achieves the goal.
- DashboardView file split — internally well-decomposed; cosmetic.
- iPad adaptive redesign — smoke-test per release instead; constrain widths only if something actually breaks.
- Realtime multi-device sync — scenePhase refetch (item in P2 list) covers the realistic case.
- RLS `(select auth.uid())` rewrite — bundle into the next policy migration; not standalone work at 54 users.
- Migrating legacy anon key → publishable keys — wait for Supabase's forcing function.
- `display_name` DB constraint — client-side clamp is sufficient.

---

## Carried-forward open backlog (previous audit, still valid)

verify_jwt=true + pin supabase-js (edge fn) · day-rollover snap-to-today · undo-last-log error surfacing · orphaned HK samples on delete · Progress error state · offline search/barcode copy · scan button dark-mode colors · a11y labels + Dynamic Type · edit-sheet dismissal guards · stale-email signup stranding · leaked-password protection toggle · `handle_updated_at`/`rls_auto_enable` migration codification · ui-reference index docs.
