import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        if
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: raw),
            let host = url.host, !host.isEmpty
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

    // Set by the xctest runner when the app is launched as a test host. Never
    // set in production builds, App Store builds, or regular debug runs — so
    // the placeholders below can only be reached during unit-test execution.
    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
