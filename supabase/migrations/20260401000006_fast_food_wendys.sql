-- =============================================================================
-- Migration: 20260401000006_fast_food_wendys
-- Purpose:   Adds Wendy's menu items to generic_foods so they appear in the
--            primary Supabase search tier instead of falling through to the
--            noisy Open Food Facts fallback.
--
-- Source: Wendy's USA published nutrition information (official menu data).
--         Values reflect standard U.S. menu items as of the time of this
--         migration. Source field = 'wendys'; brand = 'Wendy''s'.
--
-- Naming convention: "Wendy's [Item Name]"
--   - Searching "wendy"             → all items (prefix match, rank 1)
--   - Searching "wendy's fries"     → fries in 3 sizes (word-prefix, rank 3)
--   - Searching "baconator"         → found via substring (rank 4)
--   - Searching "dave's single"     → found via word match
--   - Searching "frosty"            → found via word match
--
-- Items cover: Dave's burgers, Baconator, chicken sandwiches, nuggets
-- (3 sizes), natural cut fries (3 sizes), chili (2 sizes), Frosty (2 sizes).
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Burgers ───────────────────────────────────────────────────────────────────
-- Dave's Single: 1/4 lb fresh beef, cheese, lettuce, tomato, pickle, onion,
-- ketchup, mayo on a toasted bun
('Wendy''s Dave''s Single',
    '1 sandwich (213g)',      213,  570, 33.0, 39.0, 33.0, 'wendys', 'Wendy''s'),

-- Dave's Double: two 1/4 lb fresh beef patties
('Wendy''s Dave''s Double',
    '1 sandwich (299g)',      299,  840, 55.0, 40.0, 56.0, 'wendys', 'Wendy''s'),

-- Baconator: two 1/4 lb fresh beef patties, 6 strips of bacon, cheese,
-- ketchup, mayo — no lettuce or tomato by default
('Wendy''s Baconator',
    '1 sandwich (345g)',      345,  940, 58.0, 40.0, 62.0, 'wendys', 'Wendy''s'),

('Wendy''s Jr. Bacon Cheeseburger',
    '1 sandwich (154g)',      154,  380, 20.0, 28.0, 22.0, 'wendys', 'Wendy''s'),

-- ── Chicken ───────────────────────────────────────────────────────────────────
-- Spicy Chicken Sandwich: Wendy's signature — breaded and seasoned
('Wendy''s Spicy Chicken Sandwich',
    '1 sandwich (232g)',      232,  520, 34.0, 57.0, 17.0, 'wendys', 'Wendy''s'),

('Wendy''s Grilled Chicken Sandwich',
    '1 sandwich (213g)',      213,  380, 34.0, 36.0, 10.0, 'wendys', 'Wendy''s'),

-- ── Nuggets ───────────────────────────────────────────────────────────────────
('Wendy''s Chicken Nuggets',
    '4 pc (58g)',              58,  170, 10.0,  9.0, 10.0, 'wendys', 'Wendy''s'),

('Wendy''s Chicken Nuggets',
    '6 pc (87g)',              87,  260, 14.0, 14.0, 15.0, 'wendys', 'Wendy''s'),

('Wendy''s Chicken Nuggets',
    '10 pc (145g)',           145,  420, 24.0, 23.0, 25.0, 'wendys', 'Wendy''s'),

-- ── French Fries ──────────────────────────────────────────────────────────────
-- Natural Cut Fries — skin-on, sea salt
('Wendy''s French Fries',
    'Small (113g)',           113,  230,  3.0, 34.0,  9.0, 'wendys', 'Wendy''s'),

('Wendy''s French Fries',
    'Medium (156g)',          156,  320,  4.0, 47.0, 13.0, 'wendys', 'Wendy''s'),

('Wendy''s French Fries',
    'Large (240g)',           240,  490,  7.0, 72.0, 20.0, 'wendys', 'Wendy''s'),

-- ── Chili ─────────────────────────────────────────────────────────────────────
-- Wendy's chili is a practical high-protein fast-food option
('Wendy''s Chili',
    'Small (227g)',           227,  170, 15.0, 17.0,  5.0, 'wendys', 'Wendy''s'),

('Wendy''s Chili',
    'Large (340g)',           340,  260, 23.0, 26.0,  8.0, 'wendys', 'Wendy''s'),

-- ── Frosty ────────────────────────────────────────────────────────────────────
-- Wendy's Frosty — chocolate (original) or vanilla; nutrition values are
-- identical between flavors. Listed as chocolate per the original recipe.
('Wendy''s Frosty',
    'Small (284g)',           284,  310,  8.0, 56.0,  7.0, 'wendys', 'Wendy''s'),

('Wendy''s Frosty',
    'Medium (397g)',          397,  420, 11.0, 73.0, 11.0, 'wendys', 'Wendy''s');
