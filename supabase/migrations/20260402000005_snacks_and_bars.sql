-- =============================================================================
-- Migration: 20260402000005_snacks_and_bars
-- Purpose:   Adds common U.S. packaged snack foods, protein bars, yogurt cups,
--            and convenience items to generic_foods.
--
-- Source: Official product nutrition labels (printed label / brand websites).
--         Source field = 'label'; brand = product brand name.
--
-- Serving sizes follow the on-package "Nutrition Facts" serving size.
-- For chip-type snacks, 1 oz (28g) is the standard single-serve reference;
-- multi-serve bags use the same per-serving data.
--
-- Naming convention: "[Brand] [Product Name]"
-- =============================================================================

insert into public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
values

-- ── Chips & Salty Snacks ─────────────────────────────────────────────────────
('Cheetos Crunchy',
    '1 oz (28g)',  28,  150, 2.0, 13.0, 10.0, 'label', 'Cheetos'),

('Cheetos Flamin'' Hot',
    '1 oz (28g)',  28,  160, 2.0, 13.0, 11.0, 'label', 'Cheetos'),

('Cheetos Puffs',
    '1 oz (28g)',  28,  160, 2.0, 13.0, 10.0, 'label', 'Cheetos'),

('Takis Fuego',
    '1 oz (28g)',  28,  140, 2.0, 16.0, 8.0, 'label', 'Takis'),

('Takis Blue Heat',
    '1 oz (28g)',  28,  140, 2.0, 16.0, 8.0, 'label', 'Takis'),

('Lay''s Classic Potato Chips',
    '1 oz (28g)',  28,  160, 2.0, 15.0, 10.0, 'label', 'Lay''s'),

('Lay''s Barbecue Potato Chips',
    '1 oz (28g)',  28,  150, 2.0, 15.0, 9.0, 'label', 'Lay''s'),

('Doritos Nacho Cheese',
    '1 oz (28g)',  28,  140, 2.0, 18.0, 7.0, 'label', 'Doritos'),

('Doritos Cool Ranch',
    '1 oz (28g)',  28,  140, 2.0, 18.0, 7.0, 'label', 'Doritos'),

('Doritos Spicy Sweet Chili',
    '1 oz (28g)',  28,  140, 2.0, 18.0, 7.0, 'label', 'Doritos'),

('Ruffles Original',
    '1 oz (28g)',  28,  160, 2.0, 14.0, 10.0, 'label', 'Ruffles'),

('Ruffles Cheddar & Sour Cream',
    '1 oz (28g)',  28,  160, 2.0, 14.0, 10.0, 'label', 'Ruffles'),

('Tostitos Scoops',
    '1 oz (28g)',  28,  140, 2.0, 19.0, 7.0, 'label', 'Tostitos'),

('Pringles Original',
    '1 oz (28g)',  28,  150, 1.0, 15.0, 9.0, 'label', 'Pringles'),

('Pringles Sour Cream & Onion',
    '1 oz (28g)',  28,  150, 1.0, 15.0, 9.0, 'label', 'Pringles'),

-- ── Popcorn ──────────────────────────────────────────────────────────────────
('SkinnyPop Original Popcorn',
    '1 oz (28g)',  28,  150, 2.0, 15.0, 10.0, 'label', 'SkinnyPop'),

('Smartfood White Cheddar Popcorn',
    '1 oz (28g)',  28,  160, 2.0, 14.0, 10.0, 'label', 'Smartfood'),

('Boom Chicka Pop Sea Salt Popcorn',
    '1 oz (28g)',  28,  140, 2.0, 16.0, 8.0, 'label', 'Angie''s'),

-- ── Crackers & Pretzels ──────────────────────────────────────────────────────
('Goldfish Crackers (Cheddar)',
    '1 oz (30g)',  30,  140, 4.0, 20.0, 5.0, 'label', 'Goldfish'),

('Ritz Crackers',
    '5 crackers (16g)',  16,  80, 1.0, 10.0, 4.0, 'label', 'Ritz'),

('Snyder''s Pretzels',
    '1 oz (28g)',  28,  110, 3.0, 23.0, 1.0, 'label', 'Snyder''s'),

-- ── Protein Bars ─────────────────────────────────────────────────────────────
('Quest Bar, Chocolate Chip Cookie Dough',
    '1 bar (60g)',  60,  190, 21.0, 21.0, 7.0, 'label', 'Quest'),

