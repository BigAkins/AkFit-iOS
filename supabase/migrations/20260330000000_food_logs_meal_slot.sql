-- =============================================================================
-- Migration: 20260330000000_food_logs_meal_slot
-- Table:     food_logs
-- Purpose:   Adds meal_slot for grouping log entries as breakfast / lunch /
--            dinner / snack on the dashboard and in future reporting.
--
-- Design notes:
--   - text + CHECK constraint instead of a Postgres enum: extending the slot
--     set later requires only a new CHECK migration, not an ALTER TYPE (which
--     can lock the table and requires dropping/recreating dependent objects).
--   - DEFAULT 'snack' backfills all existing rows without data loss and
--     gives the column NOT NULL semantics from the moment it is added.
--   - No RLS changes needed: the column lives on food_logs, which already has
--     user-scoped select / insert / delete policies enforcing
--     auth.uid() = user_id. Those policies cover all columns on the table,
--     including this new one.
-- =============================================================================

alter table public.food_logs
    add column meal_slot text not null default 'snack'
        check (meal_slot in ('breakfast', 'lunch', 'dinner', 'snack'));
