-- =============================================================================
-- Migration: 20260331000000_fix_goal_height_weight_types
--
-- Root cause: PostgREST serializes `numeric` columns as JSON strings to
-- preserve precision. The Swift client decodes `height_cm` and `weight_kg`
-- as `Double?`, which JSONDecoder cannot produce from a JSON string, causing
-- a DecodingError.typeMismatch and the generic "Couldn't save your targets"
-- error on the onboarding Results screen.
--
-- Fix: change both columns to `integer`. The app already rounds and inserts
-- integer values, so no precision is lost. PostgREST returns `integer`
-- columns as JSON numbers, which JSONDecoder decodes to Double correctly.
-- =============================================================================

alter table public.user_goals
    alter column height_cm type integer using height_cm::integer,
    alter column weight_kg type integer using weight_kg::integer;
