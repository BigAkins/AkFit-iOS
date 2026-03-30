-- =============================================================================
-- Migration: 20260330000001_bodyweight_logs
-- Table:     bodyweight_logs
-- Purpose:   Stores daily bodyweight entries for 7-day trend tracking.
--
-- Design notes:
--   - weight_kg stores the canonical metric value; the client converts to
--     pounds for display (matching the existing pattern in user_goals).
--   - Multiple entries per day are allowed — the client uses the latest
--     logged_at for each calendar day when rendering the trend chart.
--   - No RLS column exceptions needed: the user-scoped policies below cover
--     all columns on this table.
-- =============================================================================

create table public.bodyweight_logs (
    id          uuid          not null primary key default gen_random_uuid(),
    user_id     uuid          not null references auth.users (id) on delete cascade,
    -- Canonical storage in kilograms. numeric(5,2) covers 0.01–999.99 kg.
    weight_kg   numeric(5, 2) not null check (weight_kg > 0),
    logged_at   timestamptz   not null default now(),
    created_at  timestamptz   not null default now()
);

alter table public.bodyweight_logs enable row level security;

-- Users may only read their own bodyweight entries.
create policy "bodyweight_logs: select own"
    on public.bodyweight_logs for select
    using (auth.uid() = user_id);

-- Users may only insert their own bodyweight entries.
create policy "bodyweight_logs: insert own"
    on public.bodyweight_logs for insert
    with check (auth.uid() = user_id);

-- Users may delete their own bodyweight entries (supports overwriting today's entry).
create policy "bodyweight_logs: delete own"
    on public.bodyweight_logs for delete
    using (auth.uid() = user_id);

-- Hot path: fetching the past 7 days for a user, newest first.
create index bodyweight_logs_user_day_idx
    on public.bodyweight_logs (user_id, logged_at desc);
