import Foundation

enum LogDateContext {
    static func isToday(
        _ logDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let logDate else { return true }
        return calendar.isDate(logDate, inSameDayAs: now)
    }

    static func isBackfill(
        _ logDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        !isToday(logDate, now: now, calendar: calendar)
    }

    static func displayLabel(
        for logDate: Date?,
        locale: Locale = .current
    ) -> String {
        guard let logDate else { return "" }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter.string(from: logDate)
    }

    static func loggingText(
        for logDate: Date?,
        locale: Locale = .current
    ) -> String {
        let label = displayLabel(for: logDate, locale: locale)
        return label.isEmpty ? "" : "Logging for \(label)"
    }

    static func resolvedLoggedAt(
        for logDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        guard let logDate, !isToday(logDate, now: now, calendar: calendar) else {
            return now
        }

        let day = calendar.startOfDay(for: logDate)
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        let resolved = calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: day
        ) ?? day

        return resolved > now ? now : resolved
    }
}
