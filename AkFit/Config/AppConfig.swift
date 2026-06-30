import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        if
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = validatedSupabaseURL(raw)
        {
            return url
        }
        if isRunningUnderXCTest {
            return URL(string: "https://test-placeholder.invalid")!
        }
        fatalError(
            "SUPABASE_URL is missing or malformed in Info.plist / xcconfig. " +
            "Expected a full HTTPS URL, e.g. https:/$()/your-project.supabase.co — " +
            "note: use $()/ to escape // in xcconfig files."
        )
    }()

    static func validatedSupabaseURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        guard let components = URLComponents(string: trimmed) else { return nil }
        guard components.scheme?.lowercased() == "https" else { return nil }
        guard let host = components.host, !host.isEmpty else { return nil }
        guard components.user == nil, components.password == nil else { return nil }
        return components.url
    }

    static let supabaseAnonKey: String = {
        if
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        {
            return key
        }
        if isRunningUnderXCTest {
            return "test-placeholder-anon-key"
        }
        fatalError("Missing SUPABASE_ANON_KEY in Info.plist / xcconfig")
    }()

    static let sentryDSN: String = {
        if
            let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
            !dsn.isEmpty,
            !dsn.contains("$(")
        {
            return dsn
        }
        if isRunningUnderXCTest {
            return ""
        }
        return ""
    }()

    // Set by the xctest runner when the app is launched as a test host. Never
    // set in production builds, App Store builds, or regular debug runs — so
    // the placeholders below can only be reached during unit-test execution.
    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
