-- =============================================================================
-- Migration: 20260401000011_desserts
-- Purpose:   Adds practical dessert coverage to generic_foods so common sweet-
--            treat searches resolve in Supabase instead of falling through to
--            the noisy Open Food Facts fallback.
--
-- Coverage: ice cream, frozen yogurt, ice pop, cookies, brownies, cheesecake,
--           donuts, cake slices, chocolate, pie, and muffins.
--
-- Source: USDA FoodData Central (SR Legacy / Foundation Foods).
--         Values per declared serving_label / serving_weight_g.
--         Serving sizes follow U.S. consumer standards (cups, slices, pieces).
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source)
values

-- ── Ice Cream ─────────────────────────────────────────────────────────────────
-- USDA SR Legacy: Ice creams, vanilla — 207 kcal / 100g
-- 3.51g P / 23.61g C / 11.01g F per 100g
('Ice Cream, vanilla',
    '½ cup (66g)',              66,  137,  2.3, 15.6,  7.3, 'usda'),
('Ice Cream, vanilla',
    '1 cup (132g)',            132,  273,  4.6, 31.2, 14.5, 'usda'),

-- USDA SR Legacy: Ice creams, chocolate — 216 kcal / 100g
('Ice Cream, chocolate',
    '½ cup (66g)',              66,  143,  2.5, 18.6,  7.3, 'usda'),

-- USDA SR Legacy: Ice creams, strawberry — 192 kcal / 100g
('Ice Cream, strawberry',
    '½ cup (66g)',              66,  127,  2.1, 18.2,  5.6, 'usda'),

-- USDA: Frozen yogurt, vanilla soft serve — 159 kcal / 100g
('Frozen Yogurt, vanilla',
    '½ cup (72g)',              72,  115,  2.7, 17.5,  3.6, 'usda'),

-- USDA: Frozen juice bars / ice pops — 69 kcal / 100g; fat-free treat
('Ice Pop',
    '1 bar (77g)',              77,   53,  0.1, 13.8,  0.1, 'usda'),

-- ── Cookies ───────────────────────────────────────────────────────────────────
-- USDA SR Legacy: Cookies, chocolate chip, commercially prepared — 471 kcal / 100g
-- 5.41g P / 62.82g C / 22.52g F per 100g
('Chocolate Chip Cookie',
    '1 cookie (16g)',           16,   75,  0.9, 10.1,  3.6, 'usda'),
('Chocolate Chip Cookie',
    '2 cookies (32g)',          32,  151,  1.7, 20.2,  7.2, 'usda'),

-- USDA SR Legacy: Cookies, sandwich, with creme filling, chocolate (Oreo-type)
-- 473 kcal / 100g; 5.11g P / 70.41g C / 20.03g F
-- Standard commercial serving = 3 cookies (34g)
('Sandwich Cookie, chocolate creme',
    '3 cookies (34g)',          34,  161,  1.7, 23.9,  6.8, 'usda'),

-- USDA SR Legacy: Cookies, sugar, commercially prepared — 456 kcal / 100g
('Sugar Cookie',
    '2 cookies (28g)',          28,  128,  1.4, 17.9,  5.9, 'usda'),

-- USDA SR Legacy: Cookies, oatmeal, commercially prepared with raisins
-- ~432 kcal / 100g; 5.5g P / 67.6g C / 15.4g F
('Oatmeal Raisin Cookie',
    '1 cookie (23g)',           23,   99,  1.3, 15.6,  3.5, 'usda'),
('Oatmeal Raisin Cookie',
    '2 cookies (46g)',          46,  199,  2.5, 31.2,  7.1, 'usda'),

-- ── Brownies ──────────────────────────────────────────────────────────────────
-- USDA SR Legacy: Brownies, commercially prepared — 415 kcal / 100g
-- 5.11g P / 63.2g C / 17.2g F per 100g
-- Small square ≈ 45g; bakery / restaurant brownie ≈ 60g
('Brownie',
    '1 brownie (45g)',          45,  187,  2.3, 28.4,  7.7, 'usda'),
('Brownie',
    '1 large brownie (60g)',    60,  249,  3.1, 37.9, 10.3, 'usda'),

