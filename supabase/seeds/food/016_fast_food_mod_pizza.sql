-- =============================================================================
-- Migration: 20260402000004_fast_food_mod_pizza
-- Purpose:   Adds MOD Pizza menu items to generic_foods.
--
-- Source: MOD Pizza official published nutrition information.
--         Source field = 'mod_pizza'; brand = 'MOD Pizza'.
--
-- Naming convention: "MOD Pizza [Item Name]"
--
-- MOD Pizza is build-your-own, but publishes nutrition for their signature
-- (named) pizzas and individual components. We include the most popular
-- signature pizzas per 1/2 pizza (an 11" MOD-size pizza is typically
-- eaten in halves or wholes) plus key sides. Crust choice affects totals;
-- original crust is used as the default.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Signature Pizzas (1/2 of 11" MOD-size, original crust) ──────────────────
('MOD Pizza Mad Dog (half)',
    '1/2 pizza (261g)',  261,  630, 29.0, 68.0, 27.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza Dominic (half)',
    '1/2 pizza (241g)',  241,  540, 24.0, 65.0, 21.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza Lucy Sunshine (half)',
    '1/2 pizza (247g)',  247,  560, 23.0, 66.0, 23.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza Jasper (half)',
    '1/2 pizza (255g)',  255,  600, 26.0, 67.0, 25.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza Tristan (half)',
    '1/2 pizza (234g)',  234,  510, 24.0, 64.0, 19.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza Dillon James (half)',
    '1/2 pizza (261g)',  261,  590, 27.0, 66.0, 24.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza Cheese Only (half)',
    '1/2 pizza (204g)',  204,  440, 18.0, 60.0, 14.0, 'mod_pizza', 'MOD Pizza'),

-- ── Full pizza options for heavy logging ─────────────────────────────────────
('MOD Pizza Mad Dog (full)',
    '1 pizza (522g)',  522,  1260, 58.0, 136.0, 54.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza Cheese Only (full)',
    '1 pizza (408g)',  408,  880, 36.0, 120.0, 28.0, 'mod_pizza', 'MOD Pizza'),

-- ── Mega Size (full 11" with extra crust/toppings context) ───────────────────
('MOD Pizza Mega Cheese (full)',
    '1 mega pizza (510g)',  510,  1100, 44.0, 144.0, 36.0, 'mod_pizza', 'MOD Pizza'),

-- ── Sides & Other ────────────────────────────────────────────────────────────
('MOD Pizza Garlic Strips (4-piece)',
    '4 strips (113g)',  113,  300, 7.0, 38.0, 13.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza Side Salad',
    '1 salad (113g)',  113,  110, 3.0, 8.0, 8.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza Chocolate Chip Cookie',
    '1 cookie (64g)',  64,  280, 3.0, 36.0, 14.0, 'mod_pizza', 'MOD Pizza'),

('MOD Pizza No Name Cake',
    '1 slice (92g)',  92,  360, 4.0, 48.0, 17.0, 'mod_pizza', 'MOD Pizza');
