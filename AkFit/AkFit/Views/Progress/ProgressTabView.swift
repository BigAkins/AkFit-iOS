import SwiftUI
import Charts

/// 7-day calorie and macro progress screen.
///
/// Named `ProgressTabView` (not `ProgressView`) to avoid shadowing SwiftUI's
/// built-in `ProgressView`.
///
/// **Data flow:** `FoodLogStore.weekLogs` is fetched via `.task` on first appear
/// and kept current by `FoodLogStore.insert`/`delete` after each mutation.
/// `DayProgress.buildWeek` groups those raw logs into 7 daily totals in memory —
/// no Supabase aggregation needed.
///
/// **Interaction:** tapping a bar in the calorie chart selects that day. The
/// day-detail section below the chart shows calorie and macro cards for the
/// selected day, defaulting to today on first appear.
struct ProgressTabView: View {
    @Environment(FoodLogStore.self)     private var logStore
    @Environment(BodyweightStore.self)  private var weightStore
    @Environment(AuthManager.self)      private var authManager

    @State private var selectedDate  = Calendar.current.startOfDay(for: Date())
    @State private var showWeightLog = false

    // MARK: - Derived state

    private var weekProgress: [DayProgress] {
        DayProgress.buildWeek(from: logStore.weekLogs)
    }

    private var selectedDay: DayProgress? {
        weekProgress.first { $0.date == selectedDate }
    }

    /// Upper bound for the chart Y-axis. Always tall enough to show the target
    /// line even if all bars are 0 (e.g. on first load or a fresh account).
    private var yMax: Double {
        let targetCal  = Double(authManager.goal?.targetCalories ?? 2000)
        let maxLogged  = weekProgress.map { Double($0.totalCalories) }.max() ?? 0
        return max(targetCal, maxLogged) * 1.25
    }

    // MARK: - Weight derived state

    /// One entry per day that has at least one bodyweight log, using the latest
    /// `logged_at` for that calendar day. Ordered oldest → newest.
    private var weightEntries: [WeightEntry] {
        let cal = Calendar.current
        return weekProgress.compactMap { day in
            let latest = weightStore.weekLogs
                .filter { cal.isDate($0.loggedAt, inSameDayAs: day.date) }
                .sorted { $0.loggedAt > $1.loggedAt }
                .first
            guard let log = latest else { return nil }
            return WeightEntry(date: day.date, lbs: log.weightLbs)
        }
    }

    /// Today's weight in pounds, or `nil` if not yet logged today.
    private var todayWeightLbs: Double? {
        let today = Calendar.current.startOfDay(for: Date())
        return weightEntries.first {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }?.lbs
    }

    /// Y-axis domain for the weight chart. Auto-scales to data ±5 lbs padding.
    private var weightYDomain: ClosedRange<Double> {
        guard !weightEntries.isEmpty else { return 140...180 }
        let values  = weightEntries.map(\.lbs)
        let padding = max(5.0, (values.max()! - values.min()!) * 0.3)
        return (values.min()! - padding)...(values.max()! + padding)
    }

