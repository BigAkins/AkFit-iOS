import Testing
import Foundation
import Supabase
@testable import AkFit

// MARK: - SaveErrorClassification tests

/// Covers the shared save-error classification used by the onboarding results
/// step, EditGoalView, and EditProfileView.
///
/// Regression context: the 2026-06 incident where the live `goals` table
/// rejected `lean_bulk` (SQLSTATE 23514) surfaced as "Please try again." —
/// a retry that could never succeed. Non-retryable server rejects must now
/// produce the "server problem / update the app" message.
struct SaveErrorClassificationTests {

    // MARK: - Non-retryable PostgREST codes

    @Test(arguments: ["23502", "23503", "23514", "42501", "PGRST204"])
    func nonRetryableCodes_classifyAsNonRetryable(code: String) {
        let error = PostgrestError(code: code, message: "rejected")
        #expect(SaveErrorClassification.kind(of: error) == .nonRetryable)
    }

    @Test func checkViolation_messageDoesNotSayTryAgain() {
        let error = PostgrestError(code: "23514", message: "check constraint violated")
        let message = SaveErrorClassification.userMessage(for: error, action: "save your targets")
        #expect(!message.lowercased().contains("try again"))
        #expect(message.contains("server problem"))
    }

    // MARK: - Session-expired classification

    @Test func sessionMissing_classifiesAsSessionExpired() {
        let error = AuthError.sessionMissing
        #expect(SaveErrorClassification.kind(of: error) == .sessionExpired)
        #expect(
            SaveErrorClassification.userMessage(for: error, action: "save changes")
                == "Session expired. Please sign out and sign back in."
        )
    }

    @Test func postgrestJWTInvalid_classifiesAsSessionExpired() {
        let error = PostgrestError(code: "PGRST301", message: "JWT expired")
        #expect(SaveErrorClassification.kind(of: error) == .sessionExpired)
    }

    @Test func postgrestJWTMessage_withoutCode_classifiesAsSessionExpired() {
        let error = PostgrestError(code: nil, message: "invalid JWT signature")
        #expect(SaveErrorClassification.kind(of: error) == .sessionExpired)
    }

    // MARK: - Retryable defaults

    @Test func plainNetworkError_classifiesAsRetryable() {
        let error = URLError(.notConnectedToInternet)
        #expect(SaveErrorClassification.kind(of: error) == .retryable)
        let message = SaveErrorClassification.userMessage(for: error, action: "save your targets")
        #expect(message.contains("try again"))
    }

    @Test func uniqueViolation_staysRetryable() {
        // 23505 is intentionally NOT in the non-retryable set: a unique
        // violation usually means the row already exists, and a retry path
        // that re-reads state can succeed.
        let error = PostgrestError(code: "23505", message: "duplicate key")
        #expect(SaveErrorClassification.kind(of: error) == .retryable)
    }

    // MARK: - Structured log fields

    @Test func classification_mapsKnownPostgrestCodes() {
        #expect(
            SaveErrorClassification.classification(
                of: PostgrestError(code: "23514", message: "x")
            ) == "postgrest_check_violation"
        )
        #expect(
            SaveErrorClassification.classification(
                of: PostgrestError(code: "42501", message: "x")
            ) == "postgrest_permission_denied"
        )
        #expect(
            SaveErrorClassification.classification(of: URLError(.timedOut))
                == "unexpected_error"
        )
    }

    @Test func codeAccessors_defaultToNone() {
        let urlError = URLError(.timedOut)
        #expect(SaveErrorClassification.postgrestCode(of: urlError) == "none")
        #expect(SaveErrorClassification.authCode(of: urlError) == "none")
        #expect(SaveErrorClassification.authCode(of: AuthError.sessionMissing) == "session_missing")
    }
}

// MARK: - GoalType ↔ database contract

/// Tripwire for the exact bug class behind the 2026-06 onboarding incident:
/// the app's `GoalType` raw values MUST match the `goals_goal_type_check`
/// constraint in the live database.
///
/// The allowed set lives in:
///   supabase/migrations/20260611054748_fix_goals_goal_type_check.sql
///   (verification: docs/debugging-supabase-errors.md → drift check)
///
/// If this test fails, you renamed or added a `GoalType` case — ship the
/// matching constraint migration FIRST, then update this list.
struct GoalTypeDatabaseContractTests {

    private static let databaseAllowedGoalTypes: Set<String> = [
        "fat_loss", "maintenance", "lean_bulk",
    ]

    @Test func goalTypeRawValues_matchDatabaseCheckConstraint() {
        let appValues = Set(UserGoal.GoalType.allCases.map(\.rawValue))
        #expect(appValues == Self.databaseAllowedGoalTypes)
    }

    @Test func paceRawValues_matchDatabaseCheckConstraint() {
        // goals.target_pace check: ('slow','moderate','fast') — see
        // 20260401000014_reconcile_schema.sql. Pace is not CaseIterable, so
        // enumerate explicitly.
        let appValues: Set<String> = [
            UserGoal.Pace.slow.rawValue,
            UserGoal.Pace.moderate.rawValue,
            UserGoal.Pace.fast.rawValue,
        ]
        #expect(appValues == ["slow", "moderate", "fast"])
    }
}
