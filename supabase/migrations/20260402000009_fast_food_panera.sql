-- =============================================================================
-- Migration: 20260402000009_fast_food_panera
-- Purpose:   Adds Panera Bread menu items to generic_foods.
--
-- Source: Panera Bread official published nutrition information.
--         Source field = 'panera'; brand = 'Panera'.
--
-- Naming convention: "Panera [Item Name]"
--
-- Items cover: soups (cup/bowl/bread bowl), signature sandwiches, salads,
-- and bakery items. Panera's core menu is relatively stable; seasonal items
-- are excluded in favor of year-round offerings.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Soups ────────────────────────────────────────────────────────────────────
('Panera Broccoli Cheddar Soup (cup)',
    '1 cup (227g)',  227,  230, 9.0, 16.0, 14.0, 'panera', 'Panera'),

('Panera Broccoli Cheddar Soup (bowl)',
    '1 bowl (340g)',  340,  360, 14.0, 25.0, 22.0, 'panera', 'Panera'),

('Panera Broccoli Cheddar Soup (bread bowl)',
    '1 bread bowl (567g)',  567,  900, 30.0, 104.0, 40.0, 'panera', 'Panera'),

('Panera Creamy Tomato Soup (cup)',
    '1 cup (227g)',  227,  200, 4.0, 20.0, 12.0, 'panera', 'Panera'),

('Panera Creamy Tomato Soup (bowl)',
    '1 bowl (340g)',  340,  300, 6.0, 30.0, 18.0, 'panera', 'Panera'),

('Panera Chicken Noodle Soup (cup)',
    '1 cup (227g)',  227,  100, 8.0, 11.0, 2.0, 'panera', 'Panera'),

('Panera Chicken Noodle Soup (bowl)',
    '1 bowl (340g)',  340,  160, 12.0, 17.0, 4.0, 'panera', 'Panera'),

-- ── Sandwiches ───────────────────────────────────────────────────────────────
('Panera Bacon Turkey Bravo',
    '1 whole sandwich (354g)',  354,  630, 37.0, 62.0, 26.0, 'panera', 'Panera'),

('Panera Chipotle Chicken Avocado Melt',
    '1 whole sandwich (381g)',  381,  810, 42.0, 66.0, 40.0, 'panera', 'Panera'),

('Panera Frontega Chicken on Focaccia',
    '1 whole sandwich (332g)',  332,  710, 35.0, 55.0, 38.0, 'panera', 'Panera'),

('Panera Napa Almond Chicken Salad Sandwich',
    '1 whole sandwich (354g)',  354,  690, 28.0, 56.0, 39.0, 'panera', 'Panera'),

('Panera Toasted Steak & White Cheddar',
    '1 whole sandwich (340g)',  340,  690, 39.0, 56.0, 33.0, 'panera', 'Panera'),

-- ── Mac & Cheese ─────────────────────────────────────────────────────────────
('Panera Mac & Cheese (bowl)',
    '1 bowl (340g)',  340,  590, 24.0, 51.0, 32.0, 'panera', 'Panera'),

('Panera Mac & Cheese (cup)',
    '1 cup (198g)',  198,  340, 14.0, 30.0, 18.0, 'panera', 'Panera'),

-- ── Salads ───────────────────────────────────────────────────────────────────
('Panera Caesar Salad (whole)',
    '1 salad (274g)',  274,  330, 9.0, 24.0, 23.0, 'panera', 'Panera'),

('Panera Fuji Apple Chicken Salad (whole)',
    '1 salad (411g)',  411,  570, 33.0, 46.0, 29.0, 'panera', 'Panera'),

('Panera Greek Salad (whole)',
    '1 salad (262g)',  262,  400, 6.0, 14.0, 36.0, 'panera', 'Panera'),

-- ── Bakery ───────────────────────────────────────────────────────────────────
('Panera Kitchen Sink Cookie',
    '1 cookie (100g)',  100,  360, 4.0, 46.0, 18.0, 'panera', 'Panera'),

('Panera Chocolate Chipper Cookie',
    '1 cookie (92g)',  92,  370, 4.0, 44.0, 20.0, 'panera', 'Panera'),

('Panera Cinnamon Crunch Bagel',
    '1 bagel (113g)',  113,  420, 9.0, 68.0, 14.0, 'panera', 'Panera'),

('Panera Plain Bagel',
    '1 bagel (104g)',  104,  270, 10.0, 54.0, 1.0, 'panera', 'Panera');
