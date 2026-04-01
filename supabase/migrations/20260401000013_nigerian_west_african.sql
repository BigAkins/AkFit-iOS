-- =============================================================================
-- Migration: 20260401000013_nigerian_west_african
-- Purpose:   Adds practical Nigerian / West African food coverage to
--            generic_foods so common searches resolve in Supabase instead
--            of falling through to the Open Food Facts fallback.
--
-- Coverage: swallows (pounded yam, eba, amala, semo, fufu), jollof rice,
--           Nigerian fried rice, soups (egusi, ogbono, okra, efo riro,
--           pepper soup, banga), suya, kilishi, moi moi, akara, beans
--           porridge, fried/roasted/boiled plantain, boiled/fried yam,
--           meat pie, puff puff, chin chin, kuli kuli, akamu/ogi,
--           nkwobi, zobo drink.
--
-- Sources:
--   FAO/INFOODS West African Food Composition Table (2012) — Nigerian-specific
--   and West African dishes. Identifier: source = 'west_african_fct'.
--   Values are per 100 g edible portion as prepared.
--
--   USDA FoodData Central SR Legacy — boiled yam, boiled plantain.
--   Identifier: source = 'usda'.
--
-- Note: "White Rice, cooked" is already present in the DB from an earlier
-- seed; it is not duplicated here.
--
-- Naming convention: plain descriptive names, no brand prefix.
--   Searching "pounded yam" → exact / prefix match
--   Searching "jollof"      → substring match
--   Searching "egusi"       → first-word / substring match
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source)
values

-- ══════════════════════════════════════════════════════════════════════════════
-- SWALLOWS
-- Starchy staples served with soups; eaten by hand, rolled into balls.
-- FAO/INFOODS West African FCT values are per 100 g cooked weight.
-- ══════════════════════════════════════════════════════════════════════════════

-- Pounded Yam — 107 kcal / 100 g; 1.6 g P / 25.3 g C / 0.1 g F
-- Boiled white yam pounded smooth; smooth, stretchy texture
('Pounded Yam',
    '1 small ball (150g)',     150,  161,  2.4, 38.0,  0.2, 'west_african_fct'),
('Pounded Yam',
    '1 medium ball (250g)',    250,  268,  4.0, 63.3,  0.3, 'west_african_fct'),

-- Eba — 157 kcal / 100 g; 1.2 g P / 37.6 g C / 0.2 g F
-- Fermented cassava flour (garri) stirred into boiling water; firm, slightly sour
('Eba',
    '1 small ball (150g)',     150,  236,  1.8, 56.4,  0.3, 'west_african_fct'),
('Eba',
    '1 medium ball (250g)',    250,  393,  3.0, 94.0,  0.5, 'west_african_fct'),

-- Amala — 122 kcal / 100 g; 2.1 g P / 28.2 g C / 0.1 g F
-- Dried yam flour (elubo) swallow; dark colour, earthy flavour
('Amala',
    '1 small ball (150g)',     150,  183,  3.2, 42.3,  0.2, 'west_african_fct'),
('Amala',
    '1 medium ball (250g)',    250,  305,  5.3, 70.5,  0.3, 'west_african_fct'),

-- Semo — 155 kcal / 100 g; 3.6 g P / 33.4 g C / 0.5 g F
-- Wheat semolina swallow; smooth, light, mild flavour
('Semo',
    '1 medium ball (250g)',    250,  388,  9.0, 83.5,  1.3, 'west_african_fct'),

-- Fufu (Cassava Fufu) — 128 kcal / 100 g; 0.5 g P / 31.1 g C / 0.1 g F
-- Fermented cassava paste; more sour than eba, dense texture
('Fufu',
    '1 small ball (150g)',     150,  192,  0.8, 46.7,  0.2, 'west_african_fct'),
('Fufu',
    '1 medium ball (250g)',    250,  320,  1.3, 77.8,  0.3, 'west_african_fct'),

-- ══════════════════════════════════════════════════════════════════════════════
-- RICE DISHES
-- ══════════════════════════════════════════════════════════════════════════════

-- Jollof Rice — 175 kcal / 100 g; 3.5 g P / 33.8 g C / 3.2 g F
-- Tomato-based one-pot rice with palm/vegetable oil and spices; no meat included
('Jollof Rice',
    '1 cup (200g)',            200,  350,  7.0, 67.6,  6.4, 'west_african_fct'),
('Jollof Rice',
    '½ cup (100g)',            100,  175,  3.5, 33.8,  3.2, 'west_african_fct'),

-- Nigerian Fried Rice — 190 kcal / 100 g; 5.2 g P / 32.5 g C / 4.4 g F
-- Cooked with mixed vegetables, liver, and seasoning; slightly higher protein
('Nigerian Fried Rice',
    '1 cup (200g)',            200,  380, 10.4, 65.0,  8.8, 'west_african_fct'),

