-- =============================================================================
-- Migration: 20260401000002_generic_foods_staples
-- Purpose:   Adds ~45 practical everyday U.S. foods missing from the initial
--            seed and expand migrations.
--
-- Priority: items that commonly fall through to Open Food Facts (noisy) because
-- they were absent from generic_foods — taco components, egg preparations,
-- breakfast staples, Mexican food items, snacks, and condiments.
--
-- All values from USDA FoodData Central (SR Legacy / Foundation Foods),
-- standardised to practical U.S. serving sizes.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source)
values

-- ── Ground Beef (80/20) ───────────────────────────────────────────────────────
-- More commonly used than 90% lean; needed for taco meat, burgers, etc.
-- USDA FDC: Ground beef, 80% lean / 20% fat, pan-browned
('Ground Beef, 80% lean, cooked',  '100g',           100,  254, 17.3,  0.0, 20.0, 'usda'),
('Ground Beef, 80% lean, cooked',  '4 oz (113g)',     113,  287, 19.6,  0.0, 22.6, 'usda'),
('Ground Beef, 80% lean, cooked',  '3 oz (85g)',       85,  216, 14.7,  0.0, 17.0, 'usda'),

-- ── Taco / Mexican ────────────────────────────────────────────────────────────
-- Taco meat: 80/20 ground beef seasoned with standard taco seasoning packet.
-- Seasoning adds ~4g carbs and negligible calories per serving.
('Taco Meat, seasoned ground beef', '3 oz (85g)',      85,  240, 15.0,  4.0, 17.0, 'usda'),
('Taco Meat, seasoned ground beef', '4 oz (113g)',    113,  320, 20.0,  5.0, 23.0, 'usda'),

-- Taco shells
('Taco Shell, hard corn',          '1 shell (20g)',    20,   97,  1.7, 12.0,  4.7, 'usda'),
('Taco Shell, hard corn',          '2 shells (40g)',   40,  194,  3.4, 24.0,  9.4, 'usda'),

-- Pinto beans — common in burritos and tacos; black beans already in seed
-- USDA: Beans, pinto, cooked, boiled without salt
('Pinto Beans, cooked',            '100g',            100,  143,  9.0, 26.7,  0.7, 'usda'),
('Pinto Beans, cooked',            '½ cup (86g)',      86,  122,  7.7, 22.9,  0.6, 'usda'),

-- Refried beans (canned) — extremely common for burritos and tacos
-- USDA: Beans, refried, canned
('Refried Beans, canned',          '½ cup (124g)',    124,  118,  6.9, 19.0,  1.8, 'usda'),
('Refried Beans, canned',          '1 cup (248g)',    248,  237, 13.8, 38.0,  3.6, 'usda'),

-- Guacamole (store-bought / homemade standard)
-- USDA: Guacamole, ready-to-eat
('Guacamole',                      '2 tbsp (30g)',     30,   50,  0.7,  2.9,  4.4, 'usda'),
('Guacamole',                      '¼ cup (60g)',      60,  100,  1.4,  5.8,  8.8, 'usda'),

-- Salsa, fresh/mild (pico de gallo style)
-- USDA: Salsa, ready-to-serve
('Salsa',                          '2 tbsp (30g)',     30,   10,  0.5,  2.2,  0.1, 'usda'),
('Salsa',                          '¼ cup (60g)',      60,   20,  1.0,  4.4,  0.2, 'usda'),

-- ── Egg preparations ─────────────────────────────────────────────────────────
-- Scrambled eggs (cooked with minimal butter / cooking spray)
-- USDA: Egg, whole, cooked, scrambled
('Scrambled Eggs, 2 large',        '1 serving (94g)',  94,  149, 10.1,  2.1, 10.8, 'usda'),
('Scrambled Eggs, 3 large',        '1 serving (141g)',141,  224, 15.1,  3.2, 16.2, 'usda'),

-- Hard-boiled eggs
-- USDA: Egg, whole, cooked, hard-boiled
('Egg, hard-boiled',               '1 large (50g)',    50,   78,  6.3,  0.6,  5.3, 'usda'),
('Egg, hard-boiled',               '2 large (100g)',  100,  155, 12.6,  1.1, 10.6, 'usda'),

-- ── Breakfast staples ─────────────────────────────────────────────────────────
-- Oatmeal cooked (water, no toppings) — dry oats already in seed
-- USDA: Cereals, oats, regular and quick and instant, unenriched, cooked with water
('Oatmeal, cooked',                '1 cup (234g)',    234,  166,  5.9, 28.1,  3.3, 'usda'),
('Oatmeal, cooked',                '½ cup (117g)',    117,   83,  3.0, 14.1,  1.7, 'usda'),

