-- =============================================================================
-- Migration: 20260401000003_fast_food_mcdonalds
-- Purpose:   Adds McDonald's menu items to generic_foods so they appear in the
--            primary Supabase search tier instead of falling through to the
--            noisy Open Food Facts fallback.
--
-- Source: McDonald's USA published nutrition information (official menu data).
--         Values reflect standard U.S. menu items as of the time of this
--         migration. Source field = 'mcdonalds'; brand = 'McDonald''s'.
--
-- Naming convention: "McDonald's [Item Name]"
--   - Searching "mcdonald" → all items (prefix match, rank 1)
--   - Searching "big mac"  → found via substring (rank 4)
--   - Searching "mcnuggets", "mcdouble" → found via word prefix (rank 3)
--
-- Items cover: core burgers, chicken sandwiches, nuggets, breakfast,
-- sides (fries, hash brown), and hotcakes.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Burgers ───────────────────────────────────────────────────────────────────
('McDonald''s Big Mac',
    '1 sandwich (219g)',  219,  550, 25.0, 46.0, 30.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s McDouble',
    '1 sandwich (174g)',  174,  400, 22.0, 34.0, 20.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Quarter Pounder with Cheese',
    '1 sandwich (219g)',  219,  520, 29.0, 41.0, 26.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Double Quarter Pounder with Cheese',
    '1 sandwich (280g)',  280,  740, 48.0, 42.0, 43.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Cheeseburger',
    '1 sandwich (123g)',  123,  300, 15.0, 32.0, 13.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Double Cheeseburger',
    '1 sandwich (167g)',  167,  440, 25.0, 34.0, 23.0, 'mcdonalds', 'McDonald''s'),

-- ── Chicken ───────────────────────────────────────────────────────────────────
('McDonald''s McChicken',
    '1 sandwich (152g)',  152,  400, 14.0, 41.0, 21.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Crispy Chicken Sandwich',
    '1 sandwich (222g)',  222,  470, 27.0, 46.0, 20.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Filet-O-Fish',
    '1 sandwich (156g)',  156,  390, 18.0, 39.0, 19.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Chicken McNuggets',
    '4 pc (65g)',          65,  170, 10.0, 10.0, 10.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Chicken McNuggets',
    '6 pc (96g)',          96,  250, 15.0, 16.0, 14.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Chicken McNuggets',
    '10 pc (162g)',       162,  420, 25.0, 26.0, 24.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Chicken McNuggets',
    '20 pc (323g)',       323,  840, 50.0, 52.0, 48.0, 'mcdonalds', 'McDonald''s'),

-- ── Breakfast ─────────────────────────────────────────────────────────────────
('McDonald''s Egg McMuffin',
    '1 sandwich (138g)',  138,  310, 17.0, 30.0, 13.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Sausage McMuffin with Egg',
    '1 sandwich (167g)',  167,  480, 21.0, 30.0, 31.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Sausage McMuffin',
    '1 sandwich (113g)',  113,  400, 14.0, 29.0, 23.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Sausage Biscuit',
    '1 sandwich (145g)',  145,  460, 13.0, 37.0, 28.0, 'mcdonalds', 'McDonald''s'),

-- Hotcakes: served with 2 pats margarine and syrup as standard
('McDonald''s Hotcakes',
    '3 hotcakes with margarine and syrup (264g)', 264, 580, 12.0, 102.0, 15.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s Hash Brown',
    '1 hash brown (58g)',  58,  150,  2.0, 15.0,  9.0, 'mcdonalds', 'McDonald''s'),

-- ── Sides ─────────────────────────────────────────────────────────────────────
-- McDonald's French Fries — brand-specific values differ from generic fries
-- (proprietary blend, cooking oil).
('McDonald''s French Fries',
    'Small (71g)',         71,  230,  3.0, 29.0, 11.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s French Fries',
    'Medium (117g)',      117,  320,  4.0, 44.0, 14.0, 'mcdonalds', 'McDonald''s'),

('McDonald''s French Fries',
    'Large (177g)',       177,  490,  7.0, 66.0, 23.0, 'mcdonalds', 'McDonald''s');
