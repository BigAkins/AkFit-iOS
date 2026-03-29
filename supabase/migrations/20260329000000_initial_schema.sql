-- =============================================================================
-- Migration: 20260329000000_initial_schema
-- Tables: profiles, user_goals
-- RLS: enabled on both; users can only access their own rows
-- =============================================================================

-- ---------------------------------------------------------------------------
-- profiles
-- One row per authenticated user. Created after sign-up (during onboarding).
-- `id` is a FK to auth.users so the row is automatically removed when the
-- auth user is deleted (on delete cascade).
-- ---------------------------------------------------------------------------
create table public.profiles (
    id          uuid        not null primary key references auth.users (id) on delete cascade,
    display_name text,
    created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: select own"
    on public.profiles for select
    using (auth.uid() = id);

create policy "profiles: insert own"
    on public.profiles for insert
    with check (auth.uid() = id);

create policy "profiles: update own"
    on public.profiles for update
    using (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- user_goals
-- Stores the user's nutrition targets and the body stats used to derive them.
-- Multiple rows are supported over time (goal history). Exactly one row per
-- user should have is_active = true at any given time.
--
-- goal_type:      fat_loss | maintenance | lean_bulk
-- sex:            male | female
-- activity_level: sedentary | light | moderate | active | very_active
-- pace:           slow | moderate | fast  (rate of weight change)
-- ---------------------------------------------------------------------------
create table public.user_goals (
    id                uuid        not null primary key default gen_random_uuid(),
    user_id           uuid        not null references auth.users (id) on delete cascade,
    goal_type         text        not null check (goal_type in ('fat_loss', 'maintenance', 'lean_bulk')),
    target_calories   int         not null check (target_calories > 0),
    target_protein_g  int         not null check (target_protein_g >= 0),
    target_carbs_g    int         not null check (target_carbs_g >= 0),
    target_fat_g      int         not null check (target_fat_g >= 0),
    height_cm         numeric(5, 1),
    weight_kg         numeric(5, 2),
    age               int         check (age > 0 and age < 130),
    sex               text        check (sex in ('male', 'female')),
    activity_level    text        check (activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')),
    pace              text        check (pace in ('slow', 'moderate', 'fast')),
    is_active         boolean     not null default true,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now()
);

alter table public.user_goals enable row level security;

create policy "user_goals: select own"
    on public.user_goals for select
    using (auth.uid() = user_id);

create policy "user_goals: insert own"
    on public.user_goals for insert
    with check (auth.uid() = user_id);

create policy "user_goals: update own"
    on public.user_goals for update
    using (auth.uid() = user_id);

-- Partial index: looking up the single active goal per user is the hot path.
create index user_goals_active_idx
    on public.user_goals (user_id)
    where is_active = true;
