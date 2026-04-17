-- =============================================================================
-- Migration: 20260401000007_fast_food_cava
-- Purpose:   Adds CAVA menu items to generic_foods so they appear in the
--            primary Supabase search tier instead of falling through to the
--            noisy Open Food Facts fallback.
--
-- Source: CAVA published nutrition information (official online nutrition
--         calculator). Values reflect standard U.S. menu items as of the
--         time of this migration. Source field = 'cava'; brand = 'CAVA'.
--
-- Structure:
--   Individual components (proteins, bases, dips, toppings) named "CAVA [Item]"
--   for discoverability:
--     - Searching "cava"                → all items (starts-with rank 1)
--     - Searching "cava bowl"           → pre-built bowl entries
--     - Searching "cava chicken"        → chicken protein + chicken bowl
--     - Searching "cava hummus"         → hummus entry
--
--   Pre-built bowls (most common orders):
--   Nutrition = sum of included components at CAVA's standard portions.
--   Base composition: protein + brown rice + hummus + tzatziki +
--   cucumber-tomato salsa + super greens (small amount of romaine).
--   No cheese or falafel added unless specified.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Proteins (~4 oz / 113g serving per CAVA standard) ───────────────────────
('CAVA Grilled Chicken',
    '1 order (~4 oz)',        113,  130, 24.0,  1.0,  4.0, 'cava', 'CAVA'),

-- Harissa Honey Chicken: grilled chicken with harissa and honey glaze —
-- slightly higher carbs than plain grilled chicken
('CAVA Harissa Honey Chicken',
    '1 order (~4 oz)',        113,  190, 21.0, 11.0,  7.0, 'cava', 'CAVA'),

('CAVA Braised Lamb',
    '1 order (~4 oz)',        113,  200, 19.0,  3.0, 13.0, 'cava', 'CAVA'),

-- Falafel (Traditional): chickpea-based, fried — higher carbs and fat
-- CAVA serves ~6 falafel balls per protein portion
('CAVA Falafel',
    '1 order (~6 balls)',     113,  370, 14.0, 40.0, 20.0, 'cava', 'CAVA'),

('CAVA Salmon',
    '1 order (~4 oz)',        113,  230, 25.0,  0.0, 14.0, 'cava', 'CAVA'),

-- ── Bases ─────────────────────────────────────────────────────────────────────
-- CAVA brown rice is cooked with olive oil and lemon — more calories than plain
('CAVA Brown Rice',
    '1 serving (~5 oz)',      145,  180,  4.0, 39.0,  1.0, 'cava', 'CAVA'),

-- Super Greens: arugula, spinach, shredded kale blend
('CAVA Super Greens',
    '1 serving (~4 oz)',      113,   25,  3.0,  3.0,  0.0, 'cava', 'CAVA'),

-- Whole pita (served warm) — useful for pita bowl or side
('CAVA Pita',
    '1 pita (113g)',          113,  260,  8.0, 47.0,  4.0, 'cava', 'CAVA'),

-- ── Dips & Spreads ────────────────────────────────────────────────────────────
-- CAVA includes 2 dips free per bowl; each portion is ~2 oz (57g)
('CAVA Hummus',
    '1 dip serving (2 oz)',    57,   80,  3.0,  8.0,  5.0, 'cava', 'CAVA'),

('CAVA Tzatziki',
    '1 dip serving (2 oz)',    57,   35,  2.0,  2.0,  3.0, 'cava', 'CAVA'),

-- Crazy Feta: whipped feta with jalapeños — bold flavor, moderate fat
('CAVA Crazy Feta',
    '1 dip serving (2 oz)',    57,   90,  3.0,  2.0,  8.0, 'cava', 'CAVA'),

('CAVA Eggplant and Red Pepper',
    '1 dip serving (2 oz)',    57,   45,  1.0,  5.0,  3.0, 'cava', 'CAVA'),

-- ── Toppings ──────────────────────────────────────────────────────────────────
('CAVA Cucumber Tomato Salsa',
    '1 topping (2 oz)',        57,   20,  1.0,  4.0,  0.0, 'cava', 'CAVA'),

('CAVA Fire Roasted Corn',
    '1 topping (2 oz)',        57,   40,  1.0,  8.0,  1.0, 'cava', 'CAVA'),

('CAVA Kalamata Olives',
    '1 topping (1 oz)',        28,   30,  0.0,  2.0,  3.0, 'cava', 'CAVA'),

-- ── Pre-built bowls (most common orders) ─────────────────────────────────────
-- Named "CAVA Bowl, [Protein]" so searching "cava bowl" matches all entries
-- via ilike '%cava bowl%'.
-- Nutrition = sum of components at CAVA standard portions.
-- Base composition per bowl: protein + brown rice + hummus + tzatziki +
-- cucumber-tomato salsa + small super greens (~30g / ~15 cal, ~1g P, ~2g C).

-- Grilled Chicken Bowl (base):
-- 130 + 180 + 80 + 35 + 20 + 15 = 460 cal
-- P: 24+4+3+2+1+0 = 34g | C: 1+39+8+2+4+2 = 56g | F: 4+1+5+3+0+0 = 13g
-- Weight: 113+145+57+57+57+30 = 459g → 460g
('CAVA Bowl, Grilled Chicken',
    'grilled chicken, brown rice, hummus, tzatziki, cucumber-tomato salsa',
    460,  460, 34.0, 56.0, 13.0, 'cava', 'CAVA'),

-- Harissa Honey Chicken Bowl (base):
-- 190 + 180 + 80 + 35 + 20 + 15 = 520 cal
-- P: 21+4+3+2+1+0 = 31g | C: 11+39+8+2+4+2 = 66g | F: 7+1+5+3+0+0 = 16g
('CAVA Bowl, Harissa Honey Chicken',
    'harissa honey chicken, brown rice, hummus, tzatziki, cucumber-tomato salsa',
    460,  520, 31.0, 66.0, 16.0, 'cava', 'CAVA'),

-- Braised Lamb Bowl (base):
-- 200 + 180 + 80 + 35 + 20 + 15 = 530 cal
-- P: 19+4+3+2+1+0 = 29g | C: 3+39+8+2+4+2 = 58g | F: 13+1+5+3+0+0 = 22g
('CAVA Bowl, Braised Lamb',
    'braised lamb, brown rice, hummus, tzatziki, cucumber-tomato salsa',
    460,  530, 29.0, 58.0, 22.0, 'cava', 'CAVA'),

-- Falafel Bowl (base) — higher carb + fat from fried falafel:
-- 370 + 180 + 80 + 35 + 20 + 15 = 700 cal
-- P: 14+4+3+2+1+0 = 24g | C: 40+39+8+2+4+2 = 95g | F: 20+1+5+3+0+0 = 29g
('CAVA Bowl, Falafel',
    'falafel, brown rice, hummus, tzatziki, cucumber-tomato salsa',
    460,  700, 24.0, 95.0, 29.0, 'cava', 'CAVA');
