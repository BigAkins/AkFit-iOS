-- =============================================================================
-- Seed: 028_search_improvements_seed
-- Purpose: New generic_foods rows introduced alongside the comma-stripping
--          trigger update. Fruits, seeds, sweeteners, supplements, flax,
--          hemp hearts, and sliced-fruit variations.
--
-- Extracted from migration 20260403000001_search_improvements so only data
-- statements live in the seed path. The trigger replacement (adds comma
-- to the list of characters stripped during search_text normalization)
-- stays in supabase/migrations.
--
-- The BEFORE INSERT trigger populates search_text on every row below; the
-- trigger is already at the comma-stripping version by the time seeds run.
-- =============================================================================


-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 2: New food entries
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT INTO public.generic_foods
    (food_name, serving_label, serving_weight_g, calories, protein_g, carbs_g, fat_g, source, brand)
VALUES

-- ── Missing Fruits — Whole ──────────────────────────────────────────────────
('Papaya',
    '1 cup cubed (145g)',    145,   62, 0.7, 16.0, 0.4, 'usda', null),
('Papaya',
    '1 medium (500g)',       500,  215, 2.4, 55.0, 1.3, 'usda', null),
('Papaya',
    '1/2 medium (250g)',     250,  107, 1.2, 27.0, 0.7, 'usda', null),

('Mango',
    '1 cup sliced (165g)',   165,   99, 1.4, 25.0, 0.6, 'usda', null),
('Mango',
    '1 medium (336g)',       336,  202, 2.8, 50.0, 1.3, 'usda', null),
('Mango',
    '1/2 medium (168g)',     168,  101, 1.4, 25.0, 0.6, 'usda', null),

('Watermelon',
    '1 cup diced (152g)',    152,   46, 0.9, 11.0, 0.2, 'usda', null),
('Watermelon',
    '1 wedge (286g)',        286,   86, 1.7, 22.0, 0.4, 'usda', null),

('Peach',
    '1 medium (150g)',       150,   59, 1.4, 14.0, 0.4, 'usda', null),
('Peach',
    '1 cup sliced (154g)',   154,   60, 1.4, 15.0, 0.4, 'usda', null),

('Plum',
    '1 medium (66g)',         66,   30, 0.5, 8.0, 0.2, 'usda', null),
('Plum',
    '2 small (132g)',        132,   61, 0.9, 15.0, 0.4, 'usda', null),

('Nectarine',
    '1 medium (142g)',       142,   63, 1.5, 15.0, 0.5, 'usda', null),

('Pear',
    '1 medium (178g)',       178,  101, 0.7, 27.0, 0.2, 'usda', null),
('Pear',
    '1 cup sliced (140g)',   140,   80, 0.5, 21.0, 0.2, 'usda', null),

('Cherries',
    '1 cup (138g)',          138,   87, 1.5, 22.0, 0.3, 'usda', null),
('Cherries',
    '10 cherries (68g)',      68,   43, 0.7, 11.0, 0.1, 'usda', null),

('Coconut, raw',
    '1 cup shredded (80g)',   80,  283, 2.7, 12.0, 27.0, 'usda', null),
('Coconut, raw',
    '1 piece (45g)',          45,  159, 1.5, 7.0, 15.0, 'usda', null),

('Passion Fruit',
    '1 fruit (18g)',          18,   17, 0.4, 4.0, 0.1, 'usda', null),
('Passion Fruit',
    '3 fruits (54g)',         54,   53, 1.3, 13.0, 0.4, 'usda', null),

('Guava',
    '1 fruit (55g)',          55,   37, 1.4, 8.0, 0.5, 'usda', null),
('Guava',
    '1 cup (165g)',          165,  112, 4.2, 24.0, 1.6, 'usda', null),

('Dragon Fruit',
    '1 medium (227g)',       227,  136, 3.0, 29.0, 0.0, 'usda', null),
('Dragon Fruit',
    '1 cup cubed (140g)',    140,   84, 1.8, 18.0, 0.0, 'usda', null),

('Lychee',
    '1 cup (190g)',          190,  125, 1.6, 31.0, 0.8, 'usda', null),