    /// Seed value for the weight log sheet: today's entry → last entry → goal weight → 150.
    private var logSheetInitialLbs: Int {
        if let lbs = todayWeightLbs       { return Int(lbs.rounded()) }
        if let last = weightEntries.last  { return Int(last.lbs.rounded()) }
        if let kg   = authManager.goal?.weightKg { return OnboardingData.kgToLbs(kg) }
        return 150
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    calorieChartCard
                    if let day = selectedDay {
                        dayDetailSection(day)
                    }
                    weightCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Progress")
            .sheet(isPresented: $showWeightLog) {
                WeightLogSheet(initialLbs: logSheetInitialLbs)
                    .presentationDetents([.medium])
            }
        }
        .task {
            if let userId = authManager.currentUserId {
                // Fetch calorie logs and weight logs concurrently.
                async let calories: Void = logStore.refreshWeek(userId: userId)
                async let weights:  Void = weightStore.refreshWeek(userId: userId)
                _ = await (calories, weights)
            }
        }
    }

    // MARK: - Calorie chart card

    private var calorieChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calories · 7 days")
                .font(.headline)

            Chart {
                ForEach(weekProgress) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Calories", day.totalCalories)
                    )
                    .foregroundStyle(barColor(for: day))
                    .cornerRadius(4)
                }

                if let target = authManager.goal?.targetCalories {
                    RuleMark(y: .value("Target", target))
                        .foregroundStyle(Color.red.opacity(0.40))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .trailing, spacing: 4) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(Color.red.opacity(0.55))
                                .padding(.trailing, 4)
                        }
                }
            }
            .frame(height: 160)
            .chartYScale(domain: 0...yMax)
            .animation(.easeOut(duration: 0.45), value: weekProgress.map(\.totalCalories))
            .animation(.easeInOut(duration: 0.2), value: selectedDate)
            .chartXAxis {
                AxisMarks(values: weekProgress.map(\.date)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(
                            Calendar.current.isDateInToday(date)
                                ? "Today"
                                : date.formatted(.dateTime.weekday(.abbreviated))
                        )
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in
                            selectDay(at: location, proxy: proxy, geo: geo)
                        }
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func barColor(for day: DayProgress) -> Color {
        if day.date == selectedDate                      { return .primary }
        if Calendar.current.isDateInToday(day.date)     { return Color(.systemGray2) }
        return Color(.systemGray4)
    }

    /// Maps a tap location in the chart overlay to the nearest week day.
    private func selectDay(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotOrigin = geo[proxy.plotAreaFrame].origin
        let plotX = location.x - plotOrigin.x
        guard plotX >= 0, let tappedDate: Date = proxy.value(atX: plotX) else { return }
        let tappedDay = Calendar.current.startOfDay(for: tappedDate)
        // Snap to the nearest actual day in our window (handles taps between bars).
        if let nearest = weekProgress.min(by: {
            abs($0.date.timeIntervalSince(tappedDay)) < abs($1.date.timeIntervalSince(tappedDay))
        }) {
            selectedDate = nearest.date
        }
    }

    // MARK: - Day detail

    private func dayDetailSection(_ day: DayProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dayLabel(for: day.date))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            calorieDetailCard(for: day)

            HStack(spacing: 10) {
                macroCard("Protein", consumed: day.totalProteinG,
                          target: authManager.goal?.targetProteinG, color: .red)
                macroCard("Carbs",   consumed: day.totalCarbsG,
                          target: authManager.goal?.targetCarbsG,   color: .orange)
                macroCard("Fat",     consumed: day.totalFatG,
                          target: authManager.goal?.targetFatG,     color: .blue)
            }
        }
    }

    // MARK: - Calorie detail card

    private func calorieDetailCard(for day: DayProgress) -> some View {
        let target   = authManager.goal?.targetCalories ?? 0
        let consumed = day.totalCalories
        let progress = target > 0 ? min(1.0, Double(consumed) / Double(target)) : 0.0

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(day.hasLogs ? "\(consumed)" : "—")
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: consumed)
                    if day.hasLogs {
                        Text("kcal")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                if target > 0 {
                    Text("of \(target) target")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if day.hasLogs && target > 0 {
                    adherenceLabel(consumed: consumed, target: target)
                        .padding(.top, 2)
                } else if !day.hasLogs {
                    Text("Nothing logged")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.10), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.primary,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)
            }
            .frame(width: 64, height: 64)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func adherenceLabel(consumed: Int, target: Int) -> some View {
        let delta = consumed - target
        let label: String
        let color: Color
        if delta > 150 {
            label = "+\(delta) over target"
            color = .orange
        } else if delta < -150 {
            label = "\(abs(delta)) under target"
            color = .secondary
        } else {
            label = "On target"
            color = .green
        }
        return Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
    }

    // MARK: - Macro cards

    private func macroCard(_ name: String, consumed: Int, target: Int?, color: Color) -> some View {
        let targetVal = target ?? 0
        let progress  = targetVal > 0 ? min(1.0, Double(consumed) / Double(targetVal)) : 0.0

        return VStack(alignment: .leading, spacing: 6) {
            Text(consumed > 0 ? "\(consumed)g" : "—")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: consumed)

            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            // Thin horizontal progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(consumed > 0 ? 1.0 : 0.0))
                        .frame(width: geo.size.width * progress, height: 5)
                        .animation(.easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 5)

            if let target, target > 0 {
                Text("of \(target)g")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Weight card

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row — today's weight shown inline when available.
            HStack(alignment: .firstTextBaseline) {
                Text("Weight · 7 days")
                    .font(.headline)
                Spacer()
                if let lbs = todayWeightLbs {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", lbs))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: lbs)
                        Text("lbs today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if weightEntries.isEmpty {
                // Empty state — no data yet this week.
                VStack(spacing: 6) {
                    Text("No weight logged this week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Log daily to see your trend.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Line chart — connects only days with recorded entries.
                Chart {
                    ForEach(weightEntries) { entry in
                        LineMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("lbs", entry.lbs)
                        )
                        .foregroundStyle(Color.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("lbs", entry.lbs)
                        )
                        .foregroundStyle(Color.primary)
                        .symbolSize(40)
                    }
                }
                .frame(height: 120)
                .chartYScale(domain: weightYDomain)
                .animation(.easeOut(duration: 0.45), value: weightEntries.map(\.lbs))
                .chartXAxis {
                    AxisMarks(values: weekProgress.map(\.date)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel(
                                Calendar.current.isDateInToday(date)
                                    ? "Today"
                                    : date.formatted(.dateTime.weekday(.abbreviated))
                            )
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                        AxisValueLabel()
                        AxisGridLine()
                    }
                }
            }

            // Log button — label reflects whether today already has an entry.
            Button {
                showWeightLog = true
            } label: {
                Text(todayWeightLbs == nil ? "Log today's weight" : "Update today's weight")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: date)
    }
}

// MARK: - Weight log sheet

/// Modal sheet for recording today's bodyweight.
///
/// Displayed at `.medium` detent from `ProgressTabView`. Pre-seeded with
/// the user's most recent weight so every new entry only requires a small
/// adjustment — not retyping from scratch.
///
/// **Units:** display and input are in pounds; the store converts to kg
/// before persisting (`lbs / 2.20462`), matching the existing metric-internal
/// pattern used throughout the app.
private struct WeightLogSheet: View {
    @Environment(BodyweightStore.self) private var weightStore
    @Environment(AuthManager.self)     private var authManager
    @Environment(\.dismiss)            private var dismiss

    let initialLbs: Int

    @State private var weightLbs: Int
    @State private var isSaving  = false
    @State private var saveError: String? = nil

    private let minLbs = 66
    private let maxLbs = 440

    init(initialLbs: Int) {
        self.initialLbs = initialLbs
        _weightLbs      = State(initialValue: initialLbs)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Large lbs display
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(weightLbs)")
                        .font(.system(size: 72, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: weightLbs)
                    Text("lbs")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                // kg equivalent — informational, stays small
                Text(String(format: "%.1f kg", Double(weightLbs) / 2.20462))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)

                Spacer()

                // ± stepper
                HStack(spacing: 0) {
                    stepButton(systemImage: "minus") {
                        weightLbs = max(minLbs, weightLbs - 1)
                    }
                    .disabled(weightLbs <= minLbs)

                    Text("\(weightLbs)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .frame(minWidth: 72)
                        .multilineTextAlignment(.center)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: weightLbs)

                    stepButton(systemImage: "plus") {
                        weightLbs = min(maxLbs, weightLbs + 1)
                    }
                    .disabled(weightLbs >= maxLbs)
                }
                .foregroundStyle(.primary)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .sensoryFeedback(.impact(weight: .light), trigger: weightLbs)

                Spacer()

                if let error = saveError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 32)
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 56, height: 48)
        }
    }

    private func save() {
        guard let userId = authManager.currentUserId else { return }
        let kg = Double(weightLbs) / 2.20462
        isSaving  = true
        saveError = nil
        Task {
            defer { isSaving = false }
            do {
                try await weightStore.log(weightKg: kg, for: userId)
                dismiss()
            } catch {
                saveError = "Couldn't save weight. Please try again."
            }
        }
    }
}