-- ══════════════════════════════════════════════════════════════════════════════
-- SOUPS
-- Values per 100 g prepared soup (without swallow).
-- High fat reflects generous palm oil use in West African cooking.
-- ══════════════════════════════════════════════════════════════════════════════

-- Egusi Soup — 265 kcal / 100 g; 12.5 g P / 6.8 g C / 21.4 g F
-- Ground melon seeds sautéed in palm oil with leafy greens and assorted meat
('Egusi Soup',
    '1 serving (100g)',        100,  265, 12.5,  6.8, 21.4, 'west_african_fct'),

-- Ogbono Soup — 228 kcal / 100 g; 10.1 g P / 5.2 g C / 18.6 g F
-- Wild mango seed (drawing soup); viscous, mucilaginous texture
('Ogbono Soup',
    '1 serving (100g)',        100,  228, 10.1,  5.2, 18.6, 'west_african_fct'),

-- Okra Soup — 140 kcal / 100 g; 7.5 g P / 6.2 g C / 10.0 g F
-- Chopped okra with palm oil, crayfish, and assorted seafood or meat
('Okra Soup',
    '1 serving (100g)',        100,  140,  7.5,  6.2, 10.0, 'west_african_fct'),

-- Efo Riro (Spinach Stew) — 155 kcal / 100 g; 9.8 g P / 4.8 g C / 11.2 g F
-- Leafy green stew with palm oil, assorted meats, and locust beans
('Efo Riro',
    '1 serving (100g)',        100,  155,  9.8,  4.8, 11.2, 'west_african_fct'),

-- Pepper Soup — 82 kcal / 100 g; 11.5 g P / 2.8 g C / 3.1 g F
-- Light broth with assorted meat or fish and aromatic Nigerian spices; low-fat
('Pepper Soup',
    '1 cup (240g)',            240,  197, 27.6,  6.7,  7.4, 'west_african_fct'),

-- Banga Soup (Ofe Akwu) — 198 kcal / 100 g; 7.8 g P / 5.0 g C / 16.5 g F
-- Creamy palm nut soup with herbs; popular in the Niger Delta region
('Banga Soup',
    '1 serving (100g)',        100,  198,  7.8,  5.0, 16.5, 'west_african_fct'),

-- ══════════════════════════════════════════════════════════════════════════════
-- GRILLED / DRIED MEAT
-- ══════════════════════════════════════════════════════════════════════════════

-- Suya — 184 kcal / 100 g; 24.2 g P / 2.1 g C / 9.1 g F
-- Thin-sliced spiced beef or chicken grilled on skewers over open flame;
-- values reflect lean beef suya before garnish
('Suya',
    '1 skewer (85g)',           85,  156, 20.6,  1.8,  7.7, 'west_african_fct'),
('Suya',
    '100g',                    100,  184, 24.2,  2.1,  9.1, 'west_african_fct'),

-- Kilishi — 412 kcal / 100 g; 61.5 g P / 17.4 g C / 10.8 g F
-- Sun-dried, spiced, flattened meat (Nigerian jerky); very high protein density
('Kilishi',
    '1 oz (28g)',               28,  115, 17.2,  4.9,  3.0, 'west_african_fct'),

-- ══════════════════════════════════════════════════════════════════════════════
-- BEANS DISHES
-- ══════════════════════════════════════════════════════════════════════════════

-- Moi Moi (Steamed Bean Pudding) — 128 kcal / 100 g; 7.8 g P / 15.6 g C / 3.9 g F
-- Steamed black-eyed pea pudding with oil, crayfish, and boiled eggs
('Moi Moi',
    '1 wrap (150g)',           150,  192, 11.7, 23.4,  5.9, 'west_african_fct'),
('Moi Moi',
    '1 small wrap (100g)',     100,  128,  7.8, 15.6,  3.9, 'west_african_fct'),

-- Akara (Bean Fritters) — 218 kcal / 100 g; 7.6 g P / 19.4 g C / 12.0 g F
-- Deep-fried black-eyed pea fritters; popular street breakfast food
('Akara',
    '2 pieces (80g)',           80,  174,  6.1, 15.5,  9.6, 'west_african_fct'),
('Akara',
    '4 pieces (160g)',         160,  349, 12.2, 31.0, 19.2, 'west_african_fct'),

-- Beans Porridge — 152 kcal / 100 g; 8.5 g P / 20.8 g C / 3.6 g F
-- Cowpeas cooked with palm oil, crayfish, and seasoning cubes
('Beans Porridge',
    '1 cup (240g)',            240,  365, 20.4, 49.9,  8.6, 'west_african_fct'),

-- ══════════════════════════════════════════════════════════════════════════════
-- PLANTAIN & YAM
-- ══════════════════════════════════════════════════════════════════════════════

