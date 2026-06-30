import Foundation
import Testing
@testable import AkFit

struct AppConfigTests {

    @Test func validatedSupabaseURL_acceptsHTTPSProjectURL() throws {
        let url = try #require(AppConfig.validatedSupabaseURL("https://example.supabase.co"))

        #expect(url.absoluteString == "https://example.supabase.co")
    }

    @Test func validatedSupabaseURL_rejectsHTTPURL() {
        #expect(AppConfig.validatedSupabaseURL("http://example.supabase.co") == nil)
    }

    @Test func validatedSupabaseURL_rejectsMissingHost() {
        #expect(AppConfig.validatedSupabaseURL("https:///auth/v1") == nil)
    }

    @Test func validatedSupabaseURL_rejectsBuildSettingPlaceholder() {
        #expect(AppConfig.validatedSupabaseURL("$(SUPABASE_URL)") == nil)
    }

    @Test func validatedSupabaseURL_rejectsEmbeddedCredentials() {
        #expect(AppConfig.validatedSupabaseURL("https://user:pass@example.supabase.co") == nil)
    }
}
