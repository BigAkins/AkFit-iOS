-- =============================================================================
-- Migration: 20260611054748_fix_goals_goal_type_check
-- Purpose:   Fix the live goals_goal_type_check constraint so 'lean_bulk' is
--            accepted. This is the root cause of every onboarding final-save
--            failure since launch for users who chose "Lean Bulk".
--
-- ── Root cause ───────────────────────────────────────────────────────────────
-- The live public.goals table was hand-created in the dashboard before
-- migration tracking was reconciled, with:
--
--   CHECK (goal_type IN ('fat_loss', 'maintenance', 'muscle_gain'))
--
-- The app has always sent goal_type = 'lean_bulk'
-- (UserGoal.GoalType.leanBulk.rawValue). Result: every goals INSERT (onboarding
-- results step) and every UPDATE switching to Lean Bulk (EditGoalView) failed
-- with SQLSTATE 23514 (check_violation) — deterministically, on every retry,
-- on every app version.
--
-- The tracked migrations (20260329000000, 20260401000014) declare the correct
-- 'lean_bulk' set, but 20260401000014 used CREATE TABLE IF NOT EXISTS, which
-- silently no-opped against the pre-existing live table — so the corrected
-- constraint never reached production. Verified live on 2026-06-11:
--   * pg_get_constraintdef showed the 'muscle_gain' variant
--   * goals distribution: 32 fat_loss, 8 maintenance, 0 lean_bulk ever
--   * 10 users stuck with a profile but no goal (profile upsert succeeds,
--     goal insert rejected), repeatedly retried, never recovered
--
-- ── Fix ──────────────────────────────────────────────────────────────────────
-- 1. Normalize any legacy 'muscle_gain' rows to 'lean_bulk' (0 rows exist as
--    of 2026-06-11; the UPDATE is a defensive no-op kept for idempotency on
--    any environment where such rows might exist).
-- 2. Drop and re-add the constraint with the canonical app value set.
--
-- ALTER TABLE ... ADD CONSTRAINT validates existing rows (40 rows live —
-- instantaneous). Runs in one transaction; no RLS, policy, index, or data
-- changes beyond the defensive normalization.
--
-- Recovery: the stuck users remain routed to onboarding (no goal row =>
-- isOnboarded == false). Their next "Start tracking" tap re-upserts the
-- profile (idempotent) and the goal insert now succeeds. No data repair needed.
-- =============================================================================

update public.goals
   set goal_type = 'lean_bulk'
 where goal_type = 'muscle_gain';

alter table public.goals
    drop constraint if exists goals_goal_type_check;

alter table public.goals
    add constraint goals_goal_type_check
    check (goal_type in ('fat_loss', 'maintenance', 'lean_bulk'));
