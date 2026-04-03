-- =============================================================================
-- Migration: 20260402000014_data_cleanup_search_text
-- Purpose:   Data quality cleanup + search_text column for better partial
--            matching on branded names with hyphens and apostrophes.
--
-- Changes:
--   1. Remove exact and near-duplicate rows across migration waves
--   2. Fix incorrect serving weight for Grapes
--   3. Normalize "Grapes, red or green" → "Grapes"
--   4. Add search_text column (normalized food_name) with auto-populate
--      trigger and trigram GIN index
--
-- Rationale:
--   The current search uses ilike('%query%') on food_name. This fails when
--   users type "chick fil a" (no hyphens) or "mcdonalds" (no apostrophe)
--   because "Chick-fil-A" and "McDonald's" contain punctuation the user
--   omits. search_text stores a cleaned version: apostrophes removed,
--   hyphens replaced with spaces, lowercased. Searching against search_text
--   with a similarly-normalized query resolves these mismatches.
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


-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 3: Add search_text column for normalized partial matching
-- ═══════════════════════════════════════════════════════════════════════════════

-- search_text stores a normalized, search-friendly version of food_name:
--   • lowercased
--   • apostrophes removed     ("McDonald's" → "mcdonalds")
--   • hyphens → spaces        ("Chick-fil-A" → "chick fil a")
--   • parentheses removed
--   • whitespace collapsed
--
-- Paired with the same normalization on the user's query in the iOS client,
-- this lets "chick fil a", "in n out", "mcdonalds" etc. match branded items
-- whose display names use hyphens and apostrophes.

ALTER TABLE public.generic_foods
    ADD COLUMN IF NOT EXISTS search_text text;

-- Populate for all existing rows.
UPDATE public.generic_foods
SET search_text = trim(regexp_replace(
    translate(
        replace(lower(food_name), '''', ''),
        '()-', '   '
    ),
    '\s+', ' ', 'g'
));

-- Make NOT NULL now that every row is populated.
ALTER TABLE public.generic_foods
    ALTER COLUMN search_text SET NOT NULL;

ALTER TABLE public.generic_foods
    ALTER COLUMN search_text SET DEFAULT '';

-- Auto-populate on future inserts and food_name changes.
CREATE OR REPLACE FUNCTION public.generic_foods_set_search_text()
RETURNS trigger AS $$
BEGIN
    NEW.search_text := trim(regexp_replace(
        translate(
            replace(lower(NEW.food_name), '''', ''),
            '()-', '   '
        ),
        '\s+', ' ', 'g'
    ));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS generic_foods_search_text_trigger ON public.generic_foods;
CREATE TRIGGER generic_foods_search_text_trigger
    BEFORE INSERT OR UPDATE OF food_name ON public.generic_foods
    FOR EACH ROW
    EXECUTE FUNCTION public.generic_foods_set_search_text();

-- Trigram GIN index for fast ilike('%...%') queries on search_text.
CREATE INDEX IF NOT EXISTS generic_foods_search_text_trgm_idx
    ON public.generic_foods
    USING gin (search_text gin_trgm_ops);
