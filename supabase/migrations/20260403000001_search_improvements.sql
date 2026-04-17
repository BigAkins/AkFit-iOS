-- =============================================================================
-- Migration: 20260403000001_search_improvements
-- Purpose:   Upgrades the generic_foods search_text trigger to also strip
--            commas (in addition to apostrophes, parens, and hyphens), so
--            commas in food names no longer block substring matches.
--
-- The new generic_foods rows that were bundled into the original version of
-- this migration moved to supabase/seeds/food/028_search_improvements_seed.sql.
--
-- Replay behavior:
--   * Fresh `supabase db reset`: the re-populate UPDATE below is a no-op
--     (seeds haven't run yet). All subsequent inserts use the
--     comma-stripping trigger.
--   * Live databases: the UPDATE reinforces correctness on any pre-existing
--     rows predating the comma-stripping logic.
-- =============================================================================


-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 1: Update search_text normalization to strip commas
-- ═══════════════════════════════════════════════════════════════════════════════

-- Update trigger function to also replace commas with spaces.
CREATE OR REPLACE FUNCTION public.generic_foods_set_search_text()
RETURNS trigger AS $$
BEGIN
    NEW.search_text := trim(regexp_replace(
        translate(
            replace(lower(NEW.food_name), '''', ''),
            '(),-', '    '
        ),
        '\s+', ' ', 'g'
    ));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-populate search_text for all existing rows with the updated logic.
UPDATE public.generic_foods
SET search_text = trim(regexp_replace(
    translate(
        replace(lower(food_name), '''', ''),
        '(),-', '    '
    ),
    '\s+', ' ', 'g'
));