-- Fried Plantain (Dodo) — 225 kcal / 100 g; 1.4 g P / 39.8 g C / 7.5 g F
-- Ripe plantain sliced and fried in oil; common side dish or snack
('Fried Plantain',
    '½ plantain (100g)',       100,  225,  1.4, 39.8,  7.5, 'west_african_fct'),
('Fried Plantain',
    '1 medium plantain (200g)', 200, 450,  2.8, 79.6, 15.0, 'west_african_fct'),

-- Roasted Plantain (Bole) — 149 kcal / 100 g; 1.3 g P / 37.6 g C / 0.4 g F
-- Unripe plantain grilled whole over charcoal; often served with roasted fish
('Roasted Plantain (Bole)',
    '1 medium (150g)',         150,  224,  2.0, 56.4,  0.6, 'west_african_fct'),

-- Boiled Plantain — USDA FoodData Central SR Legacy; 122 kcal / 100 g
-- 1.3 g P / 31.9 g C / 0.4 g F per 100 g
('Boiled Plantain',
    '1 cup sliced (148g)',     148,  181,  1.9, 47.2,  0.6, 'usda'),

-- Boiled Yam — USDA FoodData Central SR Legacy; 118 kcal / 100 g
-- 1.5 g P / 27.9 g C / 0.2 g F per 100 g
('Boiled Yam',
    '1 cup cubed (136g)',      136,  161,  2.0, 37.9,  0.3, 'usda'),
('Boiled Yam',
    '½ cup cubed (68g)',        68,   80,  1.0, 19.0,  0.1, 'usda'),

-- Fried Yam — 194 kcal / 100 g; 1.4 g P / 34.2 g C / 6.0 g F
-- Yam slices deep-fried; popular street food and side dish
('Fried Yam',
    '5–6 pieces (100g)',       100,  194,  1.4, 34.2,  6.0, 'west_african_fct'),

-- ══════════════════════════════════════════════════════════════════════════════
-- SNACKS & STREET FOOD
-- ══════════════════════════════════════════════════════════════════════════════

-- Nigerian Meat Pie — 282 kcal / 100 g; 7.8 g P / 30.5 g C / 14.0 g F
-- Shortcrust pastry filled with spiced minced meat, potatoes, and carrots
('Nigerian Meat Pie',
    '1 pie (160g)',            160,  451, 12.5, 48.8, 22.4, 'west_african_fct'),

-- Puff Puff — 345 kcal / 100 g; 4.8 g P / 46.5 g C / 16.0 g F
-- Deep-fried sweet yeast dough balls; popular street snack and party food
('Puff Puff',
    '3 pieces (80g)',           80,  276,  3.8, 37.2, 12.8, 'west_african_fct'),
('Puff Puff',
    '6 pieces (160g)',         160,  552,  7.7, 74.4, 25.6, 'west_african_fct'),

-- Chin Chin — 476 kcal / 100 g; 7.5 g P / 64.8 g C / 21.4 g F
-- Hard, crunchy fried dough snack; made with flour, sugar, and butter
('Chin Chin',
    '¼ cup (30g)',              30,  143,  2.3, 19.4,  6.4, 'west_african_fct'),
('Chin Chin',
    '1 oz (28g)',               28,  133,  2.1, 18.1,  6.0, 'west_african_fct'),

-- Kuli Kuli — 530 kcal / 100 g; 23.1 g P / 34.8 g C / 34.5 g F
-- Crunchy groundnut (peanut) cake; high protein, popular in Northern Nigeria
('Kuli Kuli',
    '1 oz (28g)',               28,  148,  6.5,  9.7,  9.7, 'west_african_fct'),

-- ══════════════════════════════════════════════════════════════════════════════
-- OTHER
-- ══════════════════════════════════════════════════════════════════════════════

-- Akamu / Ogi (Fermented Corn Pap) — 51 kcal / 100 g; 0.9 g P / 11.4 g C / 0.3 g F
-- Thin fermented cereal porridge; eaten for breakfast or as complementary food
('Akamu (Ogi)',
    '1 cup (240g)',            240,  122,  2.2, 27.4,  0.7, 'west_african_fct'),

-- Nkwobi — 200 kcal / 100 g; 12.4 g P / 4.2 g C / 15.3 g F
-- Spicy cow foot dressed in palm oil, utazi leaves, and crayfish;
-- popular at social gatherings in Eastern Nigeria
('Nkwobi',
    '1 serving (150g)',        150,  300, 18.6,  6.3, 23.0, 'west_african_fct'),

-- Zobo Drink — 15 kcal / 100 ml; 0.2 g P / 3.5 g C / 0.0 g F
-- Chilled hibiscus (roselle) drink sweetened with sugar and pineapple; very low calorie
('Zobo Drink',
    '1 cup (240ml)',           240,   36,  0.5,  8.4,  0.0, 'west_african_fct');
