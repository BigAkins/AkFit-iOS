-- =============================================================================
-- Migration: 20260401000000_generic_foods_expand
-- Purpose:   Expands generic_foods with ~55 additional USDA-aligned entries
--            covering common U.S. foods that were missing from the initial seed
--            and causing searches to fall through to Open Food Facts (noisy).
--
-- Priority additions: bacon, turkey bacon, and other daily staples.
-- Values from USDA FoodData Central (SR Legacy / Foundation Foods).
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source)
values

-- ── Pork & Cured Meats ───────────────────────────────────────────────────────
-- USDA FDC: Bacon, cured, cooked, pan-fried — ~541 kcal/100g cooked
('Bacon, cooked',               '1 slice (8g)',         8,    43,   3.0,  0.1,  3.4, 'usda'),
('Bacon, cooked',               '2 slices (16g)',       16,    87,   5.9,  0.2,  6.7, 'usda'),
('Bacon, cooked',               '3 slices (24g)',       24,   130,   8.9,  0.3, 10.1, 'usda'),
('Bacon, cooked',               '100g',               100,   541,  37.0,  1.4, 42.0, 'usda'),
-- USDA: Canadian-style bacon, cooked — ~163 kcal/100g
('Canadian Bacon, cooked',      '2 slices (47g)',       47,    77,  10.3,  0.4,  3.7, 'usda'),
('Canadian Bacon, cooked',      '100g',               100,   163,  21.9,  0.9,  7.8, 'usda'),
-- Ham: USDA — deli/sliced, cooked
('Ham, deli-sliced',            '2 oz (56g)',           56,    60,   8.6,  0.9,  2.6, 'usda'),
('Ham, deli-sliced',            '100g',               100,   107,  15.4,  1.7,  4.6, 'usda'),
-- Pork chop
('Pork Chop, cooked',           '100g',               100,   210,  28.2,  0.0, 10.5, 'usda'),
('Pork Chop, cooked',           '4 oz (113g)',         113,   237,  31.9,  0.0, 11.9, 'usda'),
-- Breakfast sausage
('Sausage, pork breakfast',     '2 links (57g)',        57,   193,  10.5,  0.7, 16.5, 'usda'),
('Sausage, pork breakfast',     '100g',               100,   339,  18.4,  1.2, 29.0, 'usda'),

-- ── Turkey ───────────────────────────────────────────────────────────────────
-- USDA FDC: Turkey bacon, cooked — ~218 kcal/100g
('Turkey Bacon, cooked',        '1 slice (14g)',        14,    31,   4.1,  0.4,  1.5, 'usda'),
('Turkey Bacon, cooked',        '2 slices (28g)',       28,    61,   8.1,  0.7,  2.9, 'usda'),
-- Ground turkey
('Ground Turkey, cooked',       '100g',               100,   170,  25.0,  0.0,  7.0, 'usda'),
('Ground Turkey, cooked',       '4 oz (113g)',         113,   192,  28.3,  0.0,  7.9, 'usda'),
-- Turkey sausage
('Turkey Sausage, cooked',      '2 oz (56g)',           56,    87,   9.8,  1.0,  4.8, 'usda'),

-- ── Fish ─────────────────────────────────────────────────────────────────────
('Tilapia, cooked',             '100g',               100,   128,  26.2,  0.0,  2.7, 'usda'),
('Tilapia, cooked',             '4 oz (113g)',         113,   145,  29.6,  0.0,  3.1, 'usda'),
('Cod, cooked',                 '100g',               100,   105,  22.8,  0.0,  0.9, 'usda'),
('Cod, cooked',                 '4 oz (113g)',         113,   119,  25.8,  0.0,  1.0, 'usda'),
-- Canned chicken (common for meal prep)
('Chicken Breast, canned',      '3 oz (85g)',           85,   116,  21.3,  0.0,  2.6, 'usda'),
('Chicken Breast, canned',      '100g',               100,   136,  25.0,  0.0,  3.1, 'usda'),

-- ── Dairy & Eggs (additional) ────────────────────────────────────────────────
('Butter',                      '1 tbsp (14g)',         14,   102,   0.1,  0.0, 11.5, 'usda'),
('Butter',                      '100g',               100,   717,   0.9,  0.1, 81.1, 'usda'),
('Cream Cheese',                '2 tbsp (29g)',         29,   101,   1.8,  0.9,  9.9, 'usda'),
('Cream Cheese',                '100g',               100,   350,   6.2,  3.1, 34.3, 'usda'),
('Sour Cream',                  '2 tbsp (29g)',         29,    60,   0.9,  1.2,  5.8, 'usda'),
('Mozzarella',                  '1 oz (28g)',           28,    85,   6.3,  0.6,  6.3, 'usda'),

