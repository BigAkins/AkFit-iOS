-- =============================================================================
-- Migration: 20260403000000_final_food_expansion
-- Purpose:   Final curated food-data expansion — snacks, drinks, juices,
--            sodas, energy drinks, milkshakes, and alcohol.
--
-- Sources:
--   • USDA FoodData Central (SR Legacy / Foundation Foods) for generic items
--   • Official product nutrition labels (printed / brand websites) for branded
--
-- Duplicate-prevention:
--   • Full audit of existing 650+ rows performed before authoring
--   • No items below duplicate any existing food_name + serving_label pair
--   • Cheetos, Takis, SkinnyPop, Smartfood, Boom Chicka Pop, Lay's, Doritos,
--     Ruffles, Pringles, Tostitos, Goldfish, Ritz, Snyder's already present
--
-- Skipped (data not trustworthy / too variable):
--   • Horchata — recipe-dependent, no stable USDA entry
--   • Margarita — recipe-dependent, wildly variable
--   • Hot Chocolate — varies by preparation method and brand
--
-- Note: search_text column auto-populated via trigger from migration 000014.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Generic Popcorn (USDA) ──────────────────────────────────────────────────
('Popcorn, air-popped',
    '1 cup (8g)',           8,    31,  1.0,   6.0,  0.4, 'usda', null),

('Popcorn, air-popped',
    '3 cups (24g)',        24,    93,  3.0,  19.0,  1.1, 'usda', null),

('Popcorn, oil-popped',
    '1 cup (11g)',         11,    55,  1.0,   6.0,  3.1, 'usda', null),

-- ── Additional Snacks (official labels) ─────────────────────────────────────
('Fritos Original Corn Chips',
    '1 oz (28g)',          28,   160,  2.0,  15.0, 10.0, 'label', 'Fritos'),

('SunChips Original',
    '1 oz (28g)',          28,   140,  2.0,  19.0,  6.0, 'label', 'SunChips'),

('Chex Mix Traditional',
    '2/3 cup (30g)',       30,   130,  3.0,  22.0,  3.5, 'label', 'Chex Mix'),

('Funyuns Onion Flavored Rings',
    '1 oz (28g)',          28,   140,  2.0,  18.0,  7.0, 'label', 'Funyuns'),

('Pirate''s Booty Aged White Cheddar',
    '1 oz (28g)',          28,   130,  2.0,  18.0,  5.0, 'label', 'Pirate''s Booty'),

('Cheez-It Original',
    '27 crackers (30g)',   30,   150,  4.0,  17.0,  8.0, 'label', 'Cheez-It'),

('Wheat Thins Original',
    '16 crackers (31g)',   31,   140,  2.0,  22.0,  5.0, 'label', 'Wheat Thins'),

-- ── Healthy Snacks ──────────────────────────────────────────────────────────
('Veggie Straws, Sea Salt',
    '1 oz (28g)',          28,   130,  1.0,  20.0,  7.0, 'label', 'Sensible Portions'),

('Dried Mango',
    '1/4 cup (40g)',       40,   128,  0.5,  31.0,  0.5, 'usda', null),

-- ── Juices (USDA) ───────────────────────────────────────────────────────────
('Cranberry Juice Cocktail',
    '1 cup (253g)',       253,   137,  0.0,  34.0,  0.2, 'usda', null),

('Pineapple Juice',
    '1 cup (250g)',       250,   132,  0.8,  32.0,  0.2, 'usda', null),

('Apple Juice',
    '1 cup (248g)',       248,   114,  0.3,  28.0,  0.3, 'usda', null),

('Grape Juice',
    '1 cup (253g)',       253,   152,  1.4,  37.0,  0.2, 'usda', null),

-- ── Sodas (official labels) ─────────────────────────────────────────────────
('Coca-Cola',
    '12 oz can (355ml)',  355,   140,  0.0,  39.0,  0.0, 'label', 'Coca-Cola'),

