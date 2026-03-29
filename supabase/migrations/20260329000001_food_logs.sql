-- =============================================================================
-- Migration: 20260329000001_food_logs
-- Table:     food_logs
-- Purpose:   Persists individual food log entries for calorie/macro tracking.
--
-- Design notes:
--   - calories and macro grams are stored pre-scaled (food × quantity) so reads
--     are a simple SUM — no client-side multiplication needed.
--   - logged_at is timestamptz so timezone-correct "today" queries work for all
--     locales. Defaults to now() but can be user-overridden later.
--   - No meal grouping in this schema; entries are individual items.
--     Meal grouping can be layered on top (e.g. a meal_id FK) without a
--     destructive migration.
-- =============================================================================

create table public.food_logs (
    id            uuid        not null primary key default gen_random_uuid(),
    user_id       uuid        not null references auth.users (id) on delete cascade,
    food_name     text        not null,
    -- Human-readable serving description, e.g. "100g" or "2 tbsp (32g)".
    serving_label text        not null,
    -- Multiplier applied to the base serving at log time (e.g. 1.5 = 1.5 servings).
    -- stored as numeric so 0.25-step values are exact.
    quantity      numeric(5, 2) not null check (quantity > 0),
    -- Pre-scaled nutrition values (food value × quantity).
    calories      int         not null check (calories >= 0),
    protein_g     numeric(6, 1) not null check (protein_g >= 0),
    carbs_g       numeric(6, 1) not null check (carbs_g >= 0),
    fat_g         numeric(6, 1) not null check (fat_g >= 0),
    -- When the food was consumed. Defaults to insert time; supports future
    -- "log for earlier today" without a schema change.
    logged_at     timestamptz not null default now(),
    created_at    timestamptz not null default now()
);

alter table public.food_logs enable row level security;

-- Users may only read their own log entries.
create policy "food_logs: select own"
    on public.food_logs for select
    using (auth.uid() = user_id);

-- Users may only insert their own log entries.
create policy "food_logs: insert own"
    on public.food_logs for insert
    with check (auth.uid() = user_id);

-- Hot path: fetching today's logs for a user, ordered by time.
create index food_logs_user_day_idx
    on public.food_logs (user_id, logged_at desc);
