import Foundation
import Supabase

/// Supabase writes for `public.profiles`.
///
/// Thin seam between views and PostgREST so onboarding and edit flows no
/// longer embed `SupabaseClientProvider.shared.from("profiles").…` chains
/// with duplicated payload structs.
///
/// **Authenticated path only.** Guest-mode writes are handled by
/// `GuestDataStore`; callers must branch on `authManager.isGuest` before
/// invoking these methods, matching the existing pattern.
///
/// Payload shapes mirror the previous inline structs verbatim — same columns,
/// same defaults — so this is a pure move with no schema or wire-format
/// changes.
enum ProfileService {

    // MARK: - Upsert full profile row

    /// Upserts the profile row for `userId`. Used by `OnboardingView` on first
    /// save and by `EditProfileView` on edits. `display_name` is nullable; all
    /// other fields are always written.
    ///
    /// Returns the server-confirmed row so callers can push it into
    /// `AuthManager` without a follow-up fetch.
    static func upsert(
        userId: UUID,
        input: MacroCalculator.Input,
        displayName: String?,
        birthdate: String
    ) async throws -> UserProfile {
        let row = ProfileUpsert(
            id:             userId,
            display_name:   displayName,
            height_cm:      Int(input.heightCm.rounded()),
            weight_kg:      Int(input.weightKg.rounded()),
            birthdate:      birthdate,
            sex:            input.sex.rawValue,
            activity_level: input.activityLevel.rawValue,
            updated_at:     Date()
        )
        return try await SupabaseClientProvider.shared
            .from("profiles")
            .upsert(row, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Patch activity level only

    /// PATCHes `profiles.activity_level` and `updated_at` only. Called by
    /// `EditGoalView` after the user changes activity level so body-stat
    /// columns are left untouched — body stats are owned by `EditProfileView`.
    static func patchActivityLevel(
        userId: UUID,
        activityLevel: UserGoal.ActivityLevel
    ) async throws -> UserProfile {
        let payload = ActivityPatch(
            activity_level: activityLevel.rawValue,
            updated_at:     Date()
        )
        return try await SupabaseClientProvider.shared
            .from("profiles")
            .update(payload)
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Payloads

    /// Encodable shape of a full profile upsert — column names match the DB
    /// directly to avoid `CodingKeys` boilerplate, matching the existing
    /// repo style for profile/goal insert structs.
    private struct ProfileUpsert: Encodable {
        let id:             UUID
        let display_name:   String?
        let height_cm:      Int
        let weight_kg:      Int
        let birthdate:      String
        let sex:             String
        let activity_level: String
        let updated_at:     Date
    }

    /// Encodable shape of an activity-level-only patch.
    private struct ActivityPatch: Encodable {
        let activity_level: String
        let updated_at:     Date
    }
}