('Pepsi',
    '12 oz can (355ml)',  355,   150,  0.0,  41.0,  0.0, 'label', 'Pepsi'),

('Dr Pepper',
    '12 oz can (355ml)',  355,   150,  0.0,  40.0,  0.0, 'label', 'Dr Pepper'),

('Sprite',
    '12 oz can (355ml)',  355,   140,  0.0,  38.0,  0.0, 'label', 'Sprite'),

('Mountain Dew',
    '12 oz can (355ml)',  355,   170,  0.0,  46.0,  0.0, 'label', 'Mountain Dew'),

-- ── Other Beverages (USDA) ──────────────────────────────────────────────────
('Sweet Tea',
    '1 cup (240ml)',      240,    91,  0.0,  22.0,  0.0, 'usda', null),

('Lemonade',
    '1 cup (248ml)',      248,    99,  0.2,  26.0,  0.1, 'usda', null),

('Chocolate Milk',
    '1 cup (240ml)',      240,   190,  8.0,  30.0,  5.0, 'usda', null),

('Oat Milk',
    '1 cup (240ml)',      240,   120,  3.0,  16.0,  5.0, 'usda', null),

-- ── Milkshakes (USDA — fast-food style) ─────────────────────────────────────
('Milkshake, vanilla',
    '12 fl oz (340g)',    340,   370, 10.0,  56.0, 12.0, 'usda', null),

('Milkshake, chocolate',
    '12 fl oz (340g)',    340,   380, 10.0,  58.0, 12.0, 'usda', null),

('Milkshake, strawberry',
    '12 fl oz (340g)',    340,   370, 10.0,  55.0, 12.0, 'usda', null),

-- ── Sports & Energy Drinks (official labels) ────────────────────────────────
('Gatorade Thirst Quencher',
    '20 oz bottle (591ml)', 591,  140,  0.0,  36.0,  0.0, 'label', 'Gatorade'),

('Gatorade Zero',
    '20 oz bottle (591ml)', 591,    0,  0.0,   1.0,  0.0, 'label', 'Gatorade'),

('Red Bull',
    '8.4 oz can (248ml)', 248,   110,  0.0,  28.0,  0.0, 'label', 'Red Bull'),

('Monster Energy',
    '16 oz can (473ml)',  473,   210,  0.0,  54.0,  0.0, 'label', 'Monster'),

('Celsius',
    '12 oz can (355ml)',  355,    10,  0.0,   2.0,  0.0, 'label', 'Celsius'),

-- ── Alcohol — Distilled Spirits (USDA, 80-proof) ───────────────────────────
('Tequila',
    '1.5 oz shot (42ml)', 42,    97,  0.0,   0.0,  0.0, 'usda', null),

('Vodka',
    '1.5 oz shot (42ml)', 42,    97,  0.0,   0.0,  0.0, 'usda', null),

('Whiskey',
    '1.5 oz shot (42ml)', 42,    97,  0.0,   0.0,  0.0, 'usda', null),

('Rum',
    '1.5 oz shot (42ml)', 42,    97,  0.0,   0.0,  0.0, 'usda', null),

('Gin',
    '1.5 oz shot (42ml)', 42,    97,  0.0,   0.0,  0.0, 'usda', null),

-- ── Alcohol — Beer & Wine (USDA) ────────────────────────────────────────────
('Beer, regular',
    '12 oz (355ml)',      356,   153,  1.6,  13.0,  0.0, 'usda', null),

('Beer, light',
    '12 oz (355ml)',      356,   103,  0.9,   6.0,  0.0, 'usda', null),

('Red Wine',
    '5 oz (148ml)',       148,   125,  0.1,   3.8,  0.0, 'usda', null),

('White Wine',
    '5 oz (148ml)',       148,   121,  0.1,   3.8,  0.0, 'usda', null),

('Hard Seltzer',
    '12 oz can (355ml)',  355,   100,  0.0,   2.0,  0.0, 'label', null);