('Quest Bar, Cookies & Cream',
    '1 bar (60g)',  60,  190, 21.0, 22.0, 7.0, 'label', 'Quest'),

('RXBAR Chocolate Sea Salt',
    '1 bar (52g)',  52,  210, 12.0, 24.0, 9.0, 'label', 'RXBAR'),

('RXBAR Peanut Butter',
    '1 bar (52g)',  52,  210, 12.0, 23.0, 9.0, 'label', 'RXBAR'),

('KIND Protein, Dark Chocolate Nut',
    '1 bar (50g)',  50,  250, 12.0, 17.0, 17.0, 'label', 'KIND'),

('Clif Bar, Chocolate Chip',
    '1 bar (68g)',  68,  250, 10.0, 44.0, 5.0, 'label', 'Clif'),

('Clif Bar, Crunchy Peanut Butter',
    '1 bar (68g)',  68,  250, 11.0, 42.0, 6.0, 'label', 'Clif'),

('ONE Bar, Birthday Cake',
    '1 bar (60g)',  60,  220, 20.0, 23.0, 8.0, 'label', 'ONE'),

('Built Bar, Coconut Almond',
    '1 bar (49g)',  49,  130, 17.0, 15.0, 3.0, 'label', 'Built Bar'),

-- ── Yogurt ───────────────────────────────────────────────────────────────────
('Chobani Greek Yogurt, Plain Nonfat',
    '1 container (150g)',  150,  90, 15.0, 6.0, 0.0, 'label', 'Chobani'),

('Chobani Greek Yogurt, Strawberry',
    '1 container (150g)',  150,  120, 12.0, 15.0, 0.0, 'label', 'Chobani'),

('Chobani Greek Yogurt, Vanilla',
    '1 container (150g)',  150,  120, 12.0, 14.0, 0.0, 'label', 'Chobani'),

('Fage Total 0% Greek Yogurt',
    '1 container (200g)',  200,  90, 18.0, 5.0, 0.0, 'label', 'Fage'),

('Fage Total 2% Greek Yogurt',
    '1 container (200g)',  200,  140, 20.0, 8.0, 3.5, 'label', 'Fage'),

('Oikos Triple Zero, Mixed Berry',
    '1 container (150g)',  150,  100, 15.0, 7.0, 0.0, 'label', 'Oikos'),

-- ── Hummus & Dips ────────────────────────────────────────────────────────────
('Sabra Classic Hummus',
    '2 tbsp (28g)',  28,  70, 2.0, 5.0, 5.0, 'label', 'Sabra'),

('Sabra Classic Hummus Singles',
    '1 cup (57g)',  57,  150, 3.0, 7.0, 12.0, 'label', 'Sabra'),

('Sabra Roasted Red Pepper Hummus',
    '2 tbsp (28g)',  28,  70, 2.0, 5.0, 5.0, 'label', 'Sabra'),

-- ── Nuts & Trail Mix ─────────────────────────────────────────────────────────
('Blue Diamond Almonds, Whole Natural',
    '1 oz (28g)',  28,  170, 6.0, 6.0, 15.0, 'label', 'Blue Diamond'),

('Planters Dry Roasted Peanuts',
    '1 oz (28g)',  28,  170, 7.0, 5.0, 14.0, 'label', 'Planters'),

('Planters Trail Mix, Nuts & Chocolate',
    '1 oz (28g)',  28,  140, 4.0, 12.0, 9.0, 'label', 'Planters'),

-- ── Granola & Cereal Bars ────────────────────────────────────────────────────
('Nature Valley Crunchy, Oats ''n Honey',
    '2 bars (42g)',  42,  190, 4.0, 29.0, 7.0, 'label', 'Nature Valley'),

('Nature Valley Protein, Peanut Butter Dark Chocolate',
    '1 bar (40g)',  40,  190, 10.0, 21.0, 8.0, 'label', 'Nature Valley'),

('Quaker Chewy Granola Bar, Chocolate Chip',
    '1 bar (24g)',  24,  100, 1.0, 18.0, 3.0, 'label', 'Quaker'),

-- ── Jerky ────────────────────────────────────────────────────────────────────
('Jack Link''s Original Beef Jerky',
    '1 oz (28g)',  28,  80, 12.0, 5.0, 1.0, 'label', 'Jack Link''s'),

('Jack Link''s Teriyaki Beef Jerky',
    '1 oz (28g)',  28,  80, 11.0, 7.0, 1.0, 'label', 'Jack Link''s');
