-- =============================================================================
-- Migration: 20260402000013_healthy_convenience
-- Purpose:   Adds healthy convenience and snack items to generic_foods —
--            the kind of practical, macro-friendly items fitness-oriented
--            users commonly reach for.
--
-- Source: Official product nutrition labels (printed label / brand websites)
--         and USDA FoodData Central for generic items.
--         Source field = 'label' for branded; 'usda' for generic.
--
-- Naming convention: "[Brand] [Product Name]" for branded items;
-- clean generic name for USDA items.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Cheese Snacks ────────────────────────────────────────────────────────────
('Babybel Original',
    '1 piece (21g)',  21,  70, 5.0, 0.0, 6.0, 'label', 'Babybel'),

('Babybel Light',
    '1 piece (21g)',  21,  50, 6.0, 0.0, 3.0, 'label', 'Babybel'),

('Sargento String Cheese',
    '1 stick (28g)',  28,  80, 7.0, 1.0, 6.0, 'label', 'Sargento'),

('Sargento String Cheese, Light',
    '1 stick (28g)',  28,  50, 7.0, 1.0, 2.5, 'label', 'Sargento'),

('Laughing Cow Cheese Wedge, Original',
    '1 wedge (21g)',  21,  35, 2.0, 1.0, 2.5, 'label', 'Laughing Cow'),

-- ── Cottage Cheese ───────────────────────────────────────────────────────────
('Good Culture Cottage Cheese, Low-Fat',
    '1 container (150g)',  150,  120, 15.0, 5.0, 4.0, 'label', 'Good Culture'),

('Daisy Cottage Cheese, Low-Fat 2%',
    '1/2 cup (113g)',  113,  90, 13.0, 5.0, 2.5, 'label', 'Daisy'),

('Cottage Cheese, 2% milkfat',
    '1/2 cup (113g)',  113,  90, 12.0, 5.0, 2.5, 'usda', null),

('Cottage Cheese, 4% milkfat',
    '1/2 cup (113g)',  113,  110, 13.0, 4.0, 5.0, 'usda', null),

-- ── Protein Shakes (ready-to-drink) ──────────────────────────────────────────
('Premier Protein Shake, Chocolate',
    '1 bottle (340ml)',  340,  160, 30.0, 5.0, 3.0, 'label', 'Premier Protein'),

('Premier Protein Shake, Vanilla',
    '1 bottle (340ml)',  340,  160, 30.0, 5.0, 3.0, 'label', 'Premier Protein'),

('Fairlife Core Power, Chocolate',
    '1 bottle (414ml)',  414,  170, 26.0, 8.0, 4.5, 'label', 'Fairlife'),

('Fairlife Core Power Elite, Chocolate',
    '1 bottle (414ml)',  414,  230, 42.0, 8.0, 3.5, 'label', 'Fairlife'),

('Muscle Milk Genuine Shake, Chocolate',
    '1 bottle (414ml)',  414,  220, 25.0, 12.0, 9.0, 'label', 'Muscle Milk'),

('Orgain Organic Protein Shake, Creamy Chocolate',
    '1 carton (330ml)',  330,  150, 16.0, 15.0, 3.0, 'label', 'Orgain'),

-- ── Rice Cakes ───────────────────────────────────────────────────────────────
('Quaker Rice Cakes, Lightly Salted',
    '1 cake (9g)',  9,  35, 1.0, 7.0, 0.0, 'label', 'Quaker'),

('Quaker Rice Cakes, Chocolate',
    '1 cake (13g)',  13,  60, 1.0, 12.0, 1.0, 'label', 'Quaker'),

('Quaker Rice Cakes, Caramel Corn',
    '1 cake (13g)',  13,  50, 1.0, 11.0, 0.0, 'label', 'Quaker'),

-- ── Seaweed Snacks ───────────────────────────────────────────────────────────
('gimMe Organic Roasted Seaweed',
    '1 pack (5g)',  5,  20, 1.0, 1.0, 1.0, 'label', 'gimMe'),

('SeaSnax Roasted Seaweed',
    '1 pack (5g)',  5,  15, 1.0, 1.0, 0.5, 'label', 'SeaSnax'),

-- ── Applesauce ───────────────────────────────────────────────────────────────
('GoGo squeeZ Applesauce',
    '1 pouch (90g)',  90,  60, 0.0, 14.0, 0.0, 'label', 'GoGo squeeZ'),

('Mott''s Applesauce, Unsweetened',
    '1 cup (111g)',  111,  50, 0.0, 13.0, 0.0, 'label', 'Mott''s'),

-- ── Roasted Chickpeas & Legume Snacks ────────────────────────────────────────
('Biena Roasted Chickpeas, Sea Salt',
    '1 oz (28g)',  28,  120, 5.0, 17.0, 4.0, 'label', 'Biena'),

('Biena Roasted Chickpeas, Habanero',
    '1 oz (28g)',  28,  120, 5.0, 17.0, 4.0, 'label', 'Biena'),

('Wonderful Pistachios, Roasted & Salted',
    '1 oz in shell (30g)',  30,  160, 6.0, 8.0, 13.0, 'label', 'Wonderful'),

-- ── Nut Butters (single-serve) ───────────────────────────────────────────────
('Justin''s Classic Peanut Butter Squeeze Pack',
    '1 pack (32g)',  32,  190, 8.0, 7.0, 16.0, 'label', 'Justin''s'),

('Justin''s Almond Butter Squeeze Pack',
    '1 pack (32g)',  32,  190, 6.0, 7.0, 16.0, 'label', 'Justin''s'),

('RX Nut Butter, Chocolate Peanut Butter',
    '1 pack (32g)',  32,  180, 7.0, 10.0, 12.0, 'label', 'RXBAR');
