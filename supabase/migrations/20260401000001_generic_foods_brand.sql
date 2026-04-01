-- =============================================================================
-- Migration: 20260401000001_generic_foods_brand
-- Purpose:   Add a nullable `brand` column to generic_foods to distinguish
--            branded restaurant items (McDonald's, Chipotle) from USDA generic
--            entries.
--
-- `brand` maps to `FoodItem.brandOrCategory` in the iOS app, which shows the
-- restaurant or brand name as a secondary label in food search result rows.
--
-- NULL for all generic/USDA foods.
-- Set to the chain name (e.g. 'McDonald''s', 'Chipotle') for fast-food entries
-- inserted by the fast-food seed migrations that follow.
-- =============================================================================

alter table public.generic_foods
    add column if not exists brand text;
