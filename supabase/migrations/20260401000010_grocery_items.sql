-- =============================================================================
-- Migration: 20260401000010_grocery_items
-- Purpose:   Creates the grocery_items table — a persistent, date-agnostic
--            checklist. Accessed from the Search tab empty state.
--
-- Design decisions:
--   - No note_date — the grocery list is not date-scoped. Users build it up
--     across sessions and clear checked items when done shopping.
--   - sort_order (int) preserves stable insertion order without drag-sort UI.
--     Client writes sort_order = max(existing) + 1 on each insert.
--     Gaps after deletion are fine — ORDER BY sort_order ASC still works.
--   - is_checked default false — items start unchecked.
--
-- Security:
--   - RLS enabled. Single "all" policy: users can select, insert, update, and
--     delete only their own rows.
-- =============================================================================

create table public.grocery_items (
    id          uuid        not null default gen_random_uuid() primary key,
    user_id     uuid        not null references auth.users(id) on delete cascade,
    name        text        not null,
    is_checked  boolean     not null default false,
    sort_order  int         not null default 0,
    created_at  timestamptz not null default now()
);

-- Index: primary query is all items for a user, sorted by insertion order.
create index grocery_items_user_order_idx
    on public.grocery_items (user_id, sort_order asc);

-- RLS
alter table public.grocery_items enable row level security;

create policy "Users manage own grocery items"
    on public.grocery_items
    for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);
