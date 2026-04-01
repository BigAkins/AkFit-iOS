-- =============================================================================
-- Migration: 20260331000001_profiles_add_sex_activity_level
--
-- Root cause: sex and activity_level were never persisted to the database.
-- They were collected during onboarding for MacroCalculator only, then
-- discarded. Edit Profile hardcoded Male / Moderately Active as defaults,
-- resetting on every open — making calculation inputs untrustworthy.
--
-- Fix: add both columns to public.profiles. Nullable so existing rows are
-- unaffected. Onboarding and Edit Profile now write these on every save;
-- Edit Profile restores them on open. The Male / Moderately Active fallback
-- is kept only as a last resort for profiles that pre-date this migration.
-- =============================================================================

alter table public.profiles
    add column sex            text check (sex in ('male', 'female')),
    add column activity_level text check (activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active'));
