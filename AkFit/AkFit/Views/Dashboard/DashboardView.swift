import SwiftUI

/// How the dashboard's macro cards present per-macro progress. Persisted via
/// `@AppStorage` on the dashboard so the user's choice survives relaunch.
///
/// - `remaining`: grams still left to hit the target (AkFit default).
/// - `consumed`: grams logged so far, alongside the target.
/// - `percent`: each macro's share of total consumed macro kcal — useful for
///   users tracking distribution rather than absolute amounts.
enum MacroDisplayMode: String, CaseIterable {
    case remaining
    case consumed
    case percent

    /// Short label rendered on the toggle pill — doubles as the user-visible
    /// mode name.
    var label: String {
        switch self {
        case .remaining: return "Remaining"
        case .consumed:  return "Consumed"
        case .percent:   return "Percent"
        }
    }

    /// Next mode in the cycle. Wraps from `.percent` back to `.remaining` so
    /// the toggle reads as a continuous loop instead of a dead-end.
    var next: MacroDisplayMode {
        switch self {
        case .remaining: return .consumed
        case .consumed:  return .percent
        case .percent:   return .remaining
        }
    }
}

/// Main dashboard — the first screen the user sees after onboarding.
///
/// **Data sources:**
/// - Targets come from `AuthManager.goal` (already in memory, no fetch).
/// - Consumed values are computed from logs for `selectedDate`.
/// - `FoodLogStore.refreshDay` is called via `.task(id: selectedDate)` so the
///   day's logs reload whenever the user navigates between days.
///
/// **Date navigation:** the navigation title and an in-content date row let
/// users step backwards through previously logged days. The system large
/// title and its native scroll-collapse / inline-blur behavior are preserved
/// — we just retitle it as the user navigates between days. Logging still
/// targets today regardless of `selectedDate` — past-day logging is a
/// separate feature.
///
/// **Swipe-to-delete:** Food log rows live as direct children of a `List` Section.
/// SwiftUI's `.swipeActions` requires List rows — a `ScrollView + VStack` structure
/// silently discards swipe actions. The outer `List` replaces the previous
/// `ScrollView + VStack` to make this work reliably.
///
/// **FAB action:** tapping the floating + button sets `AppRouter.selectedTab = .search`,
/// switching the user directly into the Search tab to start logging.
struct DashboardView: View {
    @Environment(AuthManager.self)     private var authManager
    @Environment(FoodLogStore.self)    private var logStore
    @Environment(WaterStore.self)      private var waterStore
    @Environment(DailyNoteStore.self)  private var noteStore
    @Environment(AppRouter.self)       private var router

    @State private var showDeleteError    = false
    @State private var showWaterAddError  = false
    @State private var showWaterUndoError = false
    @State private var isUndoingWater     = false
    @State private var showNoteEditor     = false
    /// Currently-displayed day. Normalised to start-of-day (device-local).
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var topBrandLogo = AkFitTopBrandLogoState()

    /// User-selected macro presentation mode. Persisted across launches via
    /// `@AppStorage` so the dashboard reopens in whatever mode the user last
    /// chose. Defaults to `.remaining` to preserve AkFit's current default.
    @AppStorage("dashboardMacroDisplayMode")
    private var macroDisplayMode: MacroDisplayMode = .remaining

