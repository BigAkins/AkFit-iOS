-- Migration: favorite_foods
-- Stores a user's saved/favorited foods for fast repeat logging.
--
-- Design decisions:
-- • Denormalized — all nutrition values are stored inline rather than
--   referencing generic_foods. This is intentional: Open Food Facts results
--   have ephemeral UUIDs (regenerated each search), so a foreign-key
--   relationship would fail for half the app's food sources.
-- • Unique constraint on (user_id, food_name, serving_label) prevents
--   duplicate favorites and lets the Swift layer use an upsert-like
--   pattern safely.
-- • brand_or_category is nullable — generic/USDA foods don't have a brand.
-- • serving_weight_g defaults to 0 (same convention as FoodLog.asFoodItem).

create table public.favorite_foods (
    id                uuid         not null primary key default gen_random_uuid(),
    user_id           uuid         not null references auth.users(id) on delete cascade,
    food_name         text         not null,
    serving_label     text         not null,
    serving_weight_g  numeric(6,2) not null default 0,
    calories          integer      not null check (calories >= 0),
    protein_g         numeric(6,2) not null check (protein_g >= 0),
    carbs_g           numeric(6,2) not null check (carbs_g >= 0),
    fat_g             numeric(6,2) not null check (fat_g >= 0),
    brand_or_category text,
    created_at        timestamptz  not null default now(),
    constraint favorite_foods_user_food_unique unique (user_id, food_name, serving_label)
);

alter table public.favorite_foods enable row level security;

-- Single policy: authenticated users can insert, read, update, and delete
-- only their own rows. `with check` ensures they cannot write rows for
-- other users even if they craft a payload manually.
create policy "favorite_foods: users manage own rows"
    on public.favorite_foods
    for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- Index for the primary read path: fetch all favorites for a user,
-- ordered by creation time (newest first).
create index favorite_foods_user_id_idx
    on public.favorite_foods (user_id, created_at desc);
