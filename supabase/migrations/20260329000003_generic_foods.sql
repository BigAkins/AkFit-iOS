-- =============================================================================
-- Migration: 20260329000003_generic_foods
-- Table:     generic_foods
-- Purpose:   Read-only reference database of common/generic foods seeded from
--            USDA FoodData Central values. Used by the hybrid search path to
--            return accurate results for generic food names (e.g. "chicken
--            breast", "egg", "oats") before falling back to Open Food Facts
--            for branded/packaged items.
--
-- Design notes:
--   - Public read-only: any authenticated (or anon) user may read.
--     No insert / update / delete from the client.
--   - Nutritional values are per serving as described by serving_label.
--   - serving_weight_g is nullable for entries where gram weight is ambiguous
--     (e.g. fluid servings). FoodDetail uses it for portion scaling; falls
--     back to a default when null.
--   - pg_trgm GIN index enables fast ilike '%query%' substring search.
-- =============================================================================

create extension if not exists pg_trgm;

create table public.generic_foods (
    id               uuid         not null primary key default gen_random_uuid(),
    food_name        text         not null,
    serving_label    text         not null,
    serving_weight_g numeric(6,2),
    calories         integer      not null check (calories >= 0),
    protein_g        numeric(6,2) not null check (protein_g >= 0),
    carbs_g          numeric(6,2) not null check (carbs_g >= 0),
    fat_g            numeric(6,2) not null check (fat_g >= 0),
    source           text         not null default 'usda',
    created_at       timestamptz  not null default now()
);

alter table public.generic_foods enable row level security;

-- Public read: any user (including anon) may query generic foods.
-- No write policy: inserts/updates/deletes are done via migrations only.
create policy "generic_foods: public read"
    on public.generic_foods for select
    using (true);

-- Trigram index for fast case-insensitive substring search (ilike '%query%').
create index generic_foods_name_trgm_idx
    on public.generic_foods
    using gin (food_name gin_trgm_ops);