// MARK: - Weight entry

/// Pairs a calendar date with its recorded bodyweight in pounds.
/// Used as the data source for the 7-day weight chart.
private struct WeightEntry: Identifiable {
    var id: Date { date }
    let date: Date
    let lbs:  Double
}

// MARK: - Preview helpers

private extension ProgressTabView {
    static func previewAuth() -> AuthManager {
        let auth = AuthManager(previewMode: true)
        auth.markOnboarded(
            goal: UserGoal(
                id: UUID(), userId: UUID(),
                goalType: .fatLoss,
                targetCalories: 2100, targetProteinG: 165,
                targetCarbsG: 220,   targetFatG: 65,
                heightCm: 178, weightKg: 75, age: 30, sex: .male,
                activityLevel: .moderate, pace: .moderate,
                isActive: true, createdAt: Date(), updatedAt: Date()
            ),
            profile: UserProfile(id: UUID(), displayName: nil, createdAt: Date())
        )
        return auth
    }

    /// Six bodyweight entries across the 7-day window (one day skipped),
    /// showing a gentle downward trend — 75.8 kg → 74.6 kg.
    static var previewWeightLogs: [BodyweightLog] {
        let uid = UUID()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // (offset from today, weight_kg)
        let days: [(Int, Double)] = [
            (-6, 75.8),
            (-5, 75.5),
            (-4, 75.2),
            // -3 skipped — simulates a missed day
            (-2, 75.0),
            (-1, 74.8),
            ( 0, 74.6),   // today
        ]
        return days.compactMap { offset, kg in
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let loggedAt = day.addingTimeInterval(3600 * 8)  // 8 am
            return BodyweightLog(
                id: UUID(), userId: uid,
                weightKg: kg,
                loggedAt: loggedAt, createdAt: loggedAt
            )
        }
    }

