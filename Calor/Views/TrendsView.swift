//
//  TrendsView.swift
//  Calor
//

import SwiftUI
import SwiftData
import Charts

/// History and analytics for the last 7 or 30 days. Everything is calculated
/// on the phone, so it's free and works offline.
struct TrendsView: View {
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @Query private var entries: [FoodEntry]
    /// Switches to the Today tab when the Calor logo is tapped.
    let goHome: () -> Void

    @State private var range = TrendRange.week
    @State private var selectedDate: Date?

    private let calendar = Calendar.current

    enum TrendRange: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30

        var id: Int { rawValue }
        var title: String { "\(rawValue) days" }
    }

    init(goHome: @escaping () -> Void = {}) {
        self.goHome = goHome
        let today = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.date(byAdding: .day, value: -29, to: today) ?? today
        _entries = Query(
            filter: #Predicate<FoodEntry> { $0.timestamp >= start },
            sort: \FoodEntry.timestamp
        )
    }

    var body: some View {
        let stats = TrendStats(
            entries: entries,
            days: range.rawValue,
            goal: dailyGoal,
            maintenance: Profile(data: profileData)?.maintenanceCalories,
            proteinTarget: proteinTarget,
            calendar: calendar
        )

        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $range) {
                        ForEach(TrendRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    calorieChart(stats.days)
                } header: {
                    Text("Daily calories")
                } footer: {
                    Text("Dashed line is your daily goal. Tap a bar to see that day.")
                }

                Section("Summary") {
                    summaryGrid(stats)
                }

                if stats.loggedDays.isEmpty {
                    Section {
                        Text("Log a few meals to see your analytics here.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    weightSection(stats)
                    mealSection(stats)
                    macroSection(stats)
                    weekdaySection(stats)
                    topFoodsSection(stats)

                    Section("Insights") {
                        ForEach(stats.insights, id: \.self) { insight in
                            Label {
                                Text(insight)
                            } icon: {
                                Image(systemName: "sparkle")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trends")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CalorLogoButton(action: goHome)
                }
            }
            .onChange(of: range) {
                selectedDate = nil
            }
        }
    }

    // MARK: - Chart

    private func calorieChart(_ days: [TrendStats.DayTotal]) -> some View {
        let labelFormat: Date.FormatStyle = range == .week
            ? .dateTime.weekday(.narrow)
            : .dateTime.day().month(.abbreviated)

        return Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Calories", day.calories),
                    width: .ratio(0.6)
                )
                .foregroundStyle(Color.accentColor)
                .cornerRadius(range == .week ? 4 : 2)
                .opacity(isHighlighted(day) ? 1 : 0.35)
            }

            RuleMark(y: .value("Goal", dailyGoal))
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text("Goal \(dailyGoal.formatted())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

            if let selected = selectedDay(in: days) {
                RuleMark(x: .value("Selected", selected.date, unit: .day))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 2) {
                            Text(selected.date, format: .dateTime.weekday(.abbreviated).day().month())
                                .foregroundStyle(.secondary)
                            Text("\(selected.calories.formatted()) kcal")
                                .bold()
                            Text("\(selected.entryCount) \(selected.entryCount == 1 ? "item" : "items")")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .padding(6)
                        .background(.regularMaterial, in: .rect(cornerRadius: 6))
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                AxisValueLabel(format: labelFormat)
            }
        }
        .chartXSelection(value: $selectedDate)
        .frame(height: 200)
        .padding(.vertical, 8)
    }

    private func selectedDay(in days: [TrendStats.DayTotal]) -> TrendStats.DayTotal? {
        guard let selectedDate else { return nil }
        return days.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private func isHighlighted(_ day: TrendStats.DayTotal) -> Bool {
        guard let selectedDate else { return true }
        return calendar.isDate(day.date, inSameDayAs: selectedDate)
    }

    // MARK: - Sections

    private func summaryGrid(_ stats: TrendStats) -> some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 16) {
            GridRow {
                tile(stats.averageCalories.map { $0.formatted() } ?? "–", unit: "kcal", label: "Daily average")
                tile("\(stats.daysWithinGoal)/\(stats.loggedDays.count)", unit: "days", label: "Within goal")
                tile("\(stats.streak)", unit: stats.streak == 1 ? "day" : "days", label: "Logging streak")
            }
            GridRow {
                tile(stats.highestDay.map { $0.calories.formatted() } ?? "–", unit: "kcal", label: "Highest day")
                tile(stats.lowestDay.map { $0.calories.formatted() } ?? "–", unit: "kcal", label: "Lowest day")
                tile("\(stats.rangeEntries.count)", unit: "items", label: "Logged")
            }
        }
        .padding(.vertical, 4)
    }

    private func tile(_ value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func weightSection(_ stats: TrendStats) -> some View {
        if let balance = stats.averageDailyBalance, let maintenance = stats.maintenance {
            Section {
                LabeledContent("Average vs. what you burn",
                               value: "\(balance > 0 ? "+" : "−")\(abs(balance).formatted()) kcal/day")
                LabeledContent("Change over logged days", value: kg(stats.estimatedKgChange ?? 0))
                LabeledContent("At this pace, per week", value: kg(Double(balance) * 7 / 7700))
                LabeledContent("At this pace, per month", value: kg(Double(balance) * 30 / 7700))
            } header: {
                Text("Estimated weight change")
            } footer: {
                Text("Compared with the \(maintenance.formatted()) kcal you burn a day (from your profile), at about 7,700 kcal per kg. Only days with meals logged are counted.")
            }
            .monospacedDigit()
        }
    }

    private func mealSection(_ stats: TrendStats) -> some View {
        Section {
            ForEach(stats.mealBreakdown, id: \.meal) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.meal.title)
                        Spacer()
                        Text("\(row.averageCalories.formatted()) kcal")
                            .monospacedDigit()
                        Text(row.share, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    .font(.subheadline)
                    ProgressView(value: row.share)
                }
            }
        } header: {
            Text("By meal, daily average")
        }
    }

    private func macroSection(_ stats: TrendStats) -> some View {
        Section {
            if let macros = stats.averageMacros {
                MacroProgressView(proteinG: macros.protein, carbsG: macros.carbs, fatG: macros.fat,
                                  targets: MacroTargets(calorieGoal: dailyGoal, proteinTargetG: proteinTarget))
                LabeledContent("Share of calories") {
                    Text(macros.shareSummary)
                        .monospacedDigit()
                }
                .font(.subheadline)
            } else {
                Text("No macros logged yet. Photo entries include them automatically.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Macros, daily average")
        }
    }

    @ViewBuilder
    private func weekdaySection(_ stats: TrendStats) -> some View {
        if stats.weekdayAverage != nil || stats.weekendAverage != nil {
            Section("Weekdays vs. weekends") {
                LabeledContent("Mon–Fri average", value: stats.weekdayAverage.map { "\($0.formatted()) kcal" } ?? "No data")
                LabeledContent("Sat–Sun average", value: stats.weekendAverage.map { "\($0.formatted()) kcal" } ?? "No data")
            }
            .monospacedDigit()
        }
    }

    private func topFoodsSection(_ stats: TrendStats) -> some View {
        Section {
            ForEach(stats.topFoods, id: \.name) { food in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name)
                            .lineLimit(1)
                        Text("\(food.count)× · about \(food.averageCalories.formatted()) kcal each")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(food.totalCalories.formatted()) kcal")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Top foods by calories")
        }
    }

    private func kg(_ value: Double) -> String {
        "\(value > 0 ? "+" : "−")\(abs(value).formatted(.number.precision(.fractionLength(1)))) kg"
    }
}

