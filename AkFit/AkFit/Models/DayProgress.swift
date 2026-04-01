import Foundation

/// Aggregated nutrition totals for a single calendar day.
///
/// Built by `buildWeek(from:)` which groups raw `FoodLog` entries by device-local
/// calendar day. Days with no logged entries are still included in the result —
/// `hasLogs` distinguishes them from days that genuinely have 0 calories.
struct DayProgress: Identifiable {
    /// Midnight at the start of the day, in device-local calendar time.
    let date: Date
    let totalCalories: Int
    let totalProteinG: Int
    let totalCarbsG:   Int
    let totalFatG:     Int

    var id: Date { date }

    /// `true` when at least one food log entry exists for this day.
    var hasLogs: Bool { totalCalories > 0 || totalProteinG > 0 || totalCarbsG > 0 || totalFatG > 0 }
}

// MARK: - Factory

extension DayProgress {
    /// Groups `logs` into the `days` most recent calendar days (today and the
    /// preceding `days - 1` days) and returns one `DayProgress` per day,
    /// ordered oldest-to-newest.
    ///
    /// Days with no matching log entries are included with all-zero totals so
    /// the Progress chart always has a consistent bar structure.
    ///
    /// **Timezone:** uses `calendar` (defaults to `Calendar.current`) for day
    /// boundaries, matching the device local time zone. `FoodLog.loggedAt`
    /// values are `Date` (UTC) and are correctly mapped to their local calendar
    /// day.
    static func build(
        days: Int,
        from logs: [FoodLog],
        calendar: Calendar = .current
    ) -> [DayProgress] {
        let today   = calendar.startOfDay(for: Date())
        let offset  = -(days - 1)

        // Build day anchors: [today-(days-1), ..., today]
        let anchors: [Date] = (0..<days).compactMap {
            calendar.date(byAdding: .day, value: offset + $0, to: today)
        }

        // Group logs by their device-local midnight.
        var grouped: [Date: [FoodLog]] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.loggedAt)
            grouped[day, default: []].append(log)
        }

        return anchors.map { day in
            let dayLogs = grouped[day] ?? []
            return DayProgress(
                date:          day,
                totalCalories: dayLogs.reduce(0)       { $0 + $1.calories },
                totalProteinG: Int(dayLogs.reduce(0.0) { $0 + $1.proteinG }.rounded()),
                totalCarbsG:   Int(dayLogs.reduce(0.0) { $0 + $1.carbsG  }.rounded()),
                totalFatG:     Int(dayLogs.reduce(0.0) { $0 + $1.fatG    }.rounded())
            )
        }
    }

    /// Convenience wrapper — builds the standard 7-day window.
    static func buildWeek(
        from logs: [FoodLog],
        calendar: Calendar = .current
    ) -> [DayProgress] {
        build(days: 7, from: logs, calendar: calendar)
    }
}
