-- =============================================================================
-- Migration: 20260403000003_in_n_out_corrections
-- Purpose:   Correct In-N-Out nutrition values to match the official January
--            2026 nutrition PDF from https://www.in-n-out.com/menu/nutrition-info
--
-- The original seed (migration 20260402000003) used values from an older or
-- third-party source. Every verifiable item had incorrect calories, fat,
-- protein, carbs, and/or serving weights. This migration corrects all 9
-- items that appear in the official PDF.
--
-- Items NOT corrected (no official data to correct against):
--   • In-N-Out 3x3 (Triple Meat Triple Cheese) — not in official PDF
--   • In-N-Out Double-Double Animal Style — not in official PDF
--   • In-N-Out Animal Style Fries — not in official PDF
--   These 3 items are left as-is pending official verification.
--
-- Source: In-N-Out Burger official nutrition PDF (January 2026).
-- =============================================================================


-- ── Burgers ─────────────────────────────────────────────────────────────────

-- Hamburger w/ Onion: was 390 cal / 243g, official is 360 cal / 209g
UPDATE public.generic_foods
SET calories = 360, protein_g = 16.0, carbs_g = 38.0, fat_g = 16.0,
    serving_weight_g = 209, serving_label = '1 burger (209g)'
WHERE food_name = 'In-N-Out Hamburger'
  AND serving_label = '1 burger (243g)';

-- Cheeseburger w/ Onion: was 480 cal / 268g, official is 430 cal / 229g
UPDATE public.generic_foods
SET calories = 430, protein_g = 20.0, carbs_g = 40.0, fat_g = 21.0,
    serving_weight_g = 229, serving_label = '1 burger (229g)'
WHERE food_name = 'In-N-Out Cheeseburger'
  AND serving_label = '1 burger (268g)';

-- Double-Double w/ Onion: was 670 cal / 330g, official is 610 cal / 287g
UPDATE public.generic_foods
SET calories = 610, protein_g = 34.0, carbs_g = 42.0, fat_g = 34.0,
    serving_weight_g = 287, serving_label = '1 burger (287g)'
WHERE food_name = 'In-N-Out Double-Double'
  AND serving_label = '1 burger (330g)';


-- ── Protein Style ───────────────────────────────────────────────────────────

-- Cheeseburger Protein Style: was 330 cal / 243g, official is 280 cal / 231g
UPDATE public.generic_foods
SET calories = 280, protein_g = 16.0, carbs_g = 11.0, fat_g = 19.0,
    serving_weight_g = 231, serving_label = '1 burger (231g)'
WHERE food_name = 'In-N-Out Cheeseburger Protein Style'
  AND serving_label = '1 burger (243g)';

-- Double-Double Protein Style: was 520 cal / 305g, official is 460 cal / 289g
UPDATE public.generic_foods
SET calories = 460, protein_g = 30.0, carbs_g = 12.0, fat_g = 32.0,
    serving_weight_g = 289, serving_label = '1 burger (289g)'
WHERE food_name = 'In-N-Out Double-Double Protein Style'
  AND serving_label = '1 burger (305g)';


-- ── Fries ───────────────────────────────────────────────────────────────────

-- French Fries: was 395 cal, official is 360 cal
UPDATE public.generic_foods
SET calories = 360, protein_g = 6.0, carbs_g = 49.0, fat_g = 15.0
WHERE food_name = 'In-N-Out French Fries'
  AND serving_label = '1 order (125g)';


-- ── Shakes ──────────────────────────────────────────────────────────────────
-- Official PDF lists shakes as "15oz." without gram weight.
-- Keeping existing serving_label format with 15oz noted.

-- Chocolate Shake: was 590/29F/9P/72C, official is 610/30F/16P/74C
UPDATE public.generic_foods
SET calories = 610, protein_g = 16.0, carbs_g = 74.0, fat_g = 30.0,
    serving_label = '1 shake (15oz)'
WHERE food_name = 'In-N-Out Chocolate Shake'
  AND serving_label = '1 shake (425g)';

-- Vanilla Shake: was 580/31F/9P/67C, official is 590/31F/16P/66C
UPDATE public.generic_foods
SET calories = 590, protein_g = 16.0, carbs_g = 66.0, fat_g = 31.0,
    serving_label = '1 shake (15oz)'
WHERE food_name = 'In-N-Out Vanilla Shake'
  AND serving_label = '1 shake (425g)';

-- Strawberry Shake: was 590/29F/8P/72C, official is 610/30F/15P/74C
UPDATE public.generic_foods
SET calories = 610, protein_g = 15.0, carbs_g = 74.0, fat_g = 30.0,
    serving_label = '1 shake (15oz)'
WHERE food_name = 'In-N-Out Strawberry Shake'
  AND serving_label = '1 shake (425g)';
