import Foundation
import UserNotifications

/// Manages daily food-logging reminder notifications.
///
/// ## Scheduling strategy
///
/// Rather than a single repeating trigger (which can't be cancelled for a
/// single day), this service schedules **individual non-repeating notifications
/// for the next 7 calendar days**, each with a unique identifier based on its
/// calendar date: `"akfit.reminder.YYYY-MM-DD"`.
///
/// This lets one specific day's notification be cancelled independently.
/// After the user logs their first food, `cancelTodayReminder()` removes that
/// day's alert from both the pending queue and Notification Center — they won't
/// see a reminder for food they've already logged.
///
/// `scheduleReminder()` fills in any missing days in the 7-day window and is
/// called on: initial enable, settings change, and every app foreground (via
/// `scenePhase` in `AkFitApp`). This maintains a rolling schedule without any
/// background processing.
///
/// ## Foreground presentation
/// `NotificationService` is the `UNUserNotificationCenter` delegate. Without a
/// delegate, iOS silently suppresses local notifications when the app is in the
/// foreground. The `willPresent` delegate method opts in to banner + sound so
/// reminders are always visible regardless of app state.
///
/// ## Permission
/// Authorization is requested only when the user first enables reminders —
/// never on cold launch. Denied state surfaces a link to iPhone Settings.
///
/// ## Storage
/// `isEnabled` and `reminderTime` are persisted in `UserDefaults` so settings
/// survive app restarts without a network round-trip.
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    // MARK: - Persisted state

    /// Whether daily reminders are currently enabled. Persisted in UserDefaults.
    private(set) var isEnabled: Bool

    /// The time of day for the reminder. Only hour and minute components are used.
    /// Stored as `TimeInterval` (seconds since reference date) in UserDefaults.
    private(set) var reminderTime: Date

    // MARK: - Authorization state

    enum AuthStatus {
        case notDetermined
        case authorized
        case denied
    }

    private(set) var authStatus: AuthStatus = .notDetermined

    // MARK: - Private

    private let center = UNUserNotificationCenter.current()

    private enum Keys {
        static let enabled      = "akfit.notifications.enabled"
        static let reminderTime = "akfit.notifications.reminderTime"
    }

    /// Prefix shared by all AkFit reminder identifiers.
    private let idPrefix = "akfit.reminder."

    // MARK: - Reminder messages
    //
    // Rotated by day-of-year so each day gets a different message without any
    // stored state. Food and weight logging prompts alternate to cover both
    // core product loops.

    private static let reminderMessages: [(title: String, body: String)] = [
        ("Don't forget to log your food",
         "Tap to track what you've eaten today."),
        ("Don't forget to log your weight",
         "Jump on the scale and log it in AkFit."),
        ("Time to log your meals",
         "Stay on top of your calories and macros."),
        ("Log your food today",
         "A quick log keeps your goals on track."),
        ("Have you logged today?",
         "Open AkFit to track your food for the day."),
        ("Log your weight today",
         "Track your progress — weigh in and record it."),
        ("Stay on track today",
         "Don't forget to log your food."),
    ]

    // MARK: - Init

    override init() {
        let defaults = UserDefaults.standard
        isEnabled    = defaults.bool(forKey: Keys.enabled)

        if let stored = defaults.object(forKey: Keys.reminderTime) as? TimeInterval {
            reminderTime = Date(timeIntervalSinceReferenceDate: stored)
        } else {
            // Default: 8:00 PM — after dinner, a natural point to reflect on the day.
            var comps    = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour   = 20
            comps.minute = 0
            comps.second = 0
            reminderTime = Calendar.current.date(from: comps) ?? Date()
        }
        super.init()
        // Register as delegate so foreground notifications are presented.
        // Must come after super.init() — self is not fully formed before that.
        center.delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification fires while the app is in the foreground.
    ///
    /// Without this method iOS swallows local notifications silently when the
    /// app is active. Opting in to `.banner` and `.sound` makes reminders
    /// visible in all app states — active, background, and terminated.
    ///
    /// Only AkFit reminder identifiers are opted in; any other notification
    /// (e.g. from a framework) is passed through with empty options.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.identifier.hasPrefix(idPrefix) else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound])
    }

    // MARK: - Authorization

    /// Reads the current notification authorization status from the system and
    /// updates `authStatus`. Call on SettingsView appear and on app foreground.
    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authStatus = .authorized
        case .denied:
            authStatus = .denied
        default:
            authStatus = .notDetermined
        }
    }

    /// Presents the system notification permission prompt.
    ///
    /// iOS shows this dialog only once. On subsequent calls the system responds
    /// immediately (no prompt) and `authStatus` is updated from the stored choice.
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authStatus  = granted ? .authorized : .denied
        } catch {
            authStatus  = .denied
        }
    }

    // MARK: - Enable / disable

    /// Called when the user toggles reminders on or off in Settings.
    ///
    /// Enabling: checks / requests authorization, then schedules the 7-day window.
    /// Disabling: cancels all pending AkFit notifications immediately.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.enabled)
        Task {
            if enabled {
                await checkAuthorization()
                if authStatus == .notDetermined {
                    await requestAuthorization()
                }
                if authStatus == .authorized {
                    await scheduleReminder()
                }
            } else {
                cancelAll()
            }
        }
    }

    // MARK: - Scheduling

    /// Called when the user changes the reminder time in Settings.
    /// Cancels the current schedule and rebuilds it at the new time.
    func updateReminderTime(_ time: Date) {
        reminderTime = time
        UserDefaults.standard.set(time.timeIntervalSinceReferenceDate, forKey: Keys.reminderTime)
        guard isEnabled, authStatus == .authorized else { return }
        // Cancel synchronously then reschedule — cancellation completes before
        // the Task starts, so scheduleReminder sees a clean pending list.
        cancelAll()
        Task { await scheduleReminder() }
    }

    /// Schedules individual notifications for the next 7 calendar days.
    ///
    /// Skips days that already have a pending notification and days whose
    /// reminder time has already passed (can't schedule in the past).
    ///
    /// Each day receives a message chosen by day-of-year modulo the message
    /// count, so the rotation varies across the week without stored state.
    ///
    /// Safe to call repeatedly — existing pending notifications are untouched.
    func scheduleReminder() async {
        guard isEnabled, authStatus == .authorized else { return }

        let calendar = Calendar.current
        let now      = Date()
        let hour     = calendar.component(.hour,   from: reminderTime)
        let minute   = calendar.component(.minute, from: reminderTime)

        // Fetch existing pending IDs to avoid double-scheduling.
        let pending    = await center.pendingNotificationRequests()
        let pendingIds = Set(pending.map(\.identifier))

        for dayOffset in 0..<7 {
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let id = notificationId(for: targetDay)
            guard !pendingIds.contains(id) else { continue }

            var comps    = calendar.dateComponents([.year, .month, .day], from: targetDay)
            comps.hour   = hour
            comps.minute = minute
            comps.second = 0

            guard let fireDate = calendar.date(from: comps), fireDate > now else { continue }

            // Pick a message by day-of-year so the rotation is stable per date
            // but varies across days without any additional stored state.
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: targetDay) ?? dayOffset
            let msg       = Self.reminderMessages[dayOfYear % Self.reminderMessages.count]

            let content      = UNMutableNotificationContent()
            content.title    = msg.title
            content.body     = msg.body
            content.sound    = .default

            let triggerComps = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                                       from: fireDate)
            let trigger      = UNCalendarNotificationTrigger(dateMatching: triggerComps,
                                                             repeats: false)
            let request      = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    // MARK: - Cancellation

    /// Suppresses today's reminder. Call after the user logs their first food of
    /// the day so they don't receive an unnecessary alert.
    ///
    /// Removes from the pending queue (if not yet delivered) **and** from
    /// Notification Center (if already delivered and sitting in the drawer).
    func cancelTodayReminder() {
        let id = notificationId(for: Date())
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// Cancels all pending AkFit reminder notifications.
    ///
    /// Uses computed identifiers for a ±30-day window so no async fetch is
    /// needed — `removePendingNotificationRequests` is a synchronous no-op for
    /// identifiers that don't exist.
    func cancelAll() {
        let cal = Calendar.current
        let now = Date()
        let ids = (-1..<30).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: now).map { notificationId(for: $0) }
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Private helpers

    private func notificationId(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "\(idPrefix)%04d-%02d-%02d",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
