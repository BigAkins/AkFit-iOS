import Foundation
import Supabase

/// Shared classification of Supabase save errors for user-facing messaging
/// and structured logging.
///
/// Extracted from `OnboardingView` so the onboarding results step,
/// `EditGoalView`, and `EditProfileView` agree on one rule set — and so the
/// classification is unit-testable.
///
/// ## Why "non-retryable" matters
/// The 2026-06 onboarding incident (live `goals_goal_type_check` rejecting
/// `lean_bulk`, SQLSTATE 23514) showed users a "Please try again." message for
/// an error that could never succeed on retry. Check violations, RLS denials,
/// and not-null/foreign-key violations are deterministic server-side rejects:
/// the user needs an app update or support, not a retry.
nonisolated enum SaveErrorClassification {

    // MARK: - Outcome buckets

    nonisolated enum Kind {
        /// The session is missing/expired/invalid — re-authentication fixes it.
        /// (supabase-swift auto-signs-out on fatal refresh failures, so the
        /// user normally lands on the sign-in screen moments later.)
        case sessionExpired
        /// Deterministic server-side reject (check violation, RLS denial,
        /// not-null/FK violation, unknown column). Retrying cannot succeed.
        case nonRetryable
        /// Anything else — network blips, timeouts, transient 5xx. Retry is
        /// the right advice.
        case retryable
    }

    /// PostgREST error codes that can never succeed on retry with the same
    /// payload. See docs/debugging-supabase-errors.md for the full map.
    private static let nonRetryablePostgrestCodes: Set<String> = [
        "23502",    // not_null_violation
        "23503",    // foreign_key_violation
        "23514",    // check_violation (the 2026-06 lean_bulk incident)
        "42501",    // insufficient_privilege (RLS denial)
        "PGRST204", // column not found in schema cache
    ]

    static func kind(of error: Error) -> Kind {
        if let authError = error as? AuthError {
            switch authError {
            case .sessionMissing, .jwtVerificationFailed:
                return .sessionExpired
            case let .api(_, errorCode, _, _):
                // Invalid/expired JWT api errors are session problems; other
                // GoTrue api errors (5xx, rate limits) are transient.
                return (errorCode == .invalidJWT || errorCode == .badJWT)
                    ? .sessionExpired
                    : .retryable
            default:
                return .retryable
            }
        }

        if let postgrestError = error as? PostgrestError {
            if postgrestError.code == "PGRST301" { return .sessionExpired }
            if let code = postgrestError.code,
               nonRetryablePostgrestCodes.contains(code) {
                return .nonRetryable
            }
            let message = postgrestError.message.lowercased()
            if message.contains("jwt") { return .sessionExpired }
            return .retryable
        }

        return .retryable
    }

    // MARK: - User-facing copy

    /// One consistent message per outcome bucket.
    ///
    /// - Parameter action: what failed, in sentence-fragment form —
    ///   e.g. `"save your targets"` (onboarding) or `"save changes"` (edits).
    static func userMessage(for error: Error, action: String) -> String {
        switch kind(of: error) {
        case .sessionExpired:
            return "Session expired. Please sign out and sign back in."
        case .nonRetryable:
            return "Couldn't \(action) due to a server problem. Please update to the latest version of AkFit, or contact support if this continues."
        case .retryable:
            return "Couldn't \(action). Please check your connection and try again."
        }
    }

    // MARK: - Structured-log fields

    /// Stable classification string for os.log / Sentry tags.
    static func classification(of error: Error) -> String {
        if let authError = error as? AuthError {
            switch authError {
            case .sessionMissing:        return "auth_session_missing"
            case .jwtVerificationFailed: return "auth_jwt_verification_failed"
            case .api:                   return "auth_api_error"
            default:                     return "auth_error"
            }
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501":    return "postgrest_permission_denied"
            case "23502":    return "postgrest_not_null_violation"
            case "23503":    return "postgrest_foreign_key_violation"
            case "23505":    return "postgrest_unique_violation"
            case "23514":    return "postgrest_check_violation"
            case "PGRST116": return "postgrest_no_rows_returned"
            case "PGRST204": return "postgrest_unknown_column"
            case "PGRST301": return "postgrest_jwt_invalid"
            default:         return "postgrest_error"
            }
        }

        return "unexpected_error"
    }

    /// PostgREST error code for logs, `"none"` when not a PostgrestError.
    static func postgrestCode(of error: Error) -> String {
        (error as? PostgrestError)?.code ?? "none"
    }

    /// Auth error code (status:code) for logs, `"none"` when not an AuthError.
    static func authCode(of error: Error) -> String {
        guard let authError = error as? AuthError else { return "none" }
        switch authError {
        case let .api(_, errorCode, _, underlyingResponse):
            return "\(underlyingResponse.statusCode):\(errorCode.rawValue)"
        case .sessionMissing:
            return "session_missing"
        case .jwtVerificationFailed:
            return "jwt_verification_failed"
        default:
            return "auth_error"
        }
    }
}
