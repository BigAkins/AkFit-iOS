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
    /// Groups `logs` into the 7 most recent calendar days (today and the 6 preceding
    /// days) and returns one `DayProgress` per day, ordered oldest-to-newest.
    ///
    /// Days with no matching log entries are included with all-zero totals so the
    /// Progress chart always has a consistent 7-bar structure.
    ///
    /// **Timezone:** uses `calendar` (defaults to `Calendar.current`) for day
    /// boundaries, matching the device local time zone. `FoodLog.loggedAt` values
    /// are `Date` (UTC) and are correctly mapped to their local calendar day.
    static func buildWeek(
        from logs: [FoodLog],
        calendar: Calendar = .current
    ) -> [DayProgress] {
        let today = calendar.startOfDay(for: Date())

        // Build the 7 day anchors: [today-6, today-5, ..., today]
        let days: [Date] = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0 - 6, to: today)
        }

        // Group logs by their device-local midnight.
        // FoodLog.loggedAt is a `Date` (a point in time). startOfDay maps it
        // to the correct local calendar day regardless of the stored UTC value.
        var grouped: [Date: [FoodLog]] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.loggedAt)
            grouped[day, default: []].append(log)
        }

        return days.map { day in
            let dayLogs = grouped[day] ?? []
            return DayProgress(
                date:          day,
                totalCalories: dayLogs.reduce(0)   { $0 + $1.calories },
                totalProteinG: Int(dayLogs.reduce(0.0) { $0 + $1.proteinG }.rounded()),
                totalCarbsG:   Int(dayLogs.reduce(0.0) { $0 + $1.carbsG }.rounded()),
                totalFatG:     Int(dayLogs.reduce(0.0) { $0 + $1.fatG }.rounded())
            )
        }
    }
}
