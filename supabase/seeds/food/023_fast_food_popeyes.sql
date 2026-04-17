-- =============================================================================
-- Migration: 20260402000011_fast_food_popeyes
-- Purpose:   Adds Popeyes menu items to generic_foods.
--
-- Source: Popeyes official published nutrition information.
--         Source field = 'popeyes'; brand = 'Popeyes'.
--
-- Naming convention: "Popeyes [Item Name]"
--
-- Items cover: the chicken sandwich, tenders, individual chicken pieces
-- (by piece type), classic sides, and biscuit. All chicken entries use
-- "Mild" seasoning per Popeyes' standard nutrition — Spicy is the same
-- calories within rounding.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Chicken Sandwich ─────────────────────────────────────────────────────────
('Popeyes Chicken Sandwich (Classic)',
    '1 sandwich (219g)',  219,  700, 28.0, 50.0, 42.0, 'popeyes', 'Popeyes'),

('Popeyes Spicy Chicken Sandwich',
    '1 sandwich (219g)',  219,  700, 28.0, 50.0, 42.0, 'popeyes', 'Popeyes'),

-- ── Chicken Tenders ──────────────────────────────────────────────────────────
('Popeyes Chicken Tenders (3-piece)',
    '3 tenders (152g)',  152,  360, 27.0, 16.0, 21.0, 'popeyes', 'Popeyes'),

('Popeyes Chicken Tenders (5-piece)',
    '5 tenders (253g)',  253,  600, 45.0, 27.0, 35.0, 'popeyes', 'Popeyes'),

-- ── Bone-In Chicken (per piece, Mild) ────────────────────────────────────────
('Popeyes Chicken Breast (Mild)',
    '1 breast (180g)',  180,  380, 34.0, 12.0, 22.0, 'popeyes', 'Popeyes'),

('Popeyes Chicken Thigh (Mild)',
    '1 thigh (108g)',  108,  280, 15.0, 9.0, 21.0, 'popeyes', 'Popeyes'),

('Popeyes Chicken Leg (Mild)',
    '1 leg (72g)',  72,  160, 13.0, 5.0, 10.0, 'popeyes', 'Popeyes'),

('Popeyes Chicken Wing (Mild)',
    '1 wing (57g)',  57,  150, 10.0, 5.0, 10.0, 'popeyes', 'Popeyes'),

-- ── Sides ────────────────────────────────────────────────────────────────────
('Popeyes Cajun Fries (regular)',
    '1 regular (85g)',  85,  260, 3.0, 30.0, 14.0, 'popeyes', 'Popeyes'),

('Popeyes Cajun Fries (large)',
    '1 large (142g)',  142,  430, 5.0, 50.0, 24.0, 'popeyes', 'Popeyes'),

('Popeyes Mashed Potatoes with Cajun Gravy',
    '1 regular (142g)',  142,  110, 2.0, 14.0, 5.0, 'popeyes', 'Popeyes'),

('Popeyes Red Beans & Rice (regular)',
    '1 regular (170g)',  170,  220, 7.0, 30.0, 8.0, 'popeyes', 'Popeyes'),

('Popeyes Coleslaw (regular)',
    '1 regular (134g)',  134,  210, 1.0, 16.0, 16.0, 'popeyes', 'Popeyes'),

('Popeyes Mac & Cheese (regular)',
    '1 regular (142g)',  142,  190, 7.0, 19.0, 10.0, 'popeyes', 'Popeyes'),

('Popeyes Biscuit',
    '1 biscuit (60g)',  60,  240, 4.0, 26.0, 13.0, 'popeyes', 'Popeyes');
