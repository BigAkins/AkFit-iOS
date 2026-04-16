-- =============================================================================
-- Migration: 20260416000000_goals_profiles_update_with_check
-- Purpose:   Close the cross-user write hole on the active UPDATE policies for
--            public.goals and public.profiles by adding a WITH CHECK clause.
--
-- ── Root cause ───────────────────────────────────────────────────────────────
-- The existing UPDATE policies, defined in:
--   20260329000000_initial_schema.sql   ("profiles: update own")
--   20260401000014_reconcile_schema.sql ("goals: update own")
-- only enforce USING, which evaluates the PRE-update row. Without WITH CHECK,
-- the POST-update row is never validated, so an authenticated user can submit
-- an update that rewrites the row's ownership column:
--
--   UPDATE public.goals
--      SET user_id    = '<victim-uuid>',
--          created_at = now()
--    WHERE id = '<attacker-owned-goal-id>';
--
-- USING passes because the attacker still owns the row at evaluation time.
-- The write succeeds and the row is now owned by the victim. Because
-- AuthManager.fetchActiveGoal selects `order by created_at desc limit 1`,
-- the injected row becomes the victim's active goal on their next fetch —
-- silently replacing their calorie/macro targets.
--
-- The same pattern applies to public.profiles via `id`. Primary-key and
-- foreign-key constraints make that path narrower but non-zero.
--
-- ── Fix ──────────────────────────────────────────────────────────────────────
-- ALTER POLICY on each policy adds the WITH CHECK expression without dropping
-- or recreating the policy, so there is no brief window in which the policy
-- is absent and no impact on any unrelated RLS or schema state. The existing
-- USING expressions are re-stated verbatim for clarity — ALTER POLICY requires
-- that any specified clause be provided in full.
-- =============================================================================

alter policy "goals: update own" on public.goals
    using      (auth.uid() = user_id)
    with check (auth.uid() = user_id);

alter policy "profiles: update own" on public.profiles
    using      (auth.uid() = id)
    with check (auth.uid() = id);
