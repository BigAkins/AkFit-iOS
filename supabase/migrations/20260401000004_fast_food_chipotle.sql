-- =============================================================================
-- Migration: 20260401000004_fast_food_chipotle
-- Purpose:   Adds Chipotle Mexican Grill menu items to generic_foods so they
--            appear in the primary Supabase search tier.
--
-- Source: Chipotle's official online nutrition calculator (published values).
--         Source field = 'chipotle'; brand = 'Chipotle'.
--
-- Structure:
--   Individual ingredients (proteins, rice, beans, toppings, tortilla, chips)
--   Named "Chipotle [Item]" for discoverability:
--     - Searching "chipotle"          → all items (starts-with rank 1)
--     - Searching "chipotle chicken"  → protein + pre-built bowl
--     - Searching "chipotle bowl"     → pre-built bowl configs
--     - Searching "chicken"           → Chipotle Chicken shows alongside generic
--                                       chicken entries (word-match rank 3)
--
--   Pre-built bowls (most common orders):
--   Nutrition = sum of included components at Chipotle's standard portions.
--   Components listed in the serving_label for transparency.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Proteins (~4 oz / 113g serving per Chipotle standard) ────────────────────
('Chipotle Chicken',
    '1 order (~4 oz)',    113,  200, 32.0,  1.0,  7.0, 'chipotle', 'Chipotle'),

('Chipotle Steak',
    '1 order (~4 oz)',    113,  150, 21.0,  1.0,  7.0, 'chipotle', 'Chipotle'),

('Chipotle Barbacoa',
    '1 order (~4 oz)',    113,  170, 24.0,  2.0,  7.0, 'chipotle', 'Chipotle'),

('Chipotle Carnitas',
    '1 order (~4 oz)',    113,  210, 23.0,  1.0, 12.0, 'chipotle', 'Chipotle'),

('Chipotle Sofritas',
    '1 order (~4 oz)',    113,  150,  8.0, 10.0,  9.0, 'chipotle', 'Chipotle'),

-- ── Rice ──────────────────────────────────────────────────────────────────────
-- Chipotle rice is cooked with oil and citrus — more calories than plain rice.
('Chipotle White Rice',
    '1 serving (~½ cup)', 130,  210,  4.0, 40.0,  3.0, 'chipotle', 'Chipotle'),

('Chipotle Brown Rice',
    '1 serving (~½ cup)', 130,  215,  5.0, 40.0,  4.0, 'chipotle', 'Chipotle'),

-- ── Beans ─────────────────────────────────────────────────────────────────────
('Chipotle Black Beans',
    '1 serving (~½ cup)', 120,  130,  8.0, 22.0,  1.0, 'chipotle', 'Chipotle'),

('Chipotle Pinto Beans',
    '1 serving (~½ cup)', 120,  130,  8.0, 23.0,  1.0, 'chipotle', 'Chipotle'),

-- ── Toppings ──────────────────────────────────────────────────────────────────
('Chipotle Fajita Vegetables',
    '1 serving (~3 oz)',   85,   20,  1.0,  4.0,  0.0, 'chipotle', 'Chipotle'),

('Chipotle Pico de Gallo',
    '1 serving (~3 oz)',   85,   25,  1.0,  4.0,  0.0, 'chipotle', 'Chipotle'),

('Chipotle Tomatillo Green Salsa',
    '1 serving (2 oz)',    57,   15,  0.0,  3.0,  0.0, 'chipotle', 'Chipotle'),

('Chipotle Tomatillo Red Salsa',
    '1 serving (2 oz)',    57,   30,  1.0,  4.0,  1.0, 'chipotle', 'Chipotle'),

('Chipotle Guacamole',
    '1 side (3.5 oz)',    105,  230,  2.0,  8.0, 22.0, 'chipotle', 'Chipotle'),
('Chipotle Guacamole, small topping',
    '1 scoop (~2 tbsp)',   42,   90,  1.0,  3.0,  9.0, 'chipotle', 'Chipotle'),

('Chipotle Shredded Cheese',
    '1 serving (1.5 oz)', 42,   110,  7.0,  0.0,  9.0, 'chipotle', 'Chipotle'),

