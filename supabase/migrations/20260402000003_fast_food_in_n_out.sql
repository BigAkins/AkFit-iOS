-- =============================================================================
-- Migration: 20260402000003_fast_food_in_n_out
-- Purpose:   Adds In-N-Out Burger menu items to generic_foods.
--
-- Source: In-N-Out Burger official published nutrition information.
--         Source field = 'in_n_out'; brand = 'In-N-Out'.
--
-- Naming convention: "In-N-Out [Item Name]"
--
-- Items cover: burgers (including protein-style and animal-style), fries,
-- and shakes. In-N-Out's "secret menu" items (animal style, protein style)
-- are included because they are published on the official nutrition page
-- and are widely ordered.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Burgers ──────────────────────────────────────────────────────────────────
('In-N-Out Hamburger',
    '1 burger (243g)',  243,  390, 16.0, 39.0, 19.0, 'in_n_out', 'In-N-Out'),

('In-N-Out Cheeseburger',
    '1 burger (268g)',  268,  480, 22.0, 39.0, 27.0, 'in_n_out', 'In-N-Out'),

('In-N-Out Double-Double',
    '1 burger (330g)',  330,  670, 37.0, 39.0, 41.0, 'in_n_out', 'In-N-Out'),

('In-N-Out 3x3 (Triple Meat Triple Cheese)',
    '1 burger (392g)',  392,  860, 53.0, 39.0, 56.0, 'in_n_out', 'In-N-Out'),

-- ── Protein Style (lettuce wrap, no bun) ─────────────────────────────────────
('In-N-Out Cheeseburger Protein Style',
    '1 burger (243g)',  243,  330, 18.0, 11.0, 25.0, 'in_n_out', 'In-N-Out'),

('In-N-Out Double-Double Protein Style',
    '1 burger (305g)',  305,  520, 33.0, 11.0, 39.0, 'in_n_out', 'In-N-Out'),

-- ── Animal Style ─────────────────────────────────────────────────────────────
('In-N-Out Double-Double Animal Style',
    '1 burger (368g)',  368,  770, 38.0, 42.0, 50.0, 'in_n_out', 'In-N-Out'),

('In-N-Out Animal Style Fries',
    '1 order (283g)',  283,  750, 17.0, 57.0, 51.0, 'in_n_out', 'In-N-Out'),

-- ── Fries ────────────────────────────────────────────────────────────────────
('In-N-Out French Fries',
    '1 order (125g)',  125,  395, 7.0, 54.0, 18.0, 'in_n_out', 'In-N-Out'),

-- ── Shakes ───────────────────────────────────────────────────────────────────
('In-N-Out Chocolate Shake',
    '1 shake (425g)',  425,  590, 9.0, 72.0, 29.0, 'in_n_out', 'In-N-Out'),

('In-N-Out Vanilla Shake',
    '1 shake (425g)',  425,  580, 9.0, 67.0, 31.0, 'in_n_out', 'In-N-Out'),

('In-N-Out Strawberry Shake',
    '1 shake (425g)',  425,  590, 8.0, 72.0, 29.0, 'in_n_out', 'In-N-Out');
