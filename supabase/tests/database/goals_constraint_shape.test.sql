begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(5);

-- =============================================================================
-- goals_goal_type_check shape
--
-- Regression guard for the 2026-06 incident: the live constraint allowed
-- 'muscle_gain' while the app sends 'lean_bulk', so every Lean Bulk
-- onboarding save failed with SQLSTATE 23514. Fixed by
-- 20260611054748_fix_goals_goal_type_check.sql.
--
-- The app-side mirror of this contract is
-- AkFitTests/SaveErrorClassificationTests.swift
-- (GoalTypeDatabaseContractTests).
-- =============================================================================

select ok(
    exists (
        select 1
        from pg_constraint
        where conrelid = 'public.goals'::regclass
          and conname  = 'goals_goal_type_check'
          and contype  = 'c'
    ),
    'goals_goal_type_check exists on public.goals'
);

select matches(
    (select pg_get_constraintdef(oid)
       from pg_constraint
      where conrelid = 'public.goals'::regclass
        and conname  = 'goals_goal_type_check'),
    'fat_loss',
    'goal_type check accepts fat_loss'
);

select matches(
    (select pg_get_constraintdef(oid)
       from pg_constraint
      where conrelid = 'public.goals'::regclass
        and conname  = 'goals_goal_type_check'),
    'maintenance',
    'goal_type check accepts maintenance'
);

select matches(
    (select pg_get_constraintdef(oid)
       from pg_constraint
      where conrelid = 'public.goals'::regclass
        and conname  = 'goals_goal_type_check'),
    'lean_bulk',
    'goal_type check accepts lean_bulk (the 2026-06 incident fix)'
);

select doesnt_match(
    (select pg_get_constraintdef(oid)
       from pg_constraint
      where conrelid = 'public.goals'::regclass
        and conname  = 'goals_goal_type_check'),
    'muscle_gain',
    'goal_type check no longer references the legacy muscle_gain value'
);

select * from finish();

rollback;