// MARK: - Calculations

/// All the numbers on the Trends screen, worked out from the entries in range.
private struct TrendStats {
    struct DayTotal: Identifiable {
        let date: Date
        let calories: Int
        let entryCount: Int
        var id: Date { date }
    }

    struct MealRow {
        let meal: MealType
        let averageCalories: Int
        let share: Double
    }

    struct FoodRow {
        let name: String
        let count: Int
        let totalCalories: Int
        var averageCalories: Int { totalCalories / max(count, 1) }
    }

    struct Macros {
        let protein: Double
        let carbs: Double
        let fat: Double

        var shareSummary: String {
            let total = protein * 4 + carbs * 4 + fat * 9
            guard total > 0 else { return "–" }
            func percent(_ kcal: Double) -> String {
                (kcal / total).formatted(.percent.precision(.fractionLength(0)))
            }
            return "P \(percent(protein * 4)) · C \(percent(carbs * 4)) · F \(percent(fat * 9))"
        }
    }

    let days: [DayTotal]
    let loggedDays: [DayTotal]
    let rangeEntries: [FoodEntry]
    let streak: Int
    let goal: Int
    let maintenance: Int?
    let proteinTarget: Int
    let calendar: Calendar

    init(entries: [FoodEntry], days count: Int, goal: Int, maintenance: Int?, proteinTarget: Int, calendar: Calendar) {
        let today = calendar.startOfDay(for: .now)
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }

