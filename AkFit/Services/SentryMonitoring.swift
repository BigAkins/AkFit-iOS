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
}
