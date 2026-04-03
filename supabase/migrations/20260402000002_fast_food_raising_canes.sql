-- =============================================================================
-- Migration: 20260402000002_fast_food_raising_canes
-- Purpose:   Adds Raising Cane's menu items to generic_foods.
--
-- Source: Raising Cane's official published nutrition information.
--         Source field = 'raising_canes'; brand = 'Raising Cane''s'.
--
-- Naming convention: "Raising Cane's [Item Name]"
--
-- Raising Cane's has a focused menu: chicken fingers, fries, Texas toast,
-- coleslaw, Cane's sauce, and drinks. All core items are included.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Chicken Fingers ──────────────────────────────────────────────────────────
('Raising Cane''s Chicken Fingers (3-piece)',
    '3 fingers (135g)',  135,  510, 33.0, 26.0, 31.0, 'raising_canes', 'Raising Cane''s'),

('Raising Cane''s Chicken Fingers (4-piece)',
    '4 fingers (180g)',  180,  680, 44.0, 34.0, 41.0, 'raising_canes', 'Raising Cane''s'),

('Raising Cane''s Chicken Fingers (6-piece)',
    '6 fingers (270g)',  270,  1020, 66.0, 52.0, 62.0, 'raising_canes', 'Raising Cane''s'),

-- ── Sides ────────────────────────────────────────────────────────────────────
('Raising Cane''s Crinkle-Cut Fries (regular)',
    '1 regular (140g)',  140,  430, 6.0, 52.0, 22.0, 'raising_canes', 'Raising Cane''s'),

('Raising Cane''s Crinkle-Cut Fries (large)',
    '1 large (227g)',  227,  700, 10.0, 84.0, 36.0, 'raising_canes', 'Raising Cane''s'),

('Raising Cane''s Texas Toast',
    '1 slice (52g)',  52,  150, 3.0, 16.0, 8.0, 'raising_canes', 'Raising Cane''s'),

('Raising Cane''s Coleslaw',
    '1 side (113g)',  113,  170, 1.0, 10.0, 14.0, 'raising_canes', 'Raising Cane''s'),

-- ── Sauce ────────────────────────────────────────────────────────────────────
('Raising Cane''s Cane''s Sauce',
    '1 portion (28g)',  28,  190, 0.0, 7.0, 18.0, 'raising_canes', 'Raising Cane''s'),

-- ── Combos (pre-calculated totals for quick logging) ─────────────────────────
('Raising Cane''s The Box Combo',
    '1 combo (498g)',  498,  1450, 77.0, 111.0, 92.0, 'raising_canes', 'Raising Cane''s'),

('Raising Cane''s The 3 Finger Combo',
    '1 combo (368g)',  368,  1280, 42.0, 101.0, 79.0, 'raising_canes', 'Raising Cane''s'),

-- ── Drinks ───────────────────────────────────────────────────────────────────
('Raising Cane''s Lemonade (regular)',
    '1 regular (470ml)',  470,  210, 0.0, 54.0, 0.0, 'raising_canes', 'Raising Cane''s'),

('Raising Cane''s Sweet Tea (regular)',
    '1 regular (470ml)',  470,  170, 0.0, 43.0, 0.0, 'raising_canes', 'Raising Cane''s');
