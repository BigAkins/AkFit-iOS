import Testing
@testable import AkFit

struct SentryMonitoringTests {

    @Test func redactedURLString_removesQueryFragmentAndCredentials() {
        let redacted = SentryMonitoring.redactedURLString(
            "https://user:pass@example.supabase.co/rest/v1/foods?search_text=token#access_token=secret"
        )

        #expect(redacted == "https://example.supabase.co/rest/v1/foods")
    }

    @Test func redactedURLString_leavesNonURLTextAlone() {
        #expect(SentryMonitoring.redactedURLString("search failed") == "search failed")
    }

    @Test func redactedURLString_removesCustomSchemeQueryAndFragment() {
        let redacted = SentryMonitoring.redactedURLString(
            "akfit://auth-callback?flow=password-recovery&state=abc#access_token=secret"
        )

        #expect(redacted == "akfit://auth-callback")
    }

    @Test func scrubTelemetryDictionary_redactsSensitiveValuesButKeepsUsefulContext() throws {
        let scrubbed = SentryMonitoring.scrubTelemetryDictionary([
            "url": "https://example.supabase.co/auth/v1/callback?code=secret#token",
            "authorization": "Bearer token",
            "status_code": 401,
            "nested": [
                "query": "user_id=123",
                "operation": "food_search",
            ],
        ])

        #expect(scrubbed["url"] as? String == "https://example.supabase.co/auth/v1/callback")
        #expect(scrubbed["authorization"] as? String == "[redacted]")
        #expect(scrubbed["status_code"] as? Int == 401)

        let nested = try #require(scrubbed["nested"] as? [String: Any])
        #expect(nested["query"] as? String == "[redacted]")
        #expect(nested["operation"] as? String == "food_search")
    }
}
