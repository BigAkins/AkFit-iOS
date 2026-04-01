-- =============================================================================
-- Migration: 20260401000009_daily_notes
-- Purpose:   Creates the daily_notes table — one free-text note per user per
--            calendar day. Accessed from the Dashboard bottom section.
--
-- Design decisions:
--   - note_date is type `date` (not timestamptz) — a note belongs to a
--     calendar day, not a point in time. Avoids timezone edge cases.
--   - UNIQUE (user_id, note_date) enables clean ON CONFLICT upsert — the
--     client never needs to decide whether to INSERT or UPDATE.
--   - content default '' (empty string) simplifies Swift binding — no optional.
--   - updated_at tracked for ordering/audit purposes only (not exposed in UI).
--
-- Security:
--   - RLS enabled. Single "all" policy: users can select, insert, update, and
--     delete only their own rows. No cross-user reads are possible.
-- =============================================================================

create table public.daily_notes (
    id          uuid        not null default gen_random_uuid() primary key,
    user_id     uuid        not null references auth.users(id) on delete cascade,
    note_date   date        not null,
    content     text        not null default '',
    updated_at  timestamptz not null default now(),

    constraint daily_notes_user_date_unique unique (user_id, note_date)
);

-- Index: most common query pattern is (user_id, note_date) point lookup.
create index daily_notes_user_date_idx
    on public.daily_notes (user_id, note_date desc);

-- RLS
alter table public.daily_notes enable row level security;

create policy "Users manage own daily notes"
    on public.daily_notes
    for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);