('Lychee',
    '5 fruits (50g)',         50,   33, 0.4, 8.0, 0.2, 'usda', null),

('Pomegranate',
    '1/2 medium (87g)',       87,   72, 1.0, 16.0, 1.0, 'usda', null),
('Pomegranate Seeds',
    '1/2 cup arils (87g)',    87,   72, 1.0, 16.0, 1.0, 'usda', null),

('Persimmon',
    '1 medium (168g)',       168,  118, 1.0, 31.0, 0.3, 'usda', null),

('Tangerine',
    '1 medium (88g)',         88,   47, 0.7, 12.0, 0.3, 'usda', null),

('Apricot',
    '1 medium (35g)',         35,   17, 0.5, 4.0, 0.1, 'usda', null),
('Apricot',
    '3 medium (105g)',       105,   50, 1.4, 12.0, 0.4, 'usda', null),

-- ── Sliced / Half Fruit Variations (for existing fruits) ────────────────────
('Strawberries, sliced',
    '1 cup sliced (166g)',   166,   53, 1.1, 13.0, 0.5, 'usda', null),

('Banana, sliced',
    '1 cup sliced (150g)',   150,  134, 1.6, 34.0, 0.5, 'usda', null),
('Banana',
    '1/2 medium (59g)',       59,   53, 0.6, 14.0, 0.2, 'usda', null),

('Blueberries',
    '1/2 cup (74g)',          74,   42, 0.6, 11.0, 0.2, 'usda', null),

('Raspberries',
    '1/2 cup (62g)',          62,   32, 0.7, 7.0, 0.4, 'usda', null),

('Grapes',
    '1/2 cup (76g)',          76,   52, 0.5, 14.0, 0.1, 'usda', null),

('Pineapple',
    '1 cup chunks (165g)',   165,   82, 0.9, 22.0, 0.2, 'usda', null),

('Kiwi',
    '1 cup sliced (180g)',   180,  110, 2.1, 26.0, 0.9, 'usda', null),

-- ── Seeds, Sweeteners, Supplements ──────────────────────────────────────────
('Chia Seeds',
    '1 tbsp (12g)',           12,   58, 2.0, 5.0, 3.7, 'usda', null),
('Chia Seeds',
    '2 tbsp (24g)',           24,  117, 4.0, 10.0, 7.4, 'usda', null),
('Chia Seeds',
    '1 oz (28g)',             28,  137, 4.7, 12.0, 8.7, 'usda', null),

('Honey',
    '1 tbsp (21g)',           21,   64, 0.1, 17.0, 0.0, 'usda', null),
('Honey',
    '1 tsp (7g)',              7,   21, 0.0, 6.0, 0.0, 'usda', null),

('Agave Nectar',
    '1 tbsp (21g)',           21,   60, 0.0, 16.0, 0.0, 'usda', null),
('Agave Nectar',
    '1 tsp (7g)',              7,   20, 0.0, 5.0, 0.0, 'usda', null),

('Maple Syrup',
    '1 tbsp (20g)',           20,   52, 0.0, 13.0, 0.0, 'usda', null),

('Protein Powder, generic',
    '1 scoop (30g)',          30,  120, 24.0, 3.0, 1.5, 'usda', null),
('Protein Powder, generic',
    '20g serving',            20,   80, 16.0, 2.0, 1.0, 'usda', null),

('Protein Pudding',
    '1 cup (150g)',          150,  140, 20.0, 10.0, 2.5, 'label', null),
('Protein Pudding',
    '1/2 cup (75g)',          75,   70, 10.0, 5.0, 1.3, 'label', null),

-- ── Flax Seeds (commonly paired with chia) ──────────────────────────────────
('Flax Seeds, ground',
    '1 tbsp (7g)',             7,   37, 1.3, 2.0, 3.0, 'usda', null),
('Flax Seeds, ground',
    '2 tbsp (14g)',           14,   74, 2.6, 4.0, 5.9, 'usda', null),

-- ── Hemp Hearts (fitness staple) ────────────────────────────────────────────
('Hemp Hearts',
    '3 tbsp (30g)',           30,  166, 10.0, 2.0, 14.0, 'usda', null);
