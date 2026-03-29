import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: raw),
            let host = url.host, !host.isEmpty
        else {
            fatalError(
                "SUPABASE_URL is missing or malformed in Info.plist / xcconfig. " +
                "Expected a full HTTPS URL, e.g. https:/$()/your-project.supabase.co — " +
                "note: use $()/ to escape // in xcconfig files."
            )
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        else {
            fatalError("Missing SUPABASE_ANON_KEY in Info.plist / xcconfig")
        }
        return key
    }()
}

