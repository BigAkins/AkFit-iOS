-- =============================================================================
-- Migration: 20260402000006_fresh_produce_snackable
-- Purpose:   Adds fresh fruit and snackable produce items to generic_foods.
--
-- Source: USDA FoodData Central (SR Legacy / Foundation Foods).
--         Source field = 'usda'; brand = NULL.
--
-- These are practical, snack-sized servings of fresh produce — the kind
-- of items users grab between meals or add as sides. Serving sizes use
-- common household measures (1 cup, 1 medium, etc.) rather than 100g
-- reference portions, since that's how people actually eat them.
--
-- Naming convention: clean, obvious names that match natural search queries.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Whole Fruits ─────────────────────────────────────────────────────────────
('Apple, raw',
    '1 medium (182g)',  182,  95, 0.5, 25.0, 0.3, 'usda', null),

('Apple Slices',
    '1 cup slices (109g)',  109,  57, 0.3, 15.0, 0.2, 'usda', null),

('Banana',
    '1 medium (118g)',  118,  105, 1.3, 27.0, 0.4, 'usda', null),

('Orange, raw',
    '1 medium (131g)',  131,  62, 1.2, 15.0, 0.2, 'usda', null),

('Orange Slices',
    '1 cup sections (180g)',  180,  85, 1.7, 21.0, 0.2, 'usda', null),

('Clementine',
    '1 fruit (74g)',  74,  35, 0.6, 9.0, 0.1, 'usda', null),

('Lemon, raw',
    '1 medium (58g)',  58,  17, 0.6, 5.4, 0.2, 'usda', null),

('Lime, raw',
    '1 medium (67g)',  67,  20, 0.5, 7.1, 0.1, 'usda', null),

('Grapefruit, raw',
    '1/2 medium (128g)',  128,  52, 0.9, 13.0, 0.2, 'usda', null),

-- ── Berries ──────────────────────────────────────────────────────────────────
('Strawberries',
    '1 cup halves (152g)',  152,  49, 1.0, 12.0, 0.5, 'usda', null),

('Blueberries',
    '1 cup (148g)',  148,  84, 1.1, 21.0, 0.5, 'usda', null),

('Raspberries',
    '1 cup (123g)',  123,  64, 1.5, 15.0, 0.8, 'usda', null),

('Blackberries',
    '1 cup (144g)',  144,  62, 2.0, 14.0, 0.7, 'usda', null),

-- ── Grapes & Melons ──────────────────────────────────────────────────────────
('Grapes, red or green',
    '1 cup (151g)',  151,  104, 1.1, 27.0, 0.2, 'usda', null),

('Cantaloupe',
    '1 cup cubed (160g)',  160,  54, 1.3, 13.0, 0.3, 'usda', null),

('Honeydew Melon',
    '1 cup cubed (170g)',  170,  61, 0.9, 15.0, 0.2, 'usda', null),

-- ── Tropical ─────────────────────────────────────────────────────────────────
('Pineapple Chunks',
    '1 cup (165g)',  165,  82, 0.9, 22.0, 0.2, 'usda', null),

('Kiwi',
    '1 medium (69g)',  69,  42, 0.8, 10.0, 0.4, 'usda', null),

-- ── Snackable Vegetables ─────────────────────────────────────────────────────
('Baby Carrots',
    '3 oz (85g)',  85,  30, 0.5, 7.0, 0.1, 'usda', null),

('Cucumber Slices',
    '1 cup (119g)',  119,  16, 0.7, 3.1, 0.2, 'usda', null),

('Cherry Tomatoes',
    '1 cup (149g)',  149,  27, 1.3, 6.0, 0.3, 'usda', null),

('Celery Sticks',
    '1 cup (101g)',  101,  14, 0.7, 3.0, 0.2, 'usda', null),

('Snap Peas',
    '1 cup (63g)',  63,  26, 1.8, 5.0, 0.1, 'usda', null),

('Broccoli Florets, raw',
    '1 cup (71g)',  71,  24, 2.0, 5.0, 0.3, 'usda', null),

('Radishes',
    '1 cup slices (116g)',  116,  19, 0.8, 4.0, 0.1, 'usda', null),

('Jicama Sticks',
    '1 cup (120g)',  120,  46, 0.9, 11.0, 0.1, 'usda', null),

('Edamame, shelled',
    '1/2 cup (75g)',  75,  95, 8.5, 8.0, 4.0, 'usda', null),

-- ── Dried Fruit ──────────────────────────────────────────────────────────────
('Raisins',
    '1 small box (43g)',  43,  129, 1.3, 34.0, 0.2, 'usda', null),

('Dried Cranberries (Craisins)',
    '1/4 cup (40g)',  40,  130, 0.0, 33.0, 0.5, 'usda', null),

('Dates, Medjool',
    '2 dates (48g)',  48,  133, 1.0, 36.0, 0.1, 'usda', null),

-- ── Avocado (commonly snacked on) ────────────────────────────────────────────
('Avocado',
    '1/2 medium (68g)',  68,  114, 1.4, 6.0, 10.5, 'usda', null);
