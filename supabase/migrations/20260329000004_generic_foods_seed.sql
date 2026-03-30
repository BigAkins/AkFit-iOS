-- =============================================================================
-- Migration: 20260329000004_generic_foods_seed
-- Purpose:   Seeds generic_foods with ~35 USDA FoodData Central-aligned values
--            covering the most commonly tracked items for body-composition goals.
--
-- Values are per the declared serving_label / serving_weight_g.
-- Sources: USDA FoodData Central (SR Legacy / Foundation Foods), standardised
-- to practical serving sizes used in everyday nutrition tracking.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source)
values

-- ── Poultry ──────────────────────────────────────────────────────────────────
('Chicken Breast, cooked',      '100g',              100,    165,  31.0,   0.0,  3.6, 'usda'),
('Chicken Breast, cooked',      '4 oz (113g)',        113,    186,  35.0,   0.0,  4.1, 'usda'),
('Chicken Breast, cooked',      '6 oz (170g)',        170,    280,  52.5,   0.0,  6.1, 'usda'),
('Chicken Thigh, cooked',       '100g',              100,    209,  26.0,   0.0, 10.9, 'usda'),
('Turkey Breast, sliced',       '2 oz (56g)',          56,     59,  12.0,   0.5,  0.7, 'usda'),

-- ── Beef ─────────────────────────────────────────────────────────────────────
('Ground Beef, 90% lean',       '100g',              100,    176,  20.0,   0.0, 10.0, 'usda'),
('Ground Beef, 90% lean',       '4 oz (113g)',        113,    199,  22.6,   0.0, 11.3, 'usda'),
('Steak, sirloin, cooked',      '100g',              100,    207,  26.0,   0.0, 11.0, 'usda'),

-- ── Seafood ──────────────────────────────────────────────────────────────────
('Salmon, cooked',              '100g',              100,    208,  28.0,   0.0, 10.0, 'usda'),
('Salmon, cooked',              '4 oz (113g)',        113,    235,  31.6,   0.0, 11.3, 'usda'),
('Tuna, canned in water',       '100g',              100,    109,  25.0,   0.0,  0.5, 'usda'),
('Tuna, canned in water',       '3 oz (85g)',          85,     93,  21.3,   0.0,  0.4, 'usda'),
('Shrimp, cooked',              '100g',              100,     99,  24.0,   0.0,  0.3, 'usda'),

-- ── Eggs & Dairy ─────────────────────────────────────────────────────────────
('Egg, whole',                  '1 large (50g)',       50,     72,   6.3,   0.4,  5.0, 'usda'),
('Egg, whole',                  '2 large (100g)',     100,    143,  12.6,   0.7, 10.0, 'usda'),
('Egg White',                   '1 large (33g)',       33,     17,   3.6,   0.2,  0.1, 'usda'),
('Greek Yogurt, plain nonfat',  '100g',              100,     59,  10.0,   3.6,  0.4, 'usda'),
('Greek Yogurt, plain nonfat',  '¾ cup (170g)',       170,    100,  17.0,   6.1,  0.7, 'usda'),
('Cottage Cheese',              '100g',              100,     98,  11.0,   3.4,  4.3, 'usda'),
('Cottage Cheese',              '½ cup (113g)',       113,    111,  12.4,   3.8,  4.9, 'usda'),
('Cheddar Cheese',              '1 oz (28g)',          28,    113,   7.0,   0.4,  9.3, 'usda'),
('Milk, whole',                 '1 cup (244ml)',      244,    149,   8.0,  12.0,  8.0, 'usda'),
('Milk, 2%',                    '1 cup (244ml)',      244,    122,   8.1,  11.7,  4.8, 'usda'),
('Milk, skim',                  '1 cup (244ml)',      244,     83,   8.2,  12.2,  0.2, 'usda'),

-- ── Grains ───────────────────────────────────────────────────────────────────
('Oats, rolled (dry)',          '40g (½ cup)',         40,    154,   5.4,  26.0,  2.8, 'usda'),
('White Rice, cooked',          '100g',              100,    130,   2.7,  28.0,  0.3, 'usda'),
('White Rice, cooked',          '1 cup (186g)',       186,    242,   5.0,  53.2,  0.6, 'usda'),
('Brown Rice, cooked',          '100g',              100,    112,   2.6,  23.0,  0.9, 'usda'),
('Pasta, cooked',               '100g',              100,    131,   5.0,  25.0,  1.1, 'usda'),
('Pasta, cooked',               '1 cup (140g)',       140,    183,   7.0,  35.0,  1.5, 'usda'),
('Whole Wheat Bread',           '1 slice (28g)',       28,     69,   3.6,  12.0,  1.0, 'usda'),
('White Bread',                 '1 slice (25g)',       25,     67,   2.0,  13.0,  0.9, 'usda'),
('Potato, baked',               '100g',              100,     93,   2.5,  21.0,  0.1, 'usda'),
('Sweet Potato, baked',         '100g',              100,     90,   2.0,  21.0,  0.1, 'usda'),

-- ── Nuts, Seeds & Fats ───────────────────────────────────────────────────────
('Peanut Butter',               '2 tbsp (32g)',        32,    191,   7.0,   7.0, 16.0, 'usda'),
('Almond Butter',               '2 tbsp (32g)',        32,    196,   7.0,   6.0, 18.0, 'usda'),
('Almonds',                     '1 oz (28g)',          28,    164,   6.0,   6.0, 14.0, 'usda'),
('Walnuts',                     '1 oz (28g)',          28,    185,   4.3,   4.0, 18.5, 'usda'),
('Olive Oil',                   '1 tbsp (14g)',        14,    119,   0.0,   0.0, 13.5, 'usda'),
('Avocado',                     '½ medium (75g)',      75,    120,   1.5,   6.4, 11.0, 'usda'),

-- ── Legumes ──────────────────────────────────────────────────────────────────
('Lentils, cooked',             '100g',              100,    116,   9.0,  20.0,  0.4, 'usda'),
('Black Beans, cooked',         '100g',              100,    132,   8.9,  24.0,  0.5, 'usda'),
('Chickpeas, cooked',           '100g',              100,    164,   8.9,  27.0,  2.6, 'usda'),

-- ── Fruit ────────────────────────────────────────────────────────────────────
('Banana',                      '1 medium (118g)',    118,    105,   1.3,  27.0,  0.4, 'usda'),
('Apple',                       '1 medium (182g)',    182,     95,   0.5,  25.0,  0.3, 'usda'),
('Orange',                      '1 medium (131g)',    131,     62,   1.2,  15.0,  0.2, 'usda'),
('Blueberries',                 '1 cup (148g)',       148,     84,   1.1,  21.0,  0.5, 'usda'),
('Strawberries',                '1 cup (152g)',       152,     49,   1.0,  11.0,  0.5, 'usda'),

-- ── Vegetables ───────────────────────────────────────────────────────────────
('Broccoli',                    '100g',              100,     34,   2.8,   7.0,  0.4, 'usda'),
('Spinach',                     '100g',              100,     23,   2.9,   3.6,  0.4, 'usda'),
('Broccoli',                    '1 cup chopped (91g)', 91,     31,   2.5,   6.0,  0.3, 'usda'),

-- ── Supplements ──────────────────────────────────────────────────────────────
('Whey Protein Powder',         '1 scoop (30g)',       30,    120,  24.0,   3.0,  1.5, 'usda');