        func totals(_ count: Int) -> [DayTotal] {
            (0..<count).reversed().compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
                let dayEntries = byDay[date] ?? []
                return DayTotal(date: date,
                                calories: dayEntries.reduce(0) { $0 + $1.calories },
                                entryCount: dayEntries.count)
            }
        }

        let rangeStart = calendar.date(byAdding: .day, value: -(count - 1), to: today) ?? today
        self.days = totals(count)
        self.loggedDays = days.filter { $0.entryCount > 0 }
        self.rangeEntries = entries.filter { $0.timestamp >= rangeStart }
        self.goal = goal
        self.maintenance = maintenance
        self.proteinTarget = proteinTarget
        self.calendar = calendar

        // Days in a row with at least one entry (up to 30). Today doesn't break
        // the streak until it's over.
        var counts = totals(30).reversed().map(\.entryCount)
        if counts.first == 0 {
            counts.removeFirst()
        }
        self.streak = counts.prefix { $0 > 0 }.count
    }

    var averageCalories: Int? {
        average(loggedDays.map(\.calories))
    }

    var daysWithinGoal: Int {
        loggedDays.filter { $0.calories <= goal }.count
    }

    var highestDay: DayTotal? {
        loggedDays.max { $0.calories < $1.calories }
    }

    var lowestDay: DayTotal? {
        loggedDays.min { $0.calories < $1.calories }
    }

    /// Average intake minus maintenance. Negative means eating less than you burn.
    var averageDailyBalance: Int? {
        guard let maintenance, let averageCalories else { return nil }
        return averageCalories - maintenance
    }

    var estimatedKgChange: Double? {
        guard let maintenance, !loggedDays.isEmpty else { return nil }
        let balance = loggedDays.reduce(0) { $0 + $1.calories - maintenance }
        return Double(balance) / 7700
    }

    var mealBreakdown: [MealRow] {
        let total = Double(rangeEntries.reduce(0) { $0 + $1.calories })
        return MealType.allCases.map { meal in
            let mealCalories = rangeEntries.filter { $0.mealType == meal }.reduce(0) { $0 + $1.calories }
            return MealRow(meal: meal,
                           averageCalories: mealCalories / max(loggedDays.count, 1),
                           share: total > 0 ? Double(mealCalories) / total : 0)
        }
    }

    var averageMacros: Macros? {
        let withMacros = rangeEntries.filter { $0.proteinG != nil || $0.carbsG != nil || $0.fatG != nil }
        guard !withMacros.isEmpty else { return nil }
        let days = Double(max(loggedDays.count, 1))
        return Macros(protein: withMacros.compactMap(\.proteinG).reduce(0, +) / days,
                      carbs: withMacros.compactMap(\.carbsG).reduce(0, +) / days,
                      fat: withMacros.compactMap(\.fatG).reduce(0, +) / days)
    }

    var weekdayAverage: Int? {
        average(loggedDays.filter { !calendar.isDateInWeekend($0.date) }.map(\.calories))
    }

    var weekendAverage: Int? {
        average(loggedDays.filter { calendar.isDateInWeekend($0.date) }.map(\.calories))
    }

    var topFoods: [FoodRow] {
        let groups = Dictionary(grouping: rangeEntries) {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        return groups.values
            .compactMap { group -> FoodRow? in
                guard let first = group.first else { return nil }
                return FoodRow(name: first.name,
                               count: group.count,
                               totalCalories: group.reduce(0) { $0 + $1.calories })
            }
            .sorted { $0.totalCalories > $1.totalCalories }
            .prefix(5)
            .map { $0 }
    }

    var insights: [String] {
        var result: [String] = []

        if let averageCalories {
            let difference = averageCalories - goal
            if abs(difference) <= 50 {
                result.append("You're averaging right on your goal of \(goal.formatted()) kcal.")
            } else if difference > 0 {
                result.append("You're averaging \(difference.formatted()) kcal a day over your goal.")
            } else {
                result.append("You're averaging \((-difference).formatted()) kcal a day under your goal.")
            }
        }

        if let balance = averageDailyBalance, abs(balance) >= 50 {
            let kgPerMonth = (Double(abs(balance)) * 30 / 7700).formatted(.number.precision(.fractionLength(1)))
            result.append("At this pace you'd \(balance < 0 ? "lose" : "gain") about \(kgPerMonth) kg a month.")
        }

        if let biggest = mealBreakdown.max(by: { $0.share < $1.share }), biggest.share >= 0.35 {
            let share = biggest.share.formatted(.percent.precision(.fractionLength(0)))
            result.append("\(biggest.meal.title) is your biggest meal, \(share) of your calories.")
        }

        if let weekday = weekdayAverage, let weekend = weekendAverage, abs(weekend - weekday) >= 150 {
            let difference = abs(weekend - weekday).formatted()
            result.append(weekend > weekday
                          ? "You eat about \(difference) kcal more on weekends."
                          : "You eat about \(difference) kcal less on weekends.")
        }

        if proteinTarget > 0, let macros = averageMacros {
            let share = (macros.protein / Double(proteinTarget)).formatted(.percent.precision(.fractionLength(0)))
            result.append("Protein averages \(Int(macros.protein.rounded())) g a day, \(share) of your \(proteinTarget) g target.")
        }

        if let top = topFoods.first, top.count >= 2 {
            result.append("\(top.name) adds the most calories: \(top.totalCalories.formatted()) kcal over \(top.count) times.")
        }

        if loggedDays.count < days.count {
            result.append("You logged \(loggedDays.count) of the last \(days.count) days. Logging every day makes these numbers more accurate.")
        }

        return result
    }

    private func average(_ values: [Int]) -> Int? {
        values.isEmpty ? nil : values.reduce(0, +) / values.count
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let calendar = Calendar.current
    let samples: [(Int, MealType, String, Int)] = [
        (0, .breakfast, "Roti canai", 600), (0, .lunch, "Nasi lemak", 800),
        (1, .breakfast, "Roti canai", 600), (1, .dinner, "Mee goreng mamak", 650), (1, .snack, "Teh tarik", 150),
        (2, .lunch, "Nasi campur", 700), (2, .dinner, "Chicken rice", 600),
        (4, .breakfast, "Nasi lemak", 800), (4, .dinner, "Satay", 500), (4, .snack, "Teh tarik", 150),
        (5, .lunch, "Nasi lemak", 800), (5, .dinner, "Char kuey teow", 750),
    ]
    for (daysAgo, meal, name, calories) in samples {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        container.mainContext.insert(FoodEntry(timestamp: date, mealType: meal, name: name, calories: calories,
                                               proteinG: Double(calories) * 0.04, carbsG: Double(calories) * 0.12,
                                               fatG: Double(calories) * 0.04))
    }
    return TrendsView()
        .modelContainer(container)
}
