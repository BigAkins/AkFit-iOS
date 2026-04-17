-- =============================================================================
-- Migration: 20260403000002_in_n_out_additions
-- Purpose:   Add officially verified In-N-Out items missing from the original
--            seed (migration 20260402000003).
--
-- Source: In-N-Out Burger official nutrition PDF (January 2026), downloaded
--         from https://www.in-n-out.com/menu/nutrition-info
--         → "Download Nutrition Info" link.
--         Source field = 'in_n_out'; brand = 'In-N-Out'.
--
-- Items added:
--   • Hamburger Protein Style — officially published in the nutrition PDF.
--   • Grilled Cheese — listed on the Not So Secret menu. In-N-Out does NOT
--     publish official nutrition for this item. Values are DERIVED from
--     official Cheeseburger data (remove patty, add 1 extra cheese slice).
--     Marked source = 'estimate' to distinguish from verified items.
--
-- Items SKIPPED (no official nutrition data published):
--   • Hamburger Animal Style — Not So Secret menu, no official numbers.
--   • Cheeseburger Animal Style — same.
--
-- Note: search_text auto-populated via trigger from migration 000014.
-- =============================================================================

INSERT INTO public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
VALUES

-- Official: 210 cal, 14g fat, 12g protein, 9g carbs, 211g serving.
-- Hamburger patty wrapped in lettuce instead of a bun.
('In-N-Out Hamburger Protein Style',
    '1 burger (211g)',  211,  210, 12.0, 9.0, 14.0, 'in_n_out', 'In-N-Out'),

-- ESTIMATED — not in official nutrition PDF.
-- Derived from official Cheeseburger w/ Onion (430 cal, 229g):
--   remove beef patty (~150 cal, 10g F, 14g P, 0g C, 45g)
--   add 1 extra slice American cheese (~70 cal, 5g F, 4g P, 2g C, 20g)
-- Listed on In-N-Out "Not So Secret Menu" page: bun, 2 slices American
-- cheese, lettuce, tomato, spread, with or without onions.
('In-N-Out Grilled Cheese',
    '1 sandwich (204g)',  204,  350, 10.0, 42.0, 16.0, 'estimate', 'In-N-Out');
