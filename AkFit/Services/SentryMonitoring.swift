import Foundation
import Sentry

enum SentryMonitoring {
    /// Configures Sentry before any other app code runs. Must stay on the main thread.
    static func configure() {
        guard !AppConfig.sentryDSN.isEmpty else { return }

        SentrySDK.start { options in
            options.dsn = AppConfig.sentryDSN
            #if DEBUG
            options.debug = true
            options.sessionReplay.sessionSampleRate = 1.0
            #else
            options.debug = false
            options.sessionReplay.sessionSampleRate = 0.1
            #endif

            options.sessionReplay.onErrorSampleRate = 1.0
            options.sessionReplay.maskAllText = true
            options.sessionReplay.maskAllImages = true
            options.enableNetworkBreadcrumbs = false
            options.enableNetworkTracking = false
            options.enableCaptureFailedRequests = false
            options.beforeSend = { event in
                scrub(event)
                return event
            }
            options.beforeBreadcrumb = { breadcrumb in
                scrub(breadcrumb)
                return breadcrumb
            }
        }

        #if DEBUG
        if ProcessInfo.processInfo.environment["SENTRY_VERIFY"] == "1" {
            SentrySDK.capture(message: "Sentry Cocoa SDK test")
        }
        #endif
    }

    /// Captures a handled (non-fatal) error with non-PII context tags.
    ///
    /// Added after the 2026-06 onboarding incident: the lean_bulk check
    /// violation failed onboarding saves for ~19% of signups for two months
    /// with zero Sentry events, because every catch path logged to os.log
    /// only. Critical catch sites now report here so production failures are
    /// visible with release attribution.
    ///
    /// **Privacy rule:** tag values must be enum raw values, error codes, or
    /// fixed strings — never user IDs, emails, tokens, or free-form user data.
    static func captureNonFatal(
        _ error: Error,
        operation: String,
        tags: [String: String] = [:]
    ) {
        guard !AppConfig.sentryDSN.isEmpty else { return }
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: operation, key: "akfit.operation")
            for (key, value) in tags {
                scope.setTag(value: value, key: "akfit.\(key)")
            }
        }
    }

    nonisolated static func scrub(_ event: Event) {
        if let request = event.request {
            scrub(request)
        }
        if let breadcrumbs = event.breadcrumbs {
            breadcrumbs.forEach(scrub)
        }
    }

    nonisolated static func scrub(_ breadcrumb: Breadcrumb) {
        breadcrumb.message = breadcrumb.message.map(scrubURLsInText)
        guard let data = breadcrumb.data else { return }
        breadcrumb.data = scrubTelemetryDictionary(data)
    }

    nonisolated static func scrub(_ request: SentryRequest) {
        request.url = request.url.map(redactedURLString)
        request.queryString = nil
        request.fragment = nil
        request.cookies = nil
        request.headers = request.headers.map(sanitizedHeaders)
    }

    nonisolated static func redactedURLString(_ value: String) -> String {
        guard var components = URLComponents(string: value),
              let scheme = components.scheme,
              !scheme.isEmpty,
              components.host != nil
        else {
            return value
        }

        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.string ?? value
    }

    nonisolated static func scrubTelemetryDictionary(_ dictionary: [String: Any]) -> [String: Any] {
        dictionary.reduce(into: [:]) { result, element in
            result[element.key] = scrubTelemetryValue(element.value, key: element.key)
        }
    }

    nonisolated private static func scrubTelemetryValue(_ value: Any, key: String) -> Any {
        let normalizedKey = key.lowercased()
        if isSensitiveTelemetryKey(normalizedKey) {
            return "[redacted]"
        }

        if let string = value as? String {
            if normalizedKey.contains("url") {
                return redactedURLString(string)
            }
            return scrubURLsInText(string)
        }

        if let nested = value as? [String: Any] {
            return scrubTelemetryDictionary(nested)
        }

        if let array = value as? [Any] {
            return array.map { scrubTelemetryValue($0, key: key) }
        }

        return value
    }

    nonisolated private static func sanitizedHeaders(_ headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { result, element in
            if isSensitiveTelemetryKey(element.key.lowercased()) {
                result[element.key] = "[redacted]"
            } else {
                result[element.key] = element.value
            }
        }
    }

    nonisolated private static func isSensitiveTelemetryKey(_ key: String) -> Bool {
        key.contains("authorization") ||
        key == "apikey" ||
        key.contains("cookie") ||
        key.contains("token") ||
        key.contains("secret") ||
        key.contains("password") ||
        key.contains("query") ||
        key.contains("fragment")
    }

    nonisolated private static func scrubURLsInText(_ text: String) -> String {
        let pieces = text.split(separator: " ", omittingEmptySubsequences: false)
        return pieces
            .map { piece in
                let string = String(piece)
                return string.contains("://")
                    ? redactedURLString(string)
                    : string
            }
            .joined(separator: " ")
    }
}