    /// Six of the past seven days logged (day −3 skipped) with varied calories.
    static var previewWeekLogs: [FoodLog] {
        let uid = UUID()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // (offset from today, total kcal, protein g, carbs g, fat g)
        let days: [(Int, Int, Double, Double, Double)] = [
            (-6, 1890, 142, 200, 52),
            (-5, 2050, 158, 215, 58),
            (-4, 1760, 130, 185, 48),
            // -3 skipped — simulates a missed day
            (-2, 2320, 170, 240, 68),
            (-1, 1940, 150, 205, 54),
            ( 0,  890,  68,  92, 24),   // today, partial
        ]
        return days.compactMap { offset, kcal, p, c, f in
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let loggedAt = day.addingTimeInterval(3600 * 12) // noon
            return FoodLog(
                id: UUID(), userId: uid,
                foodName: "Sample", servingLabel: "1 serving", quantity: 1.0,
                calories: kcal, proteinG: p, carbsG: c, fatG: f,
                mealSlot: .snack,
                loggedAt: loggedAt, createdAt: loggedAt
            )
        }
    }
}

// MARK: - Preview

#Preview("Populated") {
    ProgressTabView()
        .environment(FoodLogStore(previewWeekLogs: ProgressTabView.previewWeekLogs))
        .environment(BodyweightStore(previewLogs: ProgressTabView.previewWeightLogs))
        .environment(ProgressTabView.previewAuth())
}

#Preview("Empty") {
    ProgressTabView()
        .environment(FoodLogStore())
        .environment(BodyweightStore())
        .environment(ProgressTabView.previewAuth())
}
