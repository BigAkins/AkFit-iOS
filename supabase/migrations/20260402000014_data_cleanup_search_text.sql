-- =============================================================================
-- Migration: 20260402000014_data_cleanup_search_text
-- Purpose:   Adds the normalized `search_text` column, auto-populate trigger,
--            and trigram GIN index on generic_foods. Enables punctuation-
--            tolerant search: "chick fil a" matches "Chick-fil-A",
--            "mcdonalds" matches "McDonald's", etc.
--
-- The original version of this migration also performed data-only cleanup
-- on seeded rows (removing duplicates, renaming "Grapes, red or green" →
-- "Grapes", fixing a bad serving weight). Those statements moved to
-- supabase/seeds/food/026_data_cleanup.sql so migrations stay schema-only.
--
-- Replay behavior:
--   * Fresh `supabase db reset`: seeds run AFTER migrations, so the
--     populate-existing-rows UPDATE below is a no-op on an empty table.
--     The trigger populates search_text on every subsequent seed insert.
--   * Databases where this migration already ran in its pre-split form:
--     effective row state is identical.
-- =============================================================================


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
