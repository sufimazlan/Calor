//
//  TrendsView.swift
//  Calor
//

import SwiftUI
import SwiftData
import Charts

/// Last 7 days at a glance. Everything is calculated on the phone, so it's free
/// and works offline.
struct TrendsView: View {
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0
    @Query private var entries: [FoodEntry]
    @State private var selectedDate: Date?

    private let calendar = Calendar.current

    init() {
        // 30 days of history is enough for the logging streak.
        let today = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.date(byAdding: .day, value: -29, to: today) ?? today
        _entries = Query(
            filter: #Predicate<FoodEntry> { $0.timestamp >= start },
            sort: \FoodEntry.timestamp
        )
    }

    var body: some View {
        let week = dayTotals(count: 7)
        let loggedDays = week.filter { $0.entryCount > 0 }

        NavigationStack {
            List {
                Section {
                    weekChart(week)
                } header: {
                    Text("Calories, last 7 days")
                } footer: {
                    Text("Dashed line is your daily goal. Tap a bar to see that day.")
                }

                Section("This week") {
                    HStack {
                        stat(value: average(of: loggedDays).map { $0.formatted() } ?? "–",
                             unit: "kcal", label: "Daily average")
                        Divider()
                        stat(value: "\(loggedDays.filter { $0.calories <= dailyGoal }.count)/\(loggedDays.count)",
                             unit: "days", label: "Within goal")
                        Divider()
                        stat(value: "\(streak)", unit: streak == 1 ? "day" : "days", label: "Logging streak")
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    macroRows(daysLogged: loggedDays.count)
                } header: {
                    Text("Macros, last 7 days")
                } footer: {
                    Text("Share of calories from each macro. Photo entries include macros automatically.")
                }

                Section("Insight") {
                    Text(insight(loggedDays: loggedDays))
                }
            }
            .navigationTitle("Trends")
        }
    }

    // MARK: - Chart

    private func weekChart(_ week: [DayTotal]) -> some View {
        Chart {
            ForEach(week) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Calories", day.calories),
                    width: .ratio(0.6)
                )
                .foregroundStyle(Color.accentColor)
                .cornerRadius(4)
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

            if let selected = selectedDay(in: week) {
                RuleMark(x: .value("Selected", selected.date, unit: .day))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 2) {
                            Text(selected.date, format: .dateTime.weekday(.abbreviated).day().month())
                                .foregroundStyle(.secondary)
                            Text("\(selected.calories.formatted()) kcal")
                                .bold()
                        }
                        .font(.caption)
                        .padding(6)
                        .background(.regularMaterial, in: .rect(cornerRadius: 6))
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .chartXSelection(value: $selectedDate)
        .frame(height: 200)
        .padding(.vertical, 8)
    }

    private func selectedDay(in week: [DayTotal]) -> DayTotal? {
        guard let selectedDate else { return nil }
        return week.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private func isHighlighted(_ day: DayTotal) -> Bool {
        guard let selectedDate else { return true }
        return calendar.isDate(day.date, inSameDayAs: selectedDate)
    }

    // MARK: - Stats

    private func stat(value: String, unit: String, label: String) -> some View {
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
    private func macroRows(daysLogged: Int) -> some View {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        let week = entries.filter { $0.timestamp >= weekStart }
        let protein = week.compactMap(\.proteinG).reduce(0, +)
        let carbs = week.compactMap(\.carbsG).reduce(0, +)
        let fat = week.compactMap(\.fatG).reduce(0, +)
        let total = protein * 4 + carbs * 4 + fat * 9

        if total == 0 {
            Text("No macros logged yet.")
                .foregroundStyle(.secondary)
        } else {
            macroRow("Protein", grams: protein, share: protein * 4 / total, days: daysLogged,
                     targetG: proteinTarget > 0 ? proteinTarget : nil)
            macroRow("Carbs", grams: carbs, share: carbs * 4 / total, days: daysLogged)
            macroRow("Fat", grams: fat, share: fat * 9 / total, days: daysLogged)
        }
    }

    private func macroRow(_ name: String, grams: Double, share: Double, days: Int, targetG: Int? = nil) -> some View {
        let perDay = Int((grams / Double(max(days, 1))).rounded())
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                Spacer()
                Text(share, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                Group {
                    if let targetG {
                        Text("· \(perDay) of \(targetG) g/day")
                    } else {
                        Text("· \(perDay) g/day")
                    }
                }
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            ProgressView(value: share)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Calculations

    private struct DayTotal: Identifiable {
        let date: Date
        let calories: Int
        let entryCount: Int
        var id: Date { date }
    }

    /// One total per day, oldest first, ending today. Days with nothing logged are 0.
    private func dayTotals(count: Int) -> [DayTotal] {
        let today = calendar.startOfDay(for: .now)
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }
        return (0..<count).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayEntries = byDay[date] ?? []
            return DayTotal(date: date,
                            calories: dayEntries.reduce(0) { $0 + $1.calories },
                            entryCount: dayEntries.count)
        }
    }

    private func average(of days: [DayTotal]) -> Int? {
        guard !days.isEmpty else { return nil }
        return days.reduce(0) { $0 + $1.calories } / days.count
    }

    /// Days in a row with at least one entry. Today doesn't break the streak
    /// until it's over.
    private var streak: Int {
        var counts = dayTotals(count: 30).reversed().map(\.entryCount)
        if counts.first == 0 {
            counts.removeFirst()
        }
        return counts.prefix { $0 > 0 }.count
    }

    private func insight(loggedDays: [DayTotal]) -> String {
        guard let average = average(of: loggedDays) else {
            return "Log meals for a few days to see your trends here."
        }
        let difference = average - dailyGoal
        var text: String
        if abs(difference) <= 50 {
            text = "You're averaging right on your goal of \(dailyGoal.formatted()) kcal."
        } else if difference > 0 {
            text = "You're averaging \(difference.formatted()) kcal a day over your goal."
        } else {
            text = "You're averaging \((-difference).formatted()) kcal a day under your goal."
        }
        if loggedDays.count < 7 {
            text += " Based on \(loggedDays.count) of the last 7 days."
        }
        return text
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let calendar = Calendar.current
    for (daysAgo, calories) in [(0, 1450), (1, 2150), (2, 1800), (3, 1950), (5, 2300), (6, 1700)] {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        container.mainContext.insert(FoodEntry(timestamp: date, mealType: .lunch, name: "Sample meal",
                                               calories: calories, proteinG: 80, carbsG: 220, fatG: 60))
    }
    return TrendsView()
        .modelContainer(container)
}