    /// Logs that match `selectedDate`. When viewing today, mirrors
    /// `FoodLogStore.todayLogs` so Search-tab inserts surface immediately.
    /// For past days, reads the date-stamped `dayLogs` slot — and only when
    /// it actually matches `selectedDate`, to avoid showing stale data while
    /// a refresh is in flight.
    private var displayedLogs: [FoodLog] {
        if isViewingToday { return logStore.todayLogs }
        guard let date = logStore.dayLogsDate,
              Calendar.current.isDate(date, inSameDayAs: selectedDate) else {
            return []
        }
        return logStore.dayLogs
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// Total water (oz) for `selectedDate`. Mirrors the `displayedLogs`
    /// stale-guard pattern: only surface the loaded total when the store's
    /// `dayEntriesDate` actually matches the day being viewed, otherwise
    /// the user could see yesterday's total flash while a fetch is in flight.
    private var displayedWaterOz: Double {
        guard let date = waterStore.dayEntriesDate,
              Calendar.current.isDate(date, inSameDayAs: selectedDate) else {
            return 0
        }
        return waterStore.totalOz
    }

    /// True when the loaded water entries belong to `selectedDate` and at least
    /// one exists — i.e. there is something to undo. Same stale-guard pattern
    /// as `displayedWaterOz`: prevents the undo control from operating against
    /// a previous day's entries while a fetch is in flight.
    private var canUndoWater: Bool {
        guard let date = waterStore.dayEntriesDate,
              Calendar.current.isDate(date, inSameDayAs: selectedDate) else {
            return false
        }
        return !waterStore.dayEntries.isEmpty
    }

    /// Targets from the active goal + consumed totals from `displayedLogs`.
    /// Computed synchronously — no async work in the view.
    private var summary: DaySummary? {
        guard let goal = authManager.goal else { return nil }
        return DaySummary.from(goal: goal, logs: displayedLogs)
    }

    /// Meal slots that have at least one log entry on `selectedDate`, in canonical order.
    private var occupiedSlots: [MealSlot] {
        MealSlot.orderedCases.filter { slot in
            displayedLogs.contains { $0.mealSlot == slot }
        }
    }

    /// All log entries that belong to a given meal slot on `selectedDate`.
    private func logs(for slot: MealSlot) -> [FoodLog] {
        displayedLogs.filter { $0.mealSlot == slot }
    }

    /// Total calories logged in a given meal slot on `selectedDate`.
    private func slotCalories(_ slot: MealSlot) -> Int {
        logs(for: slot).reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                List {
                    if let summary {
                        // ── Summary cards ──────────────────────────────────────────
                        // listRowBackground(Color(UIColor.systemBackground)) makes the
                        // insetGrouped section container visually invisible — the cards
                        // draw their own gray surfaces on top.
                        Section {
                            // Date navigation — sits below the native large title so
                            // the iOS scroll-collapse / blur effect continues to drive
                            // the title area unchanged. The negative top inset is a
                            // small, contained pull-up into the system's implicit
                            // section-header gap above the first row; it does not
                            // affect the nav bar, the title's position, the collapse
                            // animation, or Dynamic Island safety.
                            dateNavigationRow
                                .listRowBackground(Color(UIColor.systemBackground))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: -16, leading: 4, bottom: 0, trailing: 4))

                            // Personalized time-of-day greeting. Disappears gracefully
                            // when no display name is set — falls back to generic salutation.
                            // Hidden on past days so the heading stays focused on the
                            // day's totals rather than a time-of-day salutation.
                            if isViewingToday {
                                Text(greetingText())
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .listRowBackground(Color(UIColor.systemBackground))
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
                            }

                            CalorieSummaryCard(summary: summary)
                                .listRowBackground(Color(UIColor.systemBackground))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))

                            MacroRow(
                                summary: summary,
                                mode: macroDisplayMode,
                                onCycleMode: {
                                    macroDisplayMode = macroDisplayMode.next
                                }
                            )
                            .listRowBackground(Color(UIColor.systemBackground))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))

                            // Lightweight water tracker — sits between macros and
                            // the food sections so calories/macros stay visually
                            // dominant but the daily total + quick-add stay one
                            // glance away. Past-day logging is supported because
                            // we hand `selectedDate` to `WaterStore.add`.
                            WaterCard(
                                totalOz: displayedWaterOz,
                                isViewingToday: isViewingToday,
                                canUndo: canUndoWater,
                                isUndoing: isUndoingWater,
                                onAdd: { amount in addWater(amountOz: amount) },
                                onUndo: { undoLastWater() }
                            )
                            .listRowBackground(Color(UIColor.systemBackground))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
                        }
                        .listSectionSeparator(.hidden)

                        // ── Food log ───────────────────────────────────────────────
                        // Loading and empty states show a single "Today's food" section.
                        // When entries exist they are grouped into per-meal sections
                        // (Breakfast → Lunch → Dinner → Snack) so the log is easy to
                        // scan at a glance. Each section clips to its own rounded card
                        // automatically via insetGrouped, and .swipeActions on direct
                        // List Section children works reliably.
                        if logStore.isRefreshing {
                            Section {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading…")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                                .listRowBackground(Color(UIColor.systemBackground))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                            } header: { foodLogHeader }
                            .listSectionSeparator(.hidden)
                        } else if logStore.refreshFailed {
                            Section {
                                foodLogErrorState
                                    .listRowBackground(Color(UIColor.systemBackground))
                                    .listRowSeparator(.hidden)
                            } header: { foodLogHeader }
                            .listSectionSeparator(.hidden)
                        } else if displayedLogs.isEmpty {
                            Section {
                                foodLogEmptyState
                                    .listRowBackground(Color(UIColor.systemBackground))
                                    .listRowSeparator(.hidden)
                            } header: { foodLogHeader }
                            .listSectionSeparator(.hidden)
                        } else {
                            ForEach(occupiedSlots, id: \.self) { slot in
                                Section {
                                    ForEach(logs(for: slot)) { log in
                                        FoodLogRow(log: log)
                                            // Swipe-to-delete is today-only.
                                            // Past days are read-only history in
                                            // this branch — surfacing a destructive
                                            // action there risks accidental historic
                                            // data loss. An empty content closure
                                            // means SwiftUI renders no swipe action
                                            // at all for those rows.
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                if isViewingToday {
                                                    Button(role: .destructive) {
                                                        Task {
                                                            do {
                                                                try await logStore.delete(logId: log.id)
                                                            } catch {
                                                                showDeleteError = true
                                                            }
                                                        }
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                            }
                                            .listRowBackground(Color(.systemGray6))
                                            .listRowInsets(EdgeInsets())
                                    }
                                } header: {
                                    mealSectionHeader(slot)
                                }
                                .listSectionSeparator(.hidden)
                            }
                        }

                        // ── Daily Note ─────────────────────────────────────────────
                        // One free-text note per calendar day. Tapping the row opens
                        // NoteEditorSheet. Empty placeholder prompts the user to add one.
                        // Past-day notes are out of scope for this branch — show the
                        // note section only while viewing today.
                        if isViewingToday {
                            Section {
                                Button {
                                    showNoteEditor = true
                                } label: {
                                    Group {
                                        if noteStore.todayContent.isEmpty {
                                            Text("Tap to add a note for today…")
                                                .foregroundStyle(.tertiary)
                                        } else {
                                            Text(noteStore.todayContent)
                                                .foregroundStyle(.primary)
                                                .lineLimit(4)
                                        }
                                    }
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color(.systemGray6))
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            } header: {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Today's Note")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .textCase(nil)
                                    Spacer()
                                    if !noteStore.todayContent.isEmpty {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                            .listSectionSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                // Tighten the insetGrouped style's default vertical gap between
                // sections. The native large-title behavior is untouched — this
                // only affects spacing between in-content sections.
                .listSectionSpacing(.compact)
                // Zero the system's automatic top breathing room for grouped
                // lists. Combined with the hidden nav bar below, this lets the
                // custom in-list title sit close to the safe-area top.
                .contentMargins(.top, 0, for: .scrollContent)
                // Remove the default grouped background so the screen stays white/dark
                // and the summary cards' own gray surfaces are the only decoration.
                .scrollContentBackground(.hidden)
                .background(Color(UIColor.systemBackground))
                // Keep the navigation title bound for accessibility / system
                // metadata even though the bar itself is hidden below.
                .navigationTitle(navigationTitleText)
                // Bottom inset keeps the last row visible above the tab bar + FAB.
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
                .akfitTracksTopBrandLogoScroll(topBrandLogo)
                .refreshable {
                    await refreshDayData()
                }
                // Reload whenever the user navigates to a different day. The
                // `.task(id:)` modifier cancels the previous fetch on change.
                .task(id: selectedDate) {
                    await refreshDayData()
                }
                .sheet(isPresented: $showNoteEditor) {
                    if let userId = authManager.currentUserId {
                        NoteEditorSheet(userId: userId)
                    }
                }
                .alert("Couldn't remove entry", isPresented: $showDeleteError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Please check your connection and try again.")
                }
                .alert("Couldn't add water", isPresented: $showWaterAddError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Please check your connection and try again.")
                }
                .alert("Couldn't undo water", isPresented: $showWaterUndoError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Please check your connection and try again.")
                }
            }

            // Floating add button — jumps directly to the Search tab. When
            // the user is viewing a past day, hand the date off via the
            // router so Search/FoodDetail can log into that day instead of
            // today. Today (default) keeps `pendingLogDate = nil`.
            Button {
                if isViewingToday {
                    router.clearPendingLogDate()
                } else {
                    router.pendingLogDate = selectedDate
                }
                router.selectedTab = .search
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .frame(width: 56, height: 56)
                    .background(Color.primary)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 16)
        }
        // Subtle AkFit brand mark in the otherwise-empty compact nav-bar zone
        // above the large "Today" title. Scroll state is shared with the List
        // tracker so behavior stays identical across screens.
        .akfitTopBrandLogo(topBrandLogo)
    }

    // MARK: - Greeting

    /// Returns a greeting string for the given date.
    ///
    /// Priority order:
    /// 1. **Birthday** — when today's month/day matches `profile.birthdate`, returns
    ///    "Happy birthday, [Name]" (or "Happy birthday!" if no name is set).
    /// 2. **Time-of-day** — morning / afternoon / evening, personalized with the
    ///    user's display name when available.
    ///
    /// The `date` parameter defaults to `Date()` but can be injected for testing
    /// or to drive the birthday check without touching live state.
    private func greetingText(at date: Date = Date()) -> String {
        let name = authManager.profile?.displayName?
            .trimmingCharacters(in: .whitespaces)

        // Birthday check — fires when the stored month/day matches today's.
        // Year is deliberately ignored so the greeting recurs every year.
        if let birthdate = authManager.profile?.birthdate,
           isBirthday(birthdate: birthdate, on: date) {
            guard let name, !name.isEmpty else { return "Happy birthday!" }
            return "Happy birthday, \(name)!"
        }

        let hour = Calendar.current.component(.hour, from: date)
        let salutation: String
        switch hour {
        case 5..<12:  salutation = "Good morning"
        case 12..<17: salutation = "Good afternoon"
        default:      salutation = "Good evening"
        }

        guard let name, !name.isEmpty else { return salutation }
        return "\(salutation), \(name)"
    }

    /// Returns `true` when the month and day encoded in `birthdate` ("YYYY-MM-DD")
    /// match the month and day of `date`. Year is intentionally ignored.
    private func isBirthday(birthdate: String, on date: Date) -> Bool {
        let parts = birthdate.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day   = Int(parts[2]) else { return false }
        let cal = Calendar.current
        return cal.component(.month, from: date) == month
            && cal.component(.day,   from: date) == day
    }

    // MARK: - Food log section headers

    /// Used only for loading and empty states where no meal grouping applies.
    /// Reads "Today's food" for the live day; falls back to a neutral "Food"
    /// label for past days so the heading stays accurate.
    private var foodLogHeader: some View {
        Text(isViewingToday ? "Today's food" : "Food")
            .font(.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.bottom, 4)
    }

    /// Per-meal section header showing the meal name and its calorie subtotal.
    private func mealSectionHeader(_ slot: MealSlot) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(slot.displayName)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(slotCalories(slot)) kcal")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: slotCalories(slot))
        }
        .textCase(nil)
        .padding(.bottom, 4)
    }

    // MARK: - Food log empty state

    private var foodLogEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.system(size: 28))
                .foregroundStyle(Color(.systemGray3))

            Text(isViewingToday ? "Nothing logged yet" : "Nothing logged this day")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            // Logging targets today only in this branch, so the "Tap +" hint
            // would mislead on past days where the FAB still logs to today.
            if isViewingToday {
                Text("Tap + to log your first meal")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Food log error state

    /// Shown when the day's log fetch fails so users understand nothing is
    /// wrong with their data — it's a connectivity issue, not an empty log.
    private var foodLogErrorState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 28))
                .foregroundStyle(Color(.systemGray3))

            Text(isViewingToday ? "Couldn't load today's log" : "Couldn't load this day")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Button("Try again") {
                Task { await refreshDayData() }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Date navigation

    /// Compact previous / day-label / next row shown below the native title.
    /// Future days are blocked; on past days a small "Today" shortcut appears.
    private var dateNavigationRow: some View {
        HStack(spacing: 8) {
            Button { stepDay(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.callout.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous day")

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Text(dateLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.opacity)
                    .animation(.snappy, value: selectedDate)
                if !isViewingToday {
                    Button("Today") { goToToday() }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Jump to today")
                }
            }

            Spacer(minLength: 0)

            Button { stepDay(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(isViewingToday ? Color(.systemGray3) : .primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isViewingToday)
            .accessibilityLabel("Next day")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    /// Human-readable label for `selectedDate`. Drives both the date row and
    /// the navigation title so the native large-title / inline-collapse text
    /// matches whatever day the user is viewing.
    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate)     { return "Today" }
        if cal.isDateInYesterday(selectedDate) { return "Yesterday" }
        return Self.dateLabelFormatter.string(from: selectedDate)
    }

    private static let dateLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return f
    }()

    private var navigationTitleText: String { dateLabel }

    /// Steps `selectedDate` by `offset` days, clamped to today.
    private func stepDay(by offset: Int) {
        let cal = Calendar.current
        guard let candidate = cal.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        let normalized = cal.startOfDay(for: candidate)
        let today      = cal.startOfDay(for: Date())
        guard normalized <= today else { return }
        selectedDate = normalized
    }

    private func goToToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Day refresh

    /// Loads the selected day's logs through `FoodLogStore` and water entries
    /// through `WaterStore`. Today also pulls the daily note since the note
    /// section only renders on today. Concurrent fetches keep navigation snappy.
    private func refreshDayData() async {
        guard let userId = authManager.currentUserId else { return }
        if isViewingToday {
            async let logs:  Void = logStore.refreshDay(userId: userId, date: selectedDate)
            async let note:  Void = noteStore.fetchToday(userId: userId)
            async let water: Void = waterStore.refreshDay(userId: userId, date: selectedDate)
            _ = await (logs, note, water)
        } else {
            async let logs:  Void = logStore.refreshDay(userId: userId, date: selectedDate)
            async let water: Void = waterStore.refreshDay(userId: userId, date: selectedDate)
            _ = await (logs, water)
        }
    }

    // MARK: - Water actions

    /// Logs a water intake event for `selectedDate`. The store handles the
    /// today-vs-backfill timestamp resolution via `LogDateContext`, so passing
    /// `selectedDate` is enough — no view-side calendar gymnastics. Failures
    /// surface a quiet alert instead of silently dropping the tap.
    private func addWater(amountOz: Double) {
        guard let userId = authManager.currentUserId else { return }
        Task {
            do {
                try await waterStore.add(
                    amountOz: amountOz,
                    for: userId,
                    date: selectedDate
                )
            } catch {
                showWaterAddError = true
            }
        }
    }

    /// Deletes the most recently-added water entry for `selectedDate`. Uses
    /// `createdAt`-max rather than the array's `loggedAt`-sorted tail so cross-
    /// session past-day backfills still target the entry the user just added
    /// (a backfill row's `loggedAt` is the past day at current time, which can
    /// land mid-sequence relative to entries logged on that day live). The
    /// store's `delete` updates `dayEntries` synchronously so `displayedWaterOz`
    /// reflects the change without a refresh round-trip.
    private func undoLastWater() {
        guard !isUndoingWater else { return }
        guard let date = waterStore.dayEntriesDate,
              Calendar.current.isDate(date, inSameDayAs: selectedDate) else {
            return
        }
        guard let entry = waterStore.dayEntries
                .max(by: { $0.createdAt < $1.createdAt }) else {
            return
        }
        isUndoingWater = true
        Task {
            defer { isUndoingWater = false }
            do {
                try await waterStore.delete(entryId: entry.id)
            } catch {
                showWaterUndoError = true
            }
        }
    }
}

// MARK: - Calorie summary card

private struct CalorieSummaryCard: View {
    let summary: DaySummary

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(summary.remainingCalories)")
                    .font(.system(size: 52, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: summary.remainingCalories)

                Text("kcal remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Consumed + goal context — surfaced so users can see
                // both "what's left" and "what I've already had" without math.
                HStack(spacing: 4) {
                    Text("\(summary.consumedCalories) consumed")
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(summary.targetCalories) goal")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }

            Spacer()

            ProgressRing(
                progress: summary.calorieProgress,
                color: .primary,
                size: 80,
                lineWidth: 7
            )
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Macro row

private struct MacroRow: View {
    let summary: DaySummary
    let mode: MacroDisplayMode
    let onCycleMode: () -> Void

    /// Macro calorie distribution as integer percents (protein/carbs/fat).
    /// Computed once for the row so each `MacroCard` doesn't need to know the
    /// other macros — single source of truth, no math duplication. Returns
    /// zeros when nothing has been logged so percent mode renders a clean
    /// "0%" state instead of dividing by zero.
    private var percents: (protein: Int, carbs: Int, fat: Int) {
        let pKcal = summary.consumedProteinG * 4
        let cKcal = summary.consumedCarbsG   * 4
        let fKcal = summary.consumedFatG     * 9
        let total = pKcal + cKcal + fKcal
        guard total > 0 else { return (0, 0, 0) }
        let p = Int(((Double(pKcal) / Double(total)) * 100).rounded())
        let roundedCarbs = Int(((Double(cKcal) / Double(total)) * 100).rounded())
        let c = min(roundedCarbs, 100 - p)
        let f = 100 - p - c
        return (p, c, f)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mode toggle. Right-aligned and capsule-styled so it reads as a
            // tappable affordance without competing with the macro cards
            // below. Shows the active mode's label alongside a cycle icon.
            HStack {
                Spacer()
                Button(action: onCycleMode) {
                    HStack(spacing: 4) {
                        Text(mode.label)
                            .font(.caption.weight(.medium))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Macro display: \(mode.label)")
                .accessibilityHint("Cycles between \(MacroDisplayMode.allCases.map(\.label).joined(separator: ", "))")
            }

            HStack(spacing: 12) {
                MacroCard(
                    name: "Protein",
                    consumed: summary.consumedProteinG,
                    target: summary.targetProteinG,
                    percent: percents.protein,
                    color: .red,
                    mode: mode
                )
                MacroCard(
                    name: "Carbs",
                    consumed: summary.consumedCarbsG,
                    target: summary.targetCarbsG,
                    percent: percents.carbs,
                    color: .orange,
                    mode: mode
                )
                MacroCard(
                    name: "Fat",
                    consumed: summary.consumedFatG,
                    target: summary.targetFatG,
                    percent: percents.fat,
                    color: .blue,
                    mode: mode
                )
            }
        }
    }
}

/// Macro card. Renders one macro's progress for the active `MacroDisplayMode`.
///
/// Uses `consumed` + `target` as the underlying source of truth, plus a
/// pre-computed `percent` (the parent `MacroRow` already needs all three to
/// derive distribution so it hands the result down rather than each card
/// redoing the math). Layout stays identical across modes — only the primary
/// value, secondary label, and bar fill semantics swap.
private struct MacroCard: View {
    let name: String
    let consumed: Int
    let target: Int
    /// This macro's share of total consumed macro kcal as an integer percent.
    /// Provided by the parent in all modes; only surfaces in percent mode.
    let percent: Int
    let color: Color
    let mode: MacroDisplayMode

    private var remaining: Int {
        max(0, target - consumed)
    }

    /// Bar fill fraction. In remaining/consumed modes it's "how close to
    /// target are we"; in percent mode it's the macro's calorie share so the
    /// three bars together visually express the distribution.
    private var progress: Double {
        switch mode {
        case .remaining, .consumed:
            guard target > 0 else { return 0 }
            return min(1.0, Double(consumed) / Double(target))
        case .percent:
            return min(1.0, Double(percent) / 100.0)
        }
    }

    /// Hides the colored fill entirely when there's nothing to draw — keeps
    /// the empty state visually flat instead of leaving a 0-width phantom strip.
    private var hasFill: Bool {
        switch mode {
        case .remaining, .consumed: return consumed > 0
        case .percent:              return percent > 0
        }
    }

    private var primaryText: String {
        switch mode {
        case .remaining: return "\(remaining)g"
        case .consumed:  return "\(consumed)g"
        case .percent:   return "\(percent)%"
        }
    }

    private var secondaryText: String {
        switch mode {
        case .remaining: return "of \(target)g"
        case .consumed:  return "/ \(target)g"
        case .percent:   return "of macros"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)

            Text(primaryText)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: primaryText)

            // Thin horizontal progress bar — fill represents per-mode progress.
            // Consistent with the macro bars in ProgressTabView.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(hasFill ? 1.0 : 0.0))
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 4)

            Text(secondaryText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Water card

/// Compact daily water-intake card showing the loaded day's total in US
/// fluid ounces plus three quick-add buttons (+8 / +12 / +16). Matches the
/// visual rhythm of `CalorieSummaryCard` / `MacroCard` (systemGray6 surface,
/// rounded 14pt corners) so it slots into the summary stack without breaking
/// the dashboard's existing look. Renders cleanly at 0 oz — no dramatic
/// empty-state imagery, matching the water v0 scope.
private struct WaterCard: View {
    let totalOz: Double
    let isViewingToday: Bool
    let canUndo: Bool
    let isUndoing: Bool
    let onAdd: (Double) -> Void
    let onUndo: () -> Void

    /// Whole-ounce readout. Quick-add increments are integers so the running
    /// total is too — rounding here protects against minor floating-point
    /// noise that the ml↔oz conversion can introduce.
    private var totalLabel: String {
        "\(Int(totalOz.rounded())) oz"
    }

    private var subtext: String {
        isViewingToday ? "logged today" : "logged this day"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Water")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    // Subtext + inline "Undo" affordance. The undo control
                    // lives here so the card's main shape (header + quick-add
                    // row) stays unchanged when there's nothing to undo — no
                    // ghost row, no shifting layout. Caption sizing keeps it
                    // visually low-priority next to the total readout.
                    HStack(spacing: 6) {
                        Text(subtext)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        if canUndo {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                            Button { onUndo() } label: {
                                Text("Undo")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(isUndoing)
                            .accessibilityLabel("Undo last water entry")
                        }
                    }
                }
                Spacer()
                Text(totalLabel)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: totalOz)
            }

            HStack(spacing: 8) {
                quickAddButton(amount: 8)
                quickAddButton(amount: 12)
                quickAddButton(amount: 16)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Pill-style quick-add button. Uses `systemGray5` so the control reads
    /// as a "raised" element on the `systemGray6` card surface in both light
    /// and dark mode (gray5 is slightly darker in light, slightly lighter in
    /// dark — visible contrast either way).
    private func quickAddButton(amount: Double) -> some View {
        Button { onAdd(amount) } label: {
            Text("+\(Int(amount))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(Int(amount)) ounces of water")
    }
}

// MARK: - Food log row

private struct FoodLogRow: View {
    let log: FoodLog

    /// Shared formatter — avoids allocation on every row render.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.foodName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(servingText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Compact P / C / F chips — consistent colour scheme across the app
                HStack(spacing: 8) {
                    macroChip("P", value: log.proteinG, color: .red)
                    macroChip("C", value: log.carbsG,   color: .orange)
                    macroChip("F", value: log.fatG,     color: .blue)
                }
                .font(.caption)
                .padding(.top, 1)
            }

            Spacer()

            // Calorie count + time — top-aligned with the food name.
            // The time helps users recall which meal each entry belongs to.
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(log.calories)")
                        .font(.body.weight(.bold))
                        .monospacedDigit()
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(Self.timeFormatter.string(from: log.loggedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private func macroChip(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text("\(Int(value.rounded()))g")
                .foregroundStyle(.secondary)
        }
    }

    private var servingText: String {
        let qty = log.quantity
        // When quantity is exactly 1, just show the serving label — "1 ×" adds nothing.
        if qty == 1.0 { return log.servingLabel }
        let qtyStr: String
        if qty == qty.rounded() {
            qtyStr = "\(Int(qty))"
        } else {
            var s = String(format: "%.2f", qty)
            while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
            qtyStr = s
        }
        return "\(qtyStr) × \(log.servingLabel)"
    }
}

// MARK: - Progress ring

/// Circular arc progress indicator. Track is a faint tint; progress arc grows clockwise.
/// Used at two sizes: 80pt (calorie card) and 36pt (macro cards).
private struct ProgressRing: View {
    let progress: Double  // 0.0 – 1.0
    let color: Color
    var size: CGFloat      = 80
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Note editor sheet

/// Full-screen-style sheet for editing today's free-text note.
///
/// Loads the current note content from `DailyNoteStore` on appear.
/// "Done" saves and dismisses. "Cancel" dismisses without saving.
/// The `DailyNoteStore` is read from the environment so the store stays
/// a single source of truth — no explicit passing required.
private struct NoteEditorSheet: View {
    let userId: UUID

    @Environment(DailyNoteStore.self) private var noteStore
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var isSaving = false
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($isEditorFocused)
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .navigationTitle("Today's Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Button("Done") {
                                save()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .disabled(isSaving)
                    }
                }
        }
        .onAppear {
            text = noteStore.todayContent
        }
        .task {
            // Delay focus until the sheet presentation animation completes,
            // otherwise the keyboard can collide with the transition.
            try? await Task.sleep(for: .milliseconds(400))
            isEditorFocused = true
        }
    }

    private func save() {
        guard !isSaving else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        Task {
            defer { isSaving = false }
            await noteStore.save(content: trimmed, userId: userId)
            dismiss()
        }
    }
}

// MARK: - Preview helpers

private extension DashboardView {
    /// Builds a preview `AuthManager` with a goal and optional profile fields.
    ///
    /// - Parameters:
    ///   - displayName: Name shown in the greeting. Pass `nil` to test the no-name path.
    ///   - birthdateIsToday: When `true`, generates a birthdate whose month/day matches
    ///     today so the birthday greeting fires in Canvas previews.
    static func previewAuth(
        displayName: String? = "Alex",
        birthdateIsToday: Bool = false
    ) -> AuthManager {
        let auth = AuthManager(previewMode: true)
        let cal   = Calendar.current
        let today = Date()
        let birthdateStr: String? = birthdateIsToday
            ? String(format: "1992-%02d-%02d",
                     cal.component(.month, from: today),
                     cal.component(.day,   from: today))
            : nil
        auth.markOnboarded(
            goal: UserGoal(
                id: UUID(), userId: UUID(),
                goalType: .fatLoss,
                targetWeight: nil, targetPace: .moderate,
                dailyCalories: 2100, dailyProtein: 165,
                dailyCarbs: 220, dailyFat: 65,
                createdAt: Date(), updatedAt: Date()
            ),
            profile: UserProfile(
                id: UUID(), displayName: displayName,
                heightCm: nil, weightKg: nil,
                birthdate: birthdateStr,
                createdAt: Date(), updatedAt: Date()
            )
        )
        return auth
    }

    /// Three realistic log entries spread across different times of day.
    /// Total: 522 kcal · P 76g · C 29g · F 10g consumed
    /// Remaining: 1578 kcal · P 89g · C 191g · F 55g
    static var previewLogs: [FoodLog] {
        let uid = UUID()
        let now = Date()
        return [
            FoodLog(
                id: UUID(), userId: uid,
                foodName: "Oats, rolled", servingLabel: "40g (½ cup)",
                quantity: 1.0,
                calories: 154, proteinG: 5.4, carbsG: 26.0, fatG: 2.8,
                mealSlot: .breakfast,
                loggedAt: now.addingTimeInterval(-5 * 3600),
                createdAt: now.addingTimeInterval(-5 * 3600)
            ),
            FoodLog(
                id: UUID(), userId: uid,
                foodName: "Chicken Breast, cooked", servingLabel: "100g",
                quantity: 1.5,
                calories: 248, proteinG: 46.5, carbsG: 0,   fatG: 5.4,
                mealSlot: .lunch,
                loggedAt: now.addingTimeInterval(-3 * 3600),
                createdAt: now.addingTimeInterval(-3 * 3600)
            ),
            FoodLog(
                id: UUID(), userId: uid,
                foodName: "Whey Protein", servingLabel: "1 scoop (30g)",
                quantity: 1.0,
                calories: 120, proteinG: 24.0, carbsG: 3.0, fatG: 1.5,
                mealSlot: .snack,
                loggedAt: now.addingTimeInterval(-1 * 3600),
                createdAt: now.addingTimeInterval(-1 * 3600)
            ),
        ]
    }
}

// MARK: - Preview

#Preview("Populated — with name") {
    DashboardView()
        .environment(DashboardView.previewAuth(displayName: "Alex"))
        .environment(FoodLogStore(previewLogs: DashboardView.previewLogs))
        .environment(WaterStore())
        .environment(DailyNoteStore())
        .environment(AppRouter())
}

#Preview("Empty state — no name") {
    DashboardView()
        .environment(DashboardView.previewAuth(displayName: nil))
        .environment(FoodLogStore())
        .environment(WaterStore())
        .environment(DailyNoteStore())
        .environment(AppRouter())
}

#Preview("Birthday") {
    DashboardView()
        .environment(DashboardView.previewAuth(displayName: "Alex", birthdateIsToday: true))
        .environment(FoodLogStore())
        .environment(WaterStore())
        .environment(DailyNoteStore())
        .environment(AppRouter())
}