-- ── Cheesecake ────────────────────────────────────────────────────────────────
-- USDA SR Legacy: Cheesecake, commercially prepared — 321 kcal / 100g
-- 5.49g P / 25.48g C / 22.46g F per 100g
('Cheesecake',
    '1 slice (80g)',            80,  257,  4.4, 20.4, 18.0, 'usda'),
('Cheesecake',
    '1 large slice (125g)',    125,  401,  6.9, 31.9, 28.1, 'usda'),

-- ── Donuts ────────────────────────────────────────────────────────────────────
-- USDA SR Legacy: Doughnuts, cake-type, plain — 391 kcal / 100g
('Donut, cake',
    '1 donut (47g)',            47,  184,  2.4, 22.1,  9.9, 'usda'),

-- USDA SR Legacy: Doughnuts, yeast-leavened, glazed — 403 kcal / 100g
('Donut, glazed',
    '1 donut (60g)',            60,  242,  3.2, 28.7, 13.1, 'usda'),

-- USDA SR Legacy: Doughnuts, yeast-leavened, with jelly filling
-- ~320 kcal / 100g; 4.7g P / 50.0g C / 11.0g F
('Donut, jelly-filled',
    '1 donut (85g)',            85,  272,  4.0, 42.5,  9.4, 'usda'),

-- ── Cake ──────────────────────────────────────────────────────────────────────
-- USDA SR Legacy: Cakes, chocolate, commercially prepared with chocolate frosting
-- 367 kcal / 100g; 3.9g P / 57.0g C / 14.7g F
-- 1 slice = 1/12 of a 2-layer 9-inch cake ≈ 95g
('Cake, chocolate with frosting',
    '1 slice (95g)',            95,  349,  3.7, 54.2, 14.0, 'usda'),

-- USDA SR Legacy: Cakes, yellow, commercially prepared with vanilla frosting
-- 369 kcal / 100g; 3.5g P / 57.8g C / 14.5g F
('Cake, yellow with frosting',
    '1 slice (95g)',            95,  351,  3.3, 55.1, 13.8, 'usda'),

-- ── Chocolate ─────────────────────────────────────────────────────────────────
-- USDA FDC: Chocolate, dark, 70–85% cacao solids
-- 598 kcal / 100g; 7.79g P / 45.90g C / 42.63g F
('Chocolate, dark (70%+ cacao)',
    '1 oz (28g)',               28,  167,  2.2, 12.9, 11.9, 'usda'),
('Chocolate, dark (70%+ cacao)',
    '3.5 oz bar (100g)',       100,  598,  7.8, 45.9, 42.6, 'usda'),

-- USDA SR Legacy: Candies, milk chocolate — 535 kcal / 100g
-- 7.65g P / 59.36g C / 29.66g F per 100g
('Chocolate, milk',
    '1 oz (28g)',               28,  150,  2.2, 16.6,  8.3, 'usda'),
('Chocolate, milk',
    '1.5 oz bar (43g)',         43,  230,  3.3, 25.5, 12.8, 'usda'),

-- ── Pie ───────────────────────────────────────────────────────────────────────
-- USDA SR Legacy: Pie, apple, commercially prepared — 237 kcal / 100g
-- 1 slice = 1/8 of a 9-inch pie ≈ 125g
('Pie, apple',
    '1 slice (125g)',          125,  296,  2.1, 42.5, 12.5, 'usda'),

-- USDA SR Legacy: Pie, pumpkin, commercially prepared — 223 kcal / 100g
-- 4.5g P / 28.3g C / 10.4g F; 1 slice = 1/8 of a 9-inch pie ≈ 109g
('Pie, pumpkin',
    '1 slice (109g)',          109,  243,  4.9, 30.8, 11.3, 'usda'),

-- ── Muffins ───────────────────────────────────────────────────────────────────
-- USDA SR Legacy: Muffins, blueberry, commercially prepared — 377 kcal / 100g
-- 5.5g P / 54.2g C / 16.0g F; standard bakery / Costco-style muffin ≈ 113g
('Muffin, blueberry',
    '1 muffin (113g)',         113,  426,  6.2, 61.4, 18.1, 'usda');
