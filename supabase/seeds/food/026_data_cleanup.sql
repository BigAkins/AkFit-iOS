-- =============================================================================
-- Seed: 026_data_cleanup
-- Purpose: Post-seed cleanup of generic_foods — removes duplicates introduced
--          by earlier seed files (001–025) and normalizes a mis-named row.
--
-- Extracted from migration 20260402000014_data_cleanup_search_text so only
-- data operations live in the seed path. The associated schema change (add
-- search_text column, auto-populate trigger, trigram GIN index) stays in
-- supabase/migrations.
--
-- Depends on:
--   * seeds 001–025 (all food inserts prior to the cleanup point)
--   * generic_foods_search_text_trigger created by migration 20260402000014
--     — recomputes search_text on the Grapes UPDATE below.
-- =============================================================================


-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 1: Duplicate cleanup
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1a. Remove exact-duplicate rows (same food_name + serving_label),
--     keeping only the earliest-created entry per pair.
--     Catches: Banana (seed ↔ produce), Blueberries (seed ↔ produce).
DELETE FROM public.generic_foods
WHERE id IN (
    SELECT id FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                   PARTITION BY food_name, serving_label
                   ORDER BY created_at ASC
               ) AS rn
        FROM public.generic_foods
    ) dupes
    WHERE rn > 1
);

-- 1b. Remove near-duplicate produce entries that shadow simpler names
--     from earlier seed/expand migrations.

-- "Apple, raw" (produce) duplicates "Apple" (seed) at the same 1 medium (182g)
-- serving. Keep "Apple" (simpler, matches natural search) and "Apple Slices"
-- (distinct serving from produce).
DELETE FROM public.generic_foods WHERE food_name = 'Apple, raw';

-- "Orange, raw" (produce) duplicates "Orange" (seed). Keep "Orange" and the
-- useful "Orange Slices" from produce.
DELETE FROM public.generic_foods WHERE food_name = 'Orange, raw';

-- Seed "Strawberries" labeled "1 cup (152g)" with 11g carbs is less accurate
-- and less descriptive than the produce version "1 cup halves (152g)" with 12g
-- carbs (USDA: 11.67g → rounds to 12). Remove the seed version.
DELETE FROM public.generic_foods
WHERE food_name = 'Strawberries' AND serving_label = '1 cup (152g)';

-- "Pineapple Chunks" (produce) duplicates "Pineapple" (expand) at the same
-- 1 cup / 165g serving. Keep the simpler name.
DELETE FROM public.generic_foods WHERE food_name = 'Pineapple Chunks';

-- Produce "Avocado" at 1/2 medium (68g) duplicates the seed version at
-- ½ medium (75g). Keep the seed version (established, used in suggestions).
DELETE FROM public.generic_foods
WHERE food_name = 'Avocado' AND serving_label = '1/2 medium (68g)';


-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 2: Data fixes
-- ═══════════════════════════════════════════════════════════════════════════════

-- Expand migration has "Grapes" with serving "1 cup (92g)" — incorrect weight.
-- USDA: 1 cup seedless grapes = 151g. The produce migration has the correct
-- entry as "Grapes, red or green" at 151g. Remove the bad 92g entry and
-- normalize the produce name to "Grapes" for simpler searching.
DELETE FROM public.generic_foods
WHERE food_name = 'Grapes' AND serving_label = '1 cup (92g)';

UPDATE public.generic_foods
SET food_name = 'Grapes'
WHERE food_name = 'Grapes, red or green';
