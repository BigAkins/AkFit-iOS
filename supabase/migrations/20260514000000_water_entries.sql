-- =============================================================================
-- Migration: 20260514000000_water_entries
-- Table:     water_entries
-- Purpose:   Stores event-style daily water intake entries.
--
-- Design notes:
--   - amount_ml is the canonical internal unit. The iOS app can convert from
--     ounces at the UI boundary while storage stays metric and unambiguous.
--   - Multiple entries per day are allowed. Daily totals are calculated by
--     summing entries in the selected local-day range.
--   - Per-entry amount is capped at 5000 ml to reject accidental extreme input.
--
-- Security:
--   - RLS enabled. Users can select, insert, update, and delete only their
--     own rows. INSERT and UPDATE both enforce ownership with WITH CHECK.
-- =============================================================================

create table public.water_entries (
    id          uuid        not null primary key default gen_random_uuid(),
    user_id     uuid        not null references auth.users(id) on delete cascade,
    amount_ml   integer     not null check (amount_ml > 0 and amount_ml <= 5000),
    logged_at   timestamptz not null default now(),
    created_at  timestamptz not null default now()
);

alter table public.water_entries enable row level security;

create policy "water_entries: select own"
    on public.water_entries for select
    using (auth.uid() = user_id);

create policy "water_entries: insert own"
    on public.water_entries for insert
    with check (auth.uid() = user_id);

create policy "water_entries: update own"
    on public.water_entries for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "water_entries: delete own"
    on public.water_entries for delete
    using (auth.uid() = user_id);

-- Hot path: fetch one user's entries for a selected day/range, newest first.
create index water_entries_user_logged_at_idx
    on public.water_entries (user_id, logged_at desc);
