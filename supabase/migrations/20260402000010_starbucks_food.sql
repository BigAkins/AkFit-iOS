-- =============================================================================
-- Migration: 20260402000010_starbucks_food
-- Purpose:   Adds Starbucks food items to generic_foods.
--
-- Source: Starbucks official published nutrition information.
--         Source field = 'starbucks'; brand = 'Starbucks'.
--
-- Naming convention: "Starbucks [Item Name]"
--
-- Scope: food items only — breakfast sandwiches, egg bites, bakery,
-- protein boxes. Drinks are excluded because Starbucks beverage
-- customization makes fixed entries misleading; users who want to log
-- drinks can use the Open Food Facts fallback or manual entry.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Breakfast Sandwiches & Wraps ─────────────────────────────────────────────
('Starbucks Bacon, Gouda & Egg Sandwich',
    '1 sandwich (119g)',  119,  360, 18.0, 34.0, 17.0, 'starbucks', 'Starbucks'),

('Starbucks Double-Smoked Bacon, Cheddar & Egg Sandwich',
    '1 sandwich (141g)',  141,  490, 22.0, 38.0, 27.0, 'starbucks', 'Starbucks'),

('Starbucks Turkey Bacon, Cheddar & Egg White Sandwich',
    '1 sandwich (119g)',  119,  230, 17.0, 28.0, 5.0, 'starbucks', 'Starbucks'),

('Starbucks Sausage, Cheddar & Egg Sandwich',
    '1 sandwich (119g)',  119,  480, 15.0, 34.0, 31.0, 'starbucks', 'Starbucks'),

('Starbucks Impossible Breakfast Sandwich',
    '1 sandwich (127g)',  127,  420, 22.0, 34.0, 22.0, 'starbucks', 'Starbucks'),

('Starbucks Spinach, Feta & Egg White Wrap',
    '1 wrap (156g)',  156,  290, 20.0, 34.0, 8.0, 'starbucks', 'Starbucks'),

-- ── Egg Bites ────────────────────────────────────────────────────────────────
('Starbucks Egg Bites, Bacon & Gruyere (2-pack)',
    '2 bites (130g)',  130,  300, 19.0, 9.0, 20.0, 'starbucks', 'Starbucks'),

('Starbucks Egg Bites, Egg White & Red Pepper (2-pack)',
    '2 bites (130g)',  130,  170, 13.0, 11.0, 8.0, 'starbucks', 'Starbucks'),

('Starbucks Egg Bites, Kale & Mushroom (2-pack)',
    '2 bites (130g)',  130,  230, 14.0, 9.0, 15.0, 'starbucks', 'Starbucks'),

-- ── Bakery ───────────────────────────────────────────────────────────────────
('Starbucks Butter Croissant',
    '1 croissant (68g)',  68,  240, 5.0, 26.0, 12.0, 'starbucks', 'Starbucks'),

('Starbucks Chocolate Croissant',
    '1 croissant (78g)',  78,  340, 5.0, 37.0, 19.0, 'starbucks', 'Starbucks'),

('Starbucks Cheese Danish',
    '1 danish (99g)',  99,  290, 5.0, 32.0, 16.0, 'starbucks', 'Starbucks'),

('Starbucks Blueberry Muffin',
    '1 muffin (113g)',  113,  360, 5.0, 52.0, 15.0, 'starbucks', 'Starbucks'),

('Starbucks Banana Nut Bread',
    '1 slice (113g)',  113,  420, 6.0, 52.0, 21.0, 'starbucks', 'Starbucks'),

('Starbucks Chocolate Chip Cookie',
    '1 cookie (71g)',  71,  360, 4.0, 50.0, 16.0, 'starbucks', 'Starbucks'),

('Starbucks Birthday Cake Pop',
    '1 cake pop (36g)',  36,  160, 2.0, 18.0, 9.0, 'starbucks', 'Starbucks'),

-- ── Protein Boxes & Oatmeal ──────────────────────────────────────────────────
('Starbucks Cheese & Fruit Protein Box',
    '1 box (153g)',  153,  470, 16.0, 50.0, 24.0, 'starbucks', 'Starbucks'),

('Starbucks Eggs & Cheddar Protein Box',
    '1 box (136g)',  136,  460, 25.0, 37.0, 24.0, 'starbucks', 'Starbucks'),

('Starbucks Oatmeal',
    '1 bowl (220g)',  220,  220, 5.0, 43.0, 3.5, 'starbucks', 'Starbucks');
