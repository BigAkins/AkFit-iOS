-- =============================================================================
-- Migration: 20260402000001_fast_food_chick_fil_a
-- Purpose:   Adds Chick-fil-A menu items to generic_foods so they appear in
--            the primary Supabase search tier.
--
-- Source: Chick-fil-A official published nutrition information.
--         Values reflect standard U.S. menu items as of the time of this
--         migration. Source field = 'chick_fil_a'; brand = 'Chick-fil-A'.
--
-- Naming convention: "Chick-fil-A [Item Name]"
--   - Searching "chick-fil-a" or "chick fil a" → all items
--   - Searching "chicken sandwich" → found via substring
--   - Searching "nuggets" → found via substring
--
-- Items cover: chicken sandwiches, nuggets, wraps, breakfast, sides, sauces,
-- and desserts.
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Chicken Sandwiches ───────────────────────────────────────────────────────
('Chick-fil-A Chicken Sandwich',
    '1 sandwich (200g)',  200,  440, 28.0, 40.0, 19.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Spicy Chicken Sandwich',
    '1 sandwich (210g)',  210,  450, 28.0, 42.0, 19.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Deluxe Sandwich',
    '1 sandwich (234g)',  234,  500, 29.0, 42.0, 23.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Spicy Deluxe Sandwich',
    '1 sandwich (244g)',  244,  550, 30.0, 45.0, 25.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Grilled Chicken Sandwich',
    '1 sandwich (230g)',  230,  320, 28.0, 39.0, 6.0, 'chick_fil_a', 'Chick-fil-A'),

-- ── Nuggets ──────────────────────────────────────────────────────────────────
('Chick-fil-A Nuggets (8-count)',
    '8 pieces (113g)',  113,  250, 27.0, 11.0, 11.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Nuggets (12-count)',
    '12 pieces (170g)',  170,  380, 40.0, 17.0, 17.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Grilled Nuggets (8-count)',
    '8 pieces (113g)',  113,  130, 25.0, 1.0, 3.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Grilled Nuggets (12-count)',
    '12 pieces (170g)',  170,  200, 38.0, 2.0, 4.5, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Chick-n-Strips (3-count)',
    '3 strips (152g)',  152,  310, 28.0, 16.0, 15.0, 'chick_fil_a', 'Chick-fil-A'),

-- ── Wraps ────────────────────────────────────────────────────────────────────
('Chick-fil-A Cool Wrap',
    '1 wrap (281g)',  281,  350, 42.0, 29.0, 13.0, 'chick_fil_a', 'Chick-fil-A'),

-- ── Breakfast ────────────────────────────────────────────────────────────────
('Chick-fil-A Chicken Biscuit',
    '1 biscuit (176g)',  176,  440, 17.0, 48.0, 20.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Chick-n-Minis (4-count)',
    '4 pieces (144g)',  144,  360, 15.0, 42.0, 14.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Hash Brown Scramble Burrito',
    '1 burrito (253g)',  253,  700, 30.0, 51.0, 42.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Egg White Grill',
    '1 sandwich (146g)',  146,  300, 25.0, 31.0, 7.0, 'chick_fil_a', 'Chick-fil-A'),

-- ── Sides ────────────────────────────────────────────────────────────────────
('Chick-fil-A Waffle Fries (medium)',
    '1 medium (125g)',  125,  420, 5.0, 45.0, 24.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Waffle Fries (large)',
    '1 large (170g)',  170,  560, 7.0, 60.0, 32.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Mac & Cheese (medium)',
    '1 medium (198g)',  198,  310, 12.0, 31.0, 15.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Chicken Noodle Soup (medium)',
    '1 bowl (354g)',  354,  200, 18.0, 18.0, 6.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Fruit Cup (medium)',
    '1 cup (142g)',  142,  60, 1.0, 16.0, 0.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Side Salad',
    '1 salad (131g)',  131,  80, 5.0, 6.0, 5.0, 'chick_fil_a', 'Chick-fil-A'),

-- ── Sauces ───────────────────────────────────────────────────────────────────
('Chick-fil-A Sauce',
    '1 packet (28g)',  28,  140, 0.0, 7.0, 13.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Polynesian Sauce',
    '1 packet (28g)',  28,  110, 0.0, 13.0, 6.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Garden Herb Ranch Sauce',
    '1 packet (28g)',  28,  140, 0.0, 2.0, 15.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Honey Mustard Sauce',
    '1 packet (28g)',  28,  50, 0.0, 9.0, 2.0, 'chick_fil_a', 'Chick-fil-A'),

-- ── Treats & Drinks ──────────────────────────────────────────────────────────
('Chick-fil-A Icedream Cone',
    '1 cone (198g)',  198,  170, 4.0, 30.0, 4.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Chocolate Chunk Cookie',
    '1 cookie (57g)',  57,  370, 5.0, 44.0, 19.0, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Lemonade (medium)',
    '1 medium (510ml)',  510,  220, 0.0, 58.0, 0.5, 'chick_fil_a', 'Chick-fil-A'),

('Chick-fil-A Milkshake, Cookies & Cream (small)',
    '1 small (397g)',  397,  550, 14.0, 78.0, 22.0, 'chick_fil_a', 'Chick-fil-A');
