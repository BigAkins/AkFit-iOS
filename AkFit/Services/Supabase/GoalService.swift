import Foundation
import Supabase

/// Supabase writes for `public.goals`.
///
/// Thin seam between views and PostgREST so onboarding and edit flows no
/// longer embed `SupabaseClientProvider.shared.from("goals").…` chains with
/// duplicated payload structs.
///
/// **Authenticated path only.** Guest-mode writes are handled by
/// `GuestDataStore`; callers must branch on `authManager.isGuest` before
/// invoking these methods, matching the existing pattern.
///
/// Three distinct operations are preserved exactly as they existed inline:
///
/// 1. `insert` — onboarding first save. Writes `user_id`, `goal_type`,
///    `target_pace` (nullable for maintenance), and all four `daily_*`
///    targets. Postgres defaults fill in `id`, `created_at`, `updated_at`.
/// 2. `update` — EditGoalView. Full PATCH of goal type, pace, and all
///    recalculated targets, plus `updated_at`.
/// 3. `patchTargets` — EditProfileView. PATCH of the four `daily_*` targets
///    and `updated_at` only. `goal_type` and `target_pace` are intentionally
///    untouched because EditProfileView does not edit them — preserving the
///    previous behavior.
///
/// Each write filters by both `id` and `user_id` on update so RLS policies
/// and the app's scoping are redundantly enforced, matching the prior
/// belt-and-suspenders pattern.
enum GoalService {

    // MARK: - Insert (onboarding)

    /// Inserts a new goals row for `userId`. `target_pace` is `nil` for
    /// maintenance goals (preserves the existing OnboardingView semantics
    /// — edits via `GoalService.update` always write a non-nil pace).
    static func insert(
        userId: UUID,
        input: MacroCalculator.Input,
        out: MacroCalculator.Output
    ) async throws -> UserGoal {
        let row = GoalInsert(
            user_id:        userId,
            goal_type:      input.goalType.rawValue,
            target_pace:    input.goalType == .maintenance ? nil : input.pace.rawValue,
            daily_calories: out.calories,
            daily_protein:  out.proteinG,
            daily_carbs:    out.carbsG,
            daily_fat:      out.fatG
        )
        return try await SupabaseClientProvider.shared
            .from("goals")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Full update (EditGoalView)

    /// PATCHes `goal_type`, `target_pace`, all four `daily_*` targets, and
    /// `updated_at`. Matches the previous inline `GoalUpdate` in
    /// `EditGoalView` byte-for-byte (same non-optional `target_pace`).
    static func update(
        userId: UUID,
        goalId: UUID,
        input: MacroCalculator.Input,
        out: MacroCalculator.Output
    ) async throws -> UserGoal {
        let payload = GoalUpdate(
            goal_type:      input.goalType.rawValue,
            target_pace:    input.pace.rawValue,
            daily_calories: out.calories,
            daily_protein:  out.proteinG,
            daily_carbs:    out.carbsG,
            daily_fat:      out.fatG,
            updated_at:     Date()
        )
        return try await SupabaseClientProvider.shared
            .from("goals")
            .update(payload)
            .eq("id",      value: goalId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Targets-only patch (EditProfileView)

    /// PATCHes only the four `daily_*` macro targets and `updated_at`. Leaves
    /// `goal_type` and `target_pace` alone so recalculating macros from edited
    /// body stats doesn't accidentally overwrite goal choices the user made
    /// in `EditGoalView`.
    static func patchTargets(
        userId: UUID,
        goalId: UUID,
        out: MacroCalculator.Output
    ) async throws -> UserGoal {
        let payload = GoalTargetsPatch(
            daily_calories: out.calories,
            daily_protein:  out.proteinG,
            daily_carbs:    out.carbsG,
            daily_fat:      out.fatG,
            updated_at:     Date()
        )
        return try await SupabaseClientProvider.shared
            .from("goals")
            .update(payload)
            .eq("id",      value: goalId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Payloads

    /// Insert payload. No `id`, `created_at`, or `updated_at` — Postgres
    /// defaults fill those. `target_pace` is nullable to support maintenance
    /// goals.
    private struct GoalInsert: Encodable {
        let user_id:        UUID
        let goal_type:      String
        let target_pace:    String?
        let daily_calories: Int
        let daily_protein:  Int
        let daily_carbs:    Int
        let daily_fat:      Int
    }

    /// Full update payload. `target_pace` is non-optional here because
    /// EditGoalView always writes a pace (maintenance resets pace to
    /// `.moderate` in its `onChange` handler).
    private struct GoalUpdate: Encodable {
        let goal_type:      String
        let target_pace:    String
        let daily_calories: Int
        let daily_protein:  Int
        let daily_carbs:    Int
        let daily_fat:      Int
        let updated_at:     Date
    }

    /// Partial update payload — macros only.
    private struct GoalTargetsPatch: Encodable {
        let daily_calories: Int
        let daily_protein:  Int
        let daily_carbs:    Int
        let daily_fat:      Int
        let updated_at:     Date
    }
}
