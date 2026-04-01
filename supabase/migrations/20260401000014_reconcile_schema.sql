-- =============================================================================
-- Migration: 20260401000014_reconcile_schema
-- Purpose:   Brings tracked migrations into alignment with the live database
--            schema actually used by the app.
--
-- ── Drift A: goals vs user_goals ─────────────────────────────────────────────
-- The initial migration (20260329000000) created public.user_goals with a
-- completely different column set:
--   target_calories, target_protein_g, target_carbs_g, target_fat_g,
--   height_cm, weight_kg, age, sex, activity_level, pace, is_active
-- None of these columns exist in UserGoal.CodingKeys; the app never queries
-- from("user_goals"). Every Swift call site — AuthManager, OnboardingView,
-- EditGoalView, EditProfileView — queries from("goals") with:
--   daily_calories, daily_protein, daily_carbs, daily_fat, target_pace,
--   target_weight, goal_type, created_at, updated_at
-- A subsequent migration (20260331000000) altered user_goals.height_cm and
-- weight_kg — columns that belong on profiles, not on the goals table.
--
-- Fix: create public.goals (if not already present in the live DB) and drop
-- public.user_goals.
--
-- ── Drift B: profiles missing columns ────────────────────────────────────────
-- The initial migration + 20260331000001 left profiles with only:
--   id, display_name, created_at, sex, activity_level
-- ProfileInsert (onboarding) and ProfileUpsert (EditProfileView) both write
-- and UserProfile.CodingKeys reads back:
--   height_cm integer, weight_kg integer, birthdate date, updated_at timestamptz
-- These columns existed in the live database but were never tracked in any
-- previous migration.
--
-- Fix: add the four missing columns. All are nullable or carry DEFAULT values
-- so existing rows are unaffected.
--
-- ── Safety design ─────────────────────────────────────────────────────────────
-- • CREATE TABLE IF NOT EXISTS / DROP TABLE IF EXISTS: idempotent on the live
--   DB where goals may already exist and user_goals may already be absent.
-- • DROP POLICY IF EXISTS → CREATE POLICY: avoids duplicate_object errors when
--   the live DB already has the goals table with correct RLS.
-- • ADD COLUMN IF NOT EXISTS: safe to re-run; no-op if already present.
-- • All statements run in one transaction so there is no partial-apply state.
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- A-1. Create the correct goals table
-- ─────────────────────────────────────────────────────────────────────────────
-- Schema is derived directly from UserGoal.CodingKeys and the GoalInsert /
-- GoalUpdate / GoalPatch structs in OnboardingView, EditGoalView, and
-- EditProfileView. Body-stat columns (height, weight, age, sex, activity_level)
-- belong on profiles, not on this table.

create table if not exists public.goals (
    id             uuid        not null primary key default gen_random_uuid(),
    user_id        uuid        not null references auth.users (id) on delete cascade,

    goal_type      text        not null
                       check (goal_type in ('fat_loss', 'maintenance', 'lean_bulk')),

    -- target_weight: desired body weight in kg. Never written by current app code
    -- (GoalInsert does not include it, so it is always NULL). Retained because
    -- UserGoal.targetWeight: Double? reads it; the custom Decodable handles both
    -- numeric and JSON-string responses from PostgREST.
    target_weight  numeric(5, 2),

    -- target_pace: nullable to match UserGoal.targetPace: Pace? in Swift.
    -- OnboardingView always provides a value via input.pace.rawValue.
    target_pace    text
                       check (target_pace in ('slow', 'moderate', 'fast')),

    daily_calories int         not null check (daily_calories > 0),
    daily_protein  int         not null check (daily_protein  >= 0),
    daily_carbs    int         not null check (daily_carbs    >= 0),
    daily_fat      int         not null check (daily_fat      >= 0),

    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

alter table public.goals enable row level security;

-- DROP-IF-EXISTS → CREATE: idempotent on both fresh and live databases.
-- Both the canonical names used in this migration AND the alternate names that
-- exist in the live database (e.g. "Users can view their own goals") are dropped
-- first so the migration never produces duplicate policies.

drop policy if exists "goals: select own"             on public.goals;
drop policy if exists "Users can view their own goals" on public.goals;
create policy "goals: select own"
    on public.goals for select
    using (auth.uid() = user_id);

drop policy if exists "goals: insert own"               on public.goals;
drop policy if exists "Users can insert their own goals" on public.goals;
create policy "goals: insert own"
    on public.goals for insert
    with check (auth.uid() = user_id);

-- Update required: EditGoalView.patchGoal and EditProfileView.patchGoal both
-- PATCH the active goals row after recalculating macro targets.
drop policy if exists "goals: update own"               on public.goals;
drop policy if exists "Users can update their own goals" on public.goals;
create policy "goals: update own"
    on public.goals for update
    using (auth.uid() = user_id);

-- Delete: not called explicitly by the app, but present in the live DB and
-- harmless to carry forward. Removed via ON DELETE CASCADE on account deletion.
drop policy if exists "goals: delete own"               on public.goals;
drop policy if exists "Users can delete their own goals" on public.goals;
create policy "goals: delete own"
    on public.goals for delete
    using (auth.uid() = user_id);

-- Index for AuthManager.fetchActiveGoal:
--   from("goals").eq("user_id", …).order("created_at", ascending: false).limit(1).single()
create index if not exists goals_user_created_idx
    on public.goals (user_id, created_at desc);


-- ─────────────────────────────────────────────────────────────────────────────
-- A-2. Drop the incorrect user_goals table
-- ─────────────────────────────────────────────────────────────────────────────
-- user_goals was created by the initial migration with a completely wrong schema
-- (target_calories / target_protein_g / is_active / etc.) and was never queried
-- by any Swift code. All production goal data has always lived in public.goals.
-- IF EXISTS guards against the case where user_goals was never present in the
-- live DB (e.g. it was already manually dropped, or this migration is the first
-- time goals are being reconciled on a clone/staging environment).

drop table if exists public.user_goals;


-- ─────────────────────────────────────────────────────────────────────────────
-- B. Add missing columns to profiles
-- ─────────────────────────────────────────────────────────────────────────────
-- These four columns are written on every profile upsert (onboarding and
-- EditProfileView) and decoded on every profile fetch via UserProfile.CodingKeys.
-- They existed in the live database but were absent from all tracked migrations.

alter table public.profiles
    -- integer (not numeric) so PostgREST serialises as a JSON number, which
    -- JSONDecoder maps to Double without the type-mismatch that prompted
    -- migration 20260331000000 on user_goals.
    add column if not exists height_cm  integer,
    add column if not exists weight_kg  integer,
    -- PostgreSQL date type. PostgREST returns date columns as "YYYY-MM-DD"
    -- strings, which UserProfile.birthdate: String? decodes without error.
    -- ProfileInsert sends the value as a "YYYY-MM-DD" string and PostgreSQL
    -- casts it automatically.
    add column if not exists birthdate  date,
    -- NOT NULL with DEFAULT now() so existing rows created before this migration
    -- get a sensible non-null timestamp rather than a nullable gap.
    add column if not exists updated_at timestamptz not null default now();
