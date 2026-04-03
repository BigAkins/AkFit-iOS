-- =============================================================================
-- Migration: 20260402000008_fast_food_subway
-- Purpose:   Adds Subway menu items to generic_foods.
--
-- Source: Subway official published nutrition information.
--         Source field = 'subway'; brand = 'Subway'.
--
-- Naming convention: "Subway [Item Name]"
--
-- All 6" subs use the standard base (9-grain wheat bread, lettuce, tomato,
-- onion, green pepper, cucumber — no cheese, no sauce) per Subway's
-- published nutrition page. Users who add extras can adjust quantity or
-- log condiments separately. Footlong variants are included for the most
-- popular subs since many users order full-size.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── 6-inch Subs ──────────────────────────────────────────────────────────────
('Subway 6" Turkey Breast',
    '1 sub (224g)',  224,  270, 18.0, 40.0, 4.0, 'subway', 'Subway'),

('Subway 6" Oven Roasted Turkey & Ham',
    '1 sub (232g)',  232,  270, 19.0, 40.0, 4.0, 'subway', 'Subway'),

('Subway 6" Italian B.M.T.',
    '1 sub (232g)',  232,  370, 17.0, 41.0, 15.0, 'subway', 'Subway'),

('Subway 6" Meatball Marinara',
    '1 sub (318g)',  318,  440, 18.0, 51.0, 18.0, 'subway', 'Subway'),

('Subway 6" Sweet Onion Chicken Teriyaki',
    '1 sub (271g)',  271,  330, 21.0, 44.0, 6.0, 'subway', 'Subway'),

('Subway 6" Veggie Delite',
    '1 sub (163g)',  163,  210, 8.0, 38.0, 2.0, 'subway', 'Subway'),

('Subway 6" Tuna',
    '1 sub (240g)',  240,  370, 15.0, 38.0, 18.0, 'subway', 'Subway'),

('Subway 6" Roast Beef',
    '1 sub (224g)',  224,  290, 19.0, 39.0, 5.0, 'subway', 'Subway'),

('Subway 6" Cold Cut Combo',
    '1 sub (232g)',  232,  310, 14.0, 40.0, 10.0, 'subway', 'Subway'),

('Subway 6" Steak & Cheese',
    '1 sub (244g)',  244,  340, 24.0, 40.0, 9.0, 'subway', 'Subway'),

('Subway 6" Chicken & Bacon Ranch',
    '1 sub (294g)',  294,  520, 31.0, 42.0, 25.0, 'subway', 'Subway'),

-- ── Footlong (most popular) ──────────────────────────────────────────────────
('Subway Footlong Turkey Breast',
    '1 sub (448g)',  448,  540, 36.0, 80.0, 8.0, 'subway', 'Subway'),

('Subway Footlong Italian B.M.T.',
    '1 sub (464g)',  464,  740, 34.0, 82.0, 30.0, 'subway', 'Subway'),

('Subway Footlong Meatball Marinara',
    '1 sub (636g)',  636,  880, 36.0, 102.0, 36.0, 'subway', 'Subway'),

-- ── Sides & Extras ───────────────────────────────────────────────────────────
('Subway Chocolate Chip Cookie',
    '1 cookie (45g)',  45,  220, 2.0, 30.0, 10.0, 'subway', 'Subway'),

('Subway White Chip Macadamia Cookie',
    '1 cookie (45g)',  45,  220, 2.0, 28.0, 11.0, 'subway', 'Subway');