-- ── Bread & Grains (additional) ──────────────────────────────────────────────
('Bagel, plain',                '1 whole (98g)',        98,   245,   9.9, 48.0,  1.5, 'usda'),
('Bagel, plain',                '½ bagel (49g)',        49,   123,   5.0, 24.0,  0.8, 'usda'),
('English Muffin',              '1 whole (57g)',        57,   132,   4.5, 26.0,  1.0, 'usda'),
('Flour Tortilla',              '1 medium 8" (45g)',    45,   146,   3.8, 25.0,  3.5, 'usda'),
('Flour Tortilla',              '1 small 6" (28g)',     28,    91,   2.4, 15.6,  2.2, 'usda'),
('Corn Tortilla',               '1 small (26g)',        26,    52,   1.4, 10.7,  0.7, 'usda'),

-- ── Vegetables (additional) ──────────────────────────────────────────────────
('Carrots, raw',                '100g',               100,    41,   0.9,  9.6,  0.2, 'usda'),
('Carrots, raw',                '1 medium (61g)',       61,    25,   0.6,  5.8,  0.1, 'usda'),
('Tomato, raw',                 '100g',               100,    18,   0.9,  3.9,  0.2, 'usda'),
('Tomato, raw',                 '1 medium (123g)',     123,    22,   1.1,  4.8,  0.2, 'usda'),
('Cucumber',                    '100g',               100,    15,   0.7,  3.6,  0.1, 'usda'),
('Bell Pepper, raw',            '100g',               100,    20,   0.9,  4.6,  0.2, 'usda'),
('Bell Pepper, raw',            '1 medium (119g)',     119,    24,   1.1,  5.5,  0.2, 'usda'),
('Romaine Lettuce',             '100g',               100,    17,   1.2,  3.3,  0.3, 'usda'),
('Green Beans, cooked',         '100g',               100,    35,   1.9,  7.9,  0.1, 'usda'),
('Green Beans, cooked',         '1 cup (125g)',        125,    44,   2.4,  9.9,  0.1, 'usda'),
('Corn, cooked',                '100g',               100,    96,   3.4, 21.0,  1.5, 'usda'),
('Corn, cooked',                '1 ear (90g)',          90,    86,   3.1, 18.9,  1.4, 'usda'),
('Celery',                      '100g',               100,    16,   0.7,  3.0,  0.2, 'usda'),
('Asparagus, cooked',           '100g',               100,    22,   2.4,  4.1,  0.2, 'usda'),

-- ── Fruits (additional) ──────────────────────────────────────────────────────
('Grapes',                      '1 cup (92g)',          92,    62,   0.6, 15.8,  0.3, 'usda'),
('Grapes',                      '100g',               100,    67,   0.6, 17.2,  0.4, 'usda'),
('Mango',                       '1 cup sliced (165g)', 165,    99,   1.4, 24.7,  0.6, 'usda'),
('Mango',                       '100g',               100,    60,   0.8, 15.0,  0.4, 'usda'),
('Watermelon',                  '2 cups diced (280g)', 280,    84,   1.7, 21.3,  0.4, 'usda'),
('Watermelon',                  '100g',               100,    30,   0.6,  7.6,  0.2, 'usda'),
('Pineapple',                   '1 cup chunks (165g)', 165,    82,   0.9, 21.6,  0.2, 'usda'),
('Pear',                        '1 medium (178g)',     178,   101,   0.6, 27.1,  0.2, 'usda'),
('Peach',                       '1 medium (150g)',     150,    59,   1.4, 14.3,  0.4, 'usda'),

-- ── Beverages ────────────────────────────────────────────────────────────────
('Orange Juice',                '1 cup (248ml)',       248,   112,   1.7, 25.8,  0.5, 'usda'),
('Coffee, black',               '1 cup (240ml)',       240,     2,   0.3,  0.0,  0.0, 'usda'),
('Almond Milk, unsweetened',    '1 cup (240ml)',       240,    39,   1.0,  1.5,  2.5, 'usda');
