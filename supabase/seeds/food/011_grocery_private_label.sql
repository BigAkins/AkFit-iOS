-- =============================================================================
-- Migration: 20260401000012_grocery_private_label
-- Purpose:   Adds curated branded grocery products from Trader Joe's,
--            Whole Foods 365, and Great Value (Walmart) to generic_foods.
--            These are specific products users search by brand name or that
--            have distinctive nutritional profiles not well-served by generics.
--
-- Sources: Official product nutrition facts from each brand's published data.
--   Trader Joe's  — traderjoes.com product pages + in-store packaging
--   Whole Foods 365 — wholefoodsmarket.com + 365 brand packaging
--   Great Value     — walmart.com product pages + store packaging
--
-- Naming convention: "[Brand] [Product Name]"
--   Searching "trader joe's" → prefix match, all TJ's items surface first
--   Searching "mandarin orange chicken" → substring match
--   Searching "cauliflower gnocchi" → word-prefix/substring match
--   Searching "great value" → prefix match, all GV items surface first
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ══════════════════════════════════════════════════════════════════════════════
-- TRADER JOE'S
-- ══════════════════════════════════════════════════════════════════════════════

-- Frozen entrées
-- Per official TJ's label: 320 kcal / 140g (~¾ cup heated, ~5–6 pieces)
('Trader Joe''s Mandarin Orange Chicken',
    '¾ cup heated (140g)',     140,  320, 13.0, 43.0, 11.0,
    'trader_joes', 'Trader Joe''s'),

-- Per official TJ's label: 140 kcal / 140g (¾ cup frozen)
-- Very popular diet-friendly pasta alternative
('Trader Joe''s Cauliflower Gnocchi',
    '¾ cup frozen (140g)',     140,  140,  4.0, 27.0,  2.5,
    'trader_joes', 'Trader Joe''s'),

-- Per official TJ's label: ~340 kcal for the full single-serve package (283g)
-- Values reflect current packaging; product reformulations may occur
('Trader Joe''s Chicken Tikka Masala',
    '1 package (283g)',        283,  340, 25.0, 34.0, 12.0,
    'trader_joes', 'Trader Joe''s'),

-- Condiments & spreads
-- Per official TJ's label: 180 kcal / 2 tbsp (34g)
-- Speculoos cookie spread — signature TJ's product with no generic equivalent
('Trader Joe''s Cookie Butter',
    '2 tbsp (34g)',             34,  180,  2.0, 22.0,  9.0,
    'trader_joes', 'Trader Joe''s'),

-- Per official TJ's label: 70 kcal / ½ cup (123g)
('Trader Joe''s Organic Tomato Basil Marinara Sauce',
    '½ cup (123g)',            123,   70,  2.0, 11.0,  2.0,
    'trader_joes', 'Trader Joe''s'),

-- Snacks
-- Per official TJ's label: 150 kcal / 1 oz (28g) — about 8 chips
('Trader Joe''s Chili Lime Rolled Corn Tortilla Chips',
    '1 oz (28g)',               28,  150,  2.0, 19.0,  7.0,
    'trader_joes', 'Trader Joe''s'),

-- ══════════════════════════════════════════════════════════════════════════════
-- WHOLE FOODS 365
-- ══════════════════════════════════════════════════════════════════════════════

-- Dairy & protein
-- Per 365 label: 90 kcal / 2/3 cup (170g); higher protein than many generic
-- nonfat Greek yogurts, making brand-specific tracking useful
('365 Organic Nonfat Plain Greek Yogurt',
    '2/3 cup (170g)',          170,   90, 18.0,  7.0,  0.0,
    'whole_foods_365', '365 by Whole Foods Market'),

-- Pantry staples
-- Per 365 label: 190 kcal / 2 tbsp (32g)
('365 Organic Creamy Peanut Butter',
    '2 tbsp (32g)',             32,  190,  7.0,  7.0, 16.0,
    'whole_foods_365', '365 by Whole Foods Market'),

-- Per 365 label: 150 kcal / ½ cup dry (40g)
-- Added for brand-specific search; values match USDA rolled oats
('365 Organic Rolled Oats',
    '½ cup dry (40g)',          40,  150,  5.0, 27.0,  3.0,
    'whole_foods_365', '365 by Whole Foods Market'),

-- Per 365 label: 30 kcal / 1 cup (240ml)
('365 Unsweetened Almond Milk',
    '1 cup (240ml)',           240,   30,  1.0,  1.0,  2.5,
    'whole_foods_365', '365 by Whole Foods Market'),

-- Per 365 label: 20 kcal / 2 cups (85g)
('365 Organic Baby Spinach',
    '2 cups (85g)',             85,   20,  3.0,  3.0,  0.0,
    'whole_foods_365', '365 by Whole Foods Market'),

-- Per 365 label: 10 kcal / 1 cup (240ml)
('365 Organic Low Sodium Chicken Broth',
    '1 cup (240ml)',           240,   10,  2.0,  1.0,  0.0,
    'whole_foods_365', '365 by Whole Foods Market'),

-- ══════════════════════════════════════════════════════════════════════════════
-- GREAT VALUE (Walmart)
-- ══════════════════════════════════════════════════════════════════════════════

-- Dairy & eggs — from Walmart.com product pages
('Great Value Large Eggs',
    '1 egg (50g)',              50,   70,  6.0,  0.0,  5.0,
    'great_value', 'Great Value'),

('Great Value 2% Reduced Fat Milk',
    '1 cup (240ml)',           240,  120,  8.0, 12.0,  4.5,
    'great_value', 'Great Value'),

('Great Value Whole Milk',
    '1 cup (240ml)',           240,  150,  8.0, 12.0,  8.0,
    'great_value', 'Great Value'),

('Great Value Shredded Cheddar Cheese',
    '¼ cup (28g)',              28,  110,  7.0,  0.0,  9.0,
    'great_value', 'Great Value'),

-- Pantry staples
('Great Value Creamy Peanut Butter',
    '2 tbsp (32g)',             32,  190,  7.0,  7.0, 16.0,
    'great_value', 'Great Value'),

('Great Value Sliced White Sandwich Bread',
    '1 slice (25g)',            25,   70,  2.0, 13.0,  1.0,
    'great_value', 'Great Value'),

-- Per Great Value label: 100 kcal / 1 packet dry (28g)
('Great Value Instant Oatmeal, plain',
    '1 packet dry (28g)',       28,  100,  4.0, 19.0,  2.0,
    'great_value', 'Great Value'),

-- Frozen vegetables
-- Per Great Value label: 25 kcal / 1 cup (85g)
('Great Value Frozen Broccoli Florets',
    '1 cup (85g)',              85,   25,  3.0,  5.0,  0.0,
    'great_value', 'Great Value');
