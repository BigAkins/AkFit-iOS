-- =============================================================================
-- Migration: 20260402000007_fast_food_whataburger
-- Purpose:   Adds Whataburger menu items to generic_foods.
--
-- Source: Whataburger official published nutrition information.
--         Source field = 'whataburger'; brand = 'Whataburger'.
--
-- Naming convention: "Whataburger [Item Name]"
--
-- Items cover: signature burgers, chicken sandwiches, breakfast items,
-- sides, and shakes. Regional favorites like the Honey Butter Chicken
-- Biscuit and Patty Melt are included as core permanent menu items.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Burgers ──────────────────────────────────────────────────────────────────
('Whataburger (Original)',
    '1 burger (316g)',  316,  590, 27.0, 53.0, 30.0, 'whataburger', 'Whataburger'),

('Whataburger Double Meat',
    '1 burger (406g)',  406,  850, 47.0, 53.0, 48.0, 'whataburger', 'Whataburger'),

('Whataburger Triple Meat',
    '1 burger (496g)',  496,  1110, 67.0, 53.0, 66.0, 'whataburger', 'Whataburger'),

('Whataburger Jr.',
    '1 burger (164g)',  164,  310, 16.0, 28.0, 15.0, 'whataburger', 'Whataburger'),

('Whataburger Patty Melt',
    '1 sandwich (295g)',  295,  710, 33.0, 52.0, 39.0, 'whataburger', 'Whataburger'),

('Whataburger Bacon & Cheese Whataburger',
    '1 burger (348g)',  348,  780, 36.0, 53.0, 43.0, 'whataburger', 'Whataburger'),

('Whataburger Avocado Bacon Burger',
    '1 burger (367g)',  367,  830, 35.0, 55.0, 48.0, 'whataburger', 'Whataburger'),

-- ── Chicken ──────────────────────────────────────────────────────────────────
('Whataburger Whatachick''n Sandwich',
    '1 sandwich (234g)',  234,  500, 22.0, 51.0, 23.0, 'whataburger', 'Whataburger'),

('Whataburger Honey BBQ Chicken Strip Sandwich',
    '1 sandwich (285g)',  285,  620, 33.0, 58.0, 27.0, 'whataburger', 'Whataburger'),

('Whataburger Chicken Strips (3-piece)',
    '3 strips (150g)',  150,  420, 25.0, 28.0, 22.0, 'whataburger', 'Whataburger'),

-- ── Breakfast ────────────────────────────────────────────────────────────────
('Whataburger Honey Butter Chicken Biscuit',
    '1 biscuit (205g)',  205,  610, 22.0, 46.0, 38.0, 'whataburger', 'Whataburger'),

('Whataburger Breakfast on a Bun (Sausage)',
    '1 sandwich (181g)',  181,  530, 20.0, 30.0, 37.0, 'whataburger', 'Whataburger'),

('Whataburger Breakfast on a Bun (Bacon)',
    '1 sandwich (153g)',  153,  370, 18.0, 29.0, 20.0, 'whataburger', 'Whataburger'),

('Whataburger Taquito with Cheese',
    '1 taquito (141g)',  141,  370, 17.0, 27.0, 21.0, 'whataburger', 'Whataburger'),

-- ── Sides ────────────────────────────────────────────────────────────────────
('Whataburger French Fries (medium)',
    '1 medium (135g)',  135,  400, 5.0, 50.0, 20.0, 'whataburger', 'Whataburger'),

('Whataburger French Fries (large)',
    '1 large (179g)',  179,  530, 7.0, 66.0, 27.0, 'whataburger', 'Whataburger'),

('Whataburger Onion Rings (medium)',
    '1 medium (113g)',  113,  420, 5.0, 49.0, 23.0, 'whataburger', 'Whataburger');
