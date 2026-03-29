import Foundation

enum AppConfig {
    static let supabaseURL: URL = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: raw)
        else {
            fatalError("Missing or invalid SUPABASE_URL in Info.plist / xcconfig")
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

