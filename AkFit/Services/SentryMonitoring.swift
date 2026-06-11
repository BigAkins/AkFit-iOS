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
}