('Chipotle Sour Cream',
    '1 serving (2 oz)',    57,   110,  1.0,  2.0, 10.0, 'chipotle', 'Chipotle'),

('Chipotle Queso Blanco',
    '1 side (2 oz)',       57,    80,  5.0,  2.0,  6.0, 'chipotle', 'Chipotle'),

-- ── Shells / Wraps ────────────────────────────────────────────────────────────
-- Large flour tortilla (burrito-size)
('Chipotle Flour Tortilla',
    '1 burrito tortilla (4 oz)', 120, 320,  9.0, 50.0,  9.0, 'chipotle', 'Chipotle'),

-- Crispy corn taco shell (used for tacos)
('Chipotle Crispy Corn Taco Shell',
    '1 shell (½ oz)',      14,   60,  1.0,  9.0,  3.0, 'chipotle', 'Chipotle'),

-- ── Chips & Dips ─────────────────────────────────────────────────────────────
('Chipotle Chips',
    '1 bag (3.7 oz)',     105,  540,  7.0, 72.0, 27.0, 'chipotle', 'Chipotle'),

('Chipotle Chips and Guacamole',
    '1 order (5.4 oz)',   150,  770, 10.0, 80.0, 49.0, 'chipotle', 'Chipotle'),

('Chipotle Chips and Queso Blanco',
    '1 order (5.7 oz)',   160,  620, 12.0, 74.0, 33.0, 'chipotle', 'Chipotle'),

-- ── Pre-built bowls (most common orders) ─────────────────────────────────────
-- Named "Chipotle Bowl, [Protein]" so searching "chipotle bowl" matches all
-- four entries via ilike '%chipotle bowl%'.
-- Nutrition = sum of components at Chipotle standard portions.
-- Components listed in serving_label for transparency.
-- No sour cream or cheese in the "base" bowls — users log those individually.

-- Chicken Bowl (base): chicken + white rice + black beans + pico
-- 200 + 210 + 130 + 25 = 565 cal | 32+4+8+1 = 45g P | 1+40+22+4 = 67g C | 7+3+1+0 = 11g F
('Chipotle Bowl, Chicken',
    'chicken, white rice, black beans, pico (no cheese/sour cream)',
    448,  565, 45.0, 67.0, 11.0, 'chipotle', 'Chipotle'),

-- Chicken Bowl (with cheese + sour cream)
-- 565 + 110 + 110 = 785 cal | 45+7+1 = 53g P | 67+0+2 = 69g C | 11+9+10 = 30g F
('Chipotle Bowl, Chicken (with Cheese and Sour Cream)',
    'chicken, white rice, black beans, pico, cheese, sour cream',
    548,  785, 53.0, 69.0, 30.0, 'chipotle', 'Chipotle'),

-- Steak Bowl (base): steak + white rice + black beans + pico
-- 150 + 210 + 130 + 25 = 515 cal | 21+4+8+1 = 34g P | 1+40+22+4 = 67g C | 7+3+1+0 = 11g F
('Chipotle Bowl, Steak',
    'steak, white rice, black beans, pico (no cheese/sour cream)',
    448,  515, 34.0, 67.0, 11.0, 'chipotle', 'Chipotle'),

-- Chicken Burrito (with tortilla): tortilla + chicken + white rice + black beans + pico
-- 320 + 200 + 210 + 130 + 25 = 885 cal | 9+32+4+8+1 = 54g P | 50+1+40+22+4 = 117g C | 9+7+3+1+0 = 20g F
('Chipotle Chicken Burrito',
    'flour tortilla, chicken, white rice, black beans, pico (no cheese/sour cream)',
    568,  885, 54.0, 117.0, 20.0, 'chipotle', 'Chipotle'),

-- Veggie Bowl: sofritas + white rice + black beans + fajita veggies + pico
-- 150 + 210 + 130 + 20 + 25 = 535 cal | 8+4+8+1+1 = 22g P | 10+40+22+4+4 = 80g C | 9+3+1+0+0 = 13g F
('Chipotle Bowl, Veggie',
    'sofritas, white rice, black beans, fajita vegetables, pico',
    448,  535, 22.0, 80.0, 13.0, 'chipotle', 'Chipotle');
