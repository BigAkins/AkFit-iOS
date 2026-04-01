-- =============================================================================
-- Migration: 20260401000008_fast_food_qdoba
-- Purpose:   Adds QDOBA Mexican Eats menu items to generic_foods so they
--            appear in the primary Supabase search tier instead of falling
--            through to the noisy Open Food Facts fallback.
--
-- Source: QDOBA USA published nutrition information (official menu data).
--         Values reflect standard U.S. menu items as of the time of this
--         migration. Source field = 'qdoba'; brand = 'QDOBA'.
--
-- Key differentiator: QDOBA includes queso at no extra charge — pre-built
-- combos here include queso in the base to reflect a typical real-world order.
--
-- Structure:
--   Individual components (proteins, bases, toppings) named "QDOBA [Item]"
--   for discoverability:
--     - Searching "qdoba"              → all items (starts-with rank 1)
--     - Searching "qdoba burrito"      → burrito + pre-built burrito entries
--     - Searching "qdoba bowl"         → bowl pre-built entries
--     - Searching "qdoba chicken"      → chicken protein + chicken combos
--
--   Pre-built combos:
--   Nutrition = sum of included components at QDOBA's standard portions.
--   Math shown in comments for auditability.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Proteins (~4 oz / 113g serving per QDOBA standard) ──────────────────────
('QDOBA Grilled Adobo Chicken',
    '1 order (~4 oz)',        113,  180, 28.0,  4.0,  5.0, 'qdoba', 'QDOBA'),

('QDOBA Grilled Adobo Steak',
    '1 order (~4 oz)',        113,  200, 24.0,  3.0, 11.0, 'qdoba', 'QDOBA'),

('QDOBA Seasoned Ground Beef',
    '1 order (~4 oz)',        113,  230, 21.0,  3.0, 15.0, 'qdoba', 'QDOBA'),

('QDOBA Pulled Pork',
    '1 order (~4 oz)',        113,  210, 23.0,  2.0, 12.0, 'qdoba', 'QDOBA'),

-- ── Bases ─────────────────────────────────────────────────────────────────────
-- QDOBA cilantro lime rice is cooked with oil — more calories than plain rice
('QDOBA Cilantro Lime Rice',
    '1 serving (~4.5 oz)',    130,  210,  4.0, 43.0,  2.0, 'qdoba', 'QDOBA'),

('QDOBA Black Beans',
    '1 serving (~4 oz)',      113,  120,  7.0, 21.0,  1.0, 'qdoba', 'QDOBA'),

('QDOBA Pinto Beans',
    '1 serving (~4 oz)',      113,  120,  7.0, 22.0,  1.0, 'qdoba', 'QDOBA'),

-- ── Queso, Salsas & Toppings ──────────────────────────────────────────────────
-- QDOBA's signature 3-Cheese Queso is included free in burritos and bowls
('QDOBA 3-Cheese Queso',
    '1 serving (2 oz)',        57,  120,  5.0,  3.0, 10.0, 'qdoba', 'QDOBA'),

('QDOBA Guacamole',
    '1 serving (3 oz)',        85,  150,  2.0,  8.0, 13.0, 'qdoba', 'QDOBA'),

('QDOBA Pico de Gallo',
    '1 serving (2 oz)',        57,   20,  1.0,  4.0,  0.0, 'qdoba', 'QDOBA'),

('QDOBA Shredded Cheese',
    '1 serving (1.5 oz)',      42,  100,  6.0,  0.0,  8.0, 'qdoba', 'QDOBA'),

('QDOBA Sour Cream',
    '1 serving (1 oz)',        28,   60,  1.0,  2.0,  5.0, 'qdoba', 'QDOBA'),

('QDOBA Salsa Roja',
    '1 serving (2 oz)',        57,   25,  1.0,  5.0,  0.0, 'qdoba', 'QDOBA'),

-- ── Tortilla ──────────────────────────────────────────────────────────────────
('QDOBA Flour Tortilla',
    '1 large burrito tortilla (120g)', 120, 330,  9.0, 55.0,  9.0, 'qdoba', 'QDOBA'),

-- ── Pre-built combos (most common orders) ────────────────────────────────────
-- Named so searching "qdoba burrito" or "qdoba bowl" surfaces these entries.
-- QDOBA's free queso is included in the base combo to reflect real ordering.
-- Math shown for auditability.

-- Chicken Burrito (with queso):
-- tortilla + chicken + rice + black beans + queso + pico
-- 330 + 180 + 210 + 120 + 120 + 20 = 980 cal
-- P: 9+28+4+7+5+1 = 54g | C: 55+4+43+21+3+4 = 130g | F: 9+5+2+1+10+0 = 27g
-- Weight: 120+113+130+113+57+57 = 590g
('QDOBA Burrito, Chicken',
    'flour tortilla, chicken, cilantro lime rice, black beans, queso, pico de gallo',
    590,  980, 54.0, 130.0, 27.0, 'qdoba', 'QDOBA'),

-- Steak Burrito (with queso):
-- tortilla + steak + rice + black beans + queso + pico
-- 330 + 200 + 210 + 120 + 120 + 20 = 1000 cal
-- P: 9+24+4+7+5+1 = 50g | C: 55+3+43+21+3+4 = 129g | F: 9+11+2+1+10+0 = 33g
('QDOBA Burrito, Steak',
    'flour tortilla, steak, cilantro lime rice, black beans, queso, pico de gallo',
    590, 1000, 50.0, 129.0, 33.0, 'qdoba', 'QDOBA'),

-- Chicken Bowl (with queso): chicken + rice + black beans + queso + pico
-- 180 + 210 + 120 + 120 + 20 = 650 cal
-- P: 28+4+7+5+1 = 45g | C: 4+43+21+3+4 = 75g | F: 5+2+1+10+0 = 18g
-- Weight: 113+130+113+57+57 = 470g
('QDOBA Bowl, Chicken',
    'chicken, cilantro lime rice, black beans, queso, pico de gallo (no tortilla)',
    470,  650, 45.0, 75.0, 18.0, 'qdoba', 'QDOBA'),

-- Steak Bowl (with queso):
-- 200 + 210 + 120 + 120 + 20 = 670 cal
-- P: 24+4+7+5+1 = 41g | C: 3+43+21+3+4 = 74g | F: 11+2+1+10+0 = 24g
('QDOBA Bowl, Steak',
    'steak, cilantro lime rice, black beans, queso, pico de gallo (no tortilla)',
    470,  670, 41.0, 74.0, 24.0, 'qdoba', 'QDOBA'),

-- Ground Beef Bowl (with queso):
-- 230 + 210 + 120 + 120 + 20 = 700 cal
-- P: 21+4+7+5+1 = 38g | C: 3+43+21+3+4 = 74g | F: 15+2+1+10+0 = 28g
('QDOBA Bowl, Ground Beef',
    'ground beef, cilantro lime rice, black beans, queso, pico de gallo (no tortilla)',
    470,  700, 38.0, 74.0, 28.0, 'qdoba', 'QDOBA');
