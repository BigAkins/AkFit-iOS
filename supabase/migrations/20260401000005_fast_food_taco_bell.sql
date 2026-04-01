-- =============================================================================
-- Migration: 20260401000005_fast_food_taco_bell
-- Purpose:   Adds Taco Bell menu items to generic_foods so they appear in the
--            primary Supabase search tier instead of falling through to the
--            noisy Open Food Facts fallback.
--
-- Source: Taco Bell USA published nutrition information (official menu data).
--         Values reflect standard U.S. menu items as of the time of this
--         migration. Source field = 'taco_bell'; brand = 'Taco Bell'.
--
-- Naming convention: "Taco Bell [Item Name]"
--   - Searching "taco bell"        → all items (prefix match, rank 1)
--   - Searching "taco bell taco"   → taco items (word-prefix match, rank 3)
--   - Searching "crunchwrap"       → found via substring (rank 4)
--   - Searching "nachos bellgrande"→ found via word match
--
-- Items cover: core tacos, burritos, Crunchwrap Supreme, Mexican Pizza,
-- Nachos BellGrande, Chalupa, Chicken Quesadilla, Power Menu Bowl.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Tacos ─────────────────────────────────────────────────────────────────────
('Taco Bell Crunchy Taco',
    '1 taco (89g)',            89,  170,  8.0, 13.0,  9.0, 'taco_bell', 'Taco Bell'),

('Taco Bell Soft Taco',
    '1 taco (99g)',            99,  190, 10.0, 19.0,  9.0, 'taco_bell', 'Taco Bell'),

-- Doritos Locos Taco — seasoned beef, nacho cheese shell
('Taco Bell Doritos Locos Taco',
    '1 taco (89g)',            89,  170,  8.0, 13.0, 10.0, 'taco_bell', 'Taco Bell'),

-- ── Burritos ──────────────────────────────────────────────────────────────────
-- Burrito Supreme: seasoned beef, sour cream, tomato, lettuce, shredded cheese,
-- reduced-fat sour cream, seasoned rice, beans, in flour tortilla
('Taco Bell Burrito Supreme',
    '1 burrito (248g)',       248,  390, 17.0, 50.0, 15.0, 'taco_bell', 'Taco Bell'),

-- Bean Burrito: beans, red sauce, shredded cheese
('Taco Bell Bean Burrito',
    '1 burrito (198g)',       198,  350, 13.0, 55.0,  9.0, 'taco_bell', 'Taco Bell'),

-- Beefy 5-Layer Burrito: seasoned beef, nacho cheese sauce, beans, sour cream,
-- shredded cheese, flour tortilla (doubled)
('Taco Bell Beefy 5-Layer Burrito',
    '1 burrito (240g)',       240,  490, 18.0, 66.0, 17.0, 'taco_bell', 'Taco Bell'),

-- ── Signature Items ───────────────────────────────────────────────────────────
-- Crunchwrap Supreme: seasoned beef, nacho cheese sauce, tostada shell,
-- lettuce, tomato, sour cream, in griddled flour tortilla
('Taco Bell Crunchwrap Supreme',
    '1 crunchwrap (254g)',    254,  520, 17.0, 71.0, 20.0, 'taco_bell', 'Taco Bell'),

-- Mexican Pizza: seasoned beef, beans, pizza sauce, shredded cheese,
-- tomatoes, between two fried flour shells
('Taco Bell Mexican Pizza',
    '1 pizza (213g)',         213,  540, 21.0, 49.0, 30.0, 'taco_bell', 'Taco Bell'),

-- Nachos BellGrande: tortilla chips, seasoned beef, beans, nacho cheese sauce,
-- sour cream, tomatoes
('Taco Bell Nachos BellGrande',
    '1 order (317g)',         317,  740, 19.0, 78.0, 40.0, 'taco_bell', 'Taco Bell'),

-- Chalupa Supreme (Beef): seasoned beef, shredded cheese, lettuce, tomato,
-- sour cream in crispy chalupa shell
('Taco Bell Chalupa Supreme',
    '1 chalupa (153g)',       153,  360, 13.0, 37.0, 19.0, 'taco_bell', 'Taco Bell'),

-- ── Chicken ───────────────────────────────────────────────────────────────────
-- Chicken Quesadilla: grilled chicken, three-cheese blend, creamy jalapeño sauce
('Taco Bell Chicken Quesadilla',
    '1 quesadilla (184g)',    184,  500, 28.0, 39.0, 26.0, 'taco_bell', 'Taco Bell'),

-- Power Menu Bowl (Chicken): grilled chicken, seasoned rice, black beans,
-- premium Latin rice, guacamole, sour cream, avocado ranch, pico de gallo
-- Macro-friendly: high protein, moderate carbs
('Taco Bell Power Menu Bowl',
    'chicken, rice, black beans, guacamole, pico (344g)',
    344,  470, 26.0, 50.0, 19.0, 'taco_bell', 'Taco Bell');
