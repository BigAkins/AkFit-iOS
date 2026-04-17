-- =============================================================================
-- Migration: 20260402000012_frozen_taquitos
-- Purpose:   Adds frozen taquito and similar rolled-taco convenience items
--            to generic_foods.
--
-- Source: Official product nutrition labels (printed label / brand websites).
--         Source field = 'label'; brand = product brand name.
--
-- Taquitos are a top frozen-food search term and a practical logging gap.
-- A USDA generic taquito entry is included for users who eat homemade or
-- unlabeled versions.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Branded Frozen Taquitos ──────────────────────────────────────────────────
('El Monterey Beef & Cheese Taquitos',
    '3 taquitos (85g)',  85,  200, 6.0, 22.0, 10.0, 'label', 'El Monterey'),

('El Monterey Chicken & Cheese Taquitos',
    '3 taquitos (85g)',  85,  180, 7.0, 22.0, 7.0, 'label', 'El Monterey'),

('Jose Ole Beef & Cheese Taquitos',
    '3 taquitos (85g)',  85,  200, 6.0, 22.0, 10.0, 'label', 'Jose Ole'),

('Jose Ole Chicken & Cheese Taquitos',
    '3 taquitos (85g)',  85,  180, 7.0, 22.0, 7.0, 'label', 'Jose Ole'),

('Delimex Beef Taquitos',
    '3 taquitos (85g)',  85,  200, 6.0, 24.0, 9.0, 'label', 'Delimex'),

('Delimex Chicken Taquitos',
    '3 taquitos (85g)',  85,  180, 7.0, 23.0, 7.0, 'label', 'Delimex'),

-- ── Generic / USDA reference ─────────────────────────────────────────────────
('Taquito, beef, frozen, cooked',
    '1 taquito (28g)',  28,  65, 2.0, 7.0, 3.5, 'usda', null),

('Taquito, chicken, frozen, cooked',
    '1 taquito (28g)',  28,  60, 2.5, 7.0, 2.5, 'usda', null);