-- Pancakes, plain (homemade or Bisquick style)
-- USDA: Pancakes, plain, prepared from recipe
('Pancakes, plain',                '2 medium (76g)',   76,  186,  4.8, 26.0,  7.4, 'usda'),
('Pancakes, plain',                '3 medium (114g)', 114,  279,  7.2, 39.0, 11.1, 'usda'),

-- Mashed potatoes (whole milk, small amount of butter — basic home-prep)
-- USDA: Potatoes, mashed, home-prepared, whole milk and butter added
('Mashed Potatoes',                '½ cup (105g)',    105,  148,  2.4, 19.5,  6.3, 'usda'),
('Mashed Potatoes',                '1 cup (210g)',    210,  296,  4.8, 39.0, 12.5, 'usda'),

-- ── Snacks & Fast-casual ─────────────────────────────────────────────────────
-- Tortilla chips (plain salted)
-- USDA: Snacks, tortilla chips, plain
('Tortilla Chips',                 '1 oz (28g)',       28,  137,  2.0, 18.3,  6.5, 'usda'),
('Tortilla Chips',                 '2 oz (56g)',       56,  274,  4.0, 36.6, 13.0, 'usda'),

-- Generic restaurant-style french fries (fried in oil; McDonald's fries added separately)
-- USDA: Fast foods, potato, french fried in vegetable oil
('French Fries',                   '1 small order (71g)',  71,  222,  2.7, 29.1,  9.8, 'usda'),
('French Fries',                   '1 medium order (117g)',117, 366,  4.5, 48.0, 16.1, 'usda'),
('French Fries',                   '1 large order (177g)', 177, 553,  6.8, 72.5, 24.4, 'usda'),

-- Pizza, cheese (generic 14" pie slice)
-- USDA: Fast foods, pizza chain, 14" pizza, cheese topping, regular crust
('Pizza, cheese',                  '1 slice (107g)',  107,  272, 12.3, 33.6,  9.6, 'usda'),
('Pizza, cheese',                  '2 slices (214g)', 214,  544, 24.6, 67.2, 19.2, 'usda'),

-- ── Deli / Processed meats ────────────────────────────────────────────────────
-- Hot dog — beef frank (no bun)
-- USDA: Frankfurter, beef
('Hot Dog, beef frank',            '1 frank (57g)',    57,  186,  6.5,  1.9, 17.4, 'usda'),
('Hot Dog in bun',                 '1 with bun (100g)',100,  298, 10.4, 22.7, 19.0, 'usda'),

-- Pepperoni (common pizza topping / snack)
-- USDA: Pepperoni, beef and pork
('Pepperoni, sliced',              '1 oz (28g)',       28,  138,  5.4,  0.5, 12.4, 'usda'),
('Pepperoni, sliced',              '5 slices (14g)',   14,   69,  2.7,  0.2,  6.2, 'usda'),

-- String cheese (convenient protein snack)
-- USDA: Cheese, mozzarella, part skim milk (string cheese format = same nutrition)
('String Cheese',                  '1 stick (28g)',    28,   80,  7.0,  1.0,  6.0, 'usda'),

-- ── Condiments ────────────────────────────────────────────────────────────────
-- Mayonnaise — commonly tracked
-- USDA: Salad dressing, mayonnaise, regular
('Mayonnaise',                     '1 tbsp (14g)',     14,   94,  0.1,  0.1, 10.3, 'usda'),
('Mayonnaise',                     '2 tbsp (28g)',     28,  188,  0.3,  0.2, 20.6, 'usda'),

-- Ketchup
-- USDA: Catsup
('Ketchup',                        '1 tbsp (17g)',     17,   19,  0.3,  5.0,  0.0, 'usda'),

-- Mustard (yellow)
('Mustard, yellow',                '1 tbsp (16g)',     16,    9,  0.6,  1.0,  0.5, 'usda'),

-- Soy sauce — common in Asian cooking
-- USDA: Soy sauce made from soy (tamari)
('Soy Sauce',                      '1 tbsp (18g)',     18,   11,  1.9,  1.0,  0.0, 'usda'),

-- ── Additional protein foods ─────────────────────────────────────────────────
-- Rotisserie chicken breast (common ready-to-eat option, skin-on)
-- USDA: Chicken, broilers or fryers, breast, meat and skin, roasted
('Chicken, rotisserie breast',     '3 oz (85g)',       85,  145, 24.9,  0.0,  4.3, 'usda'),
('Chicken, rotisserie breast',     '100g',            100,  170, 29.3,  0.0,  5.1, 'usda'),

-- Chicken drumstick (bone-in, skin-on, roasted) — common at cookouts
-- USDA: Chicken, broilers or fryers, drumstick, meat and skin, roasted
('Chicken Drumstick, roasted',     '1 medium (52g)',   52,   112, 14.1,  0.0,  6.2, 'usda'),
('Chicken Drumstick, roasted',     '100g',            100,  216, 27.1,  0.0, 11.9, 'usda');
