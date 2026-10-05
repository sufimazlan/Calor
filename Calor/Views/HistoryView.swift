//
//  HistoryView.swift
//  Calor
//

import SwiftUI
import SwiftData

/// Every day with meals logged, newest first, grouped by month.
/// Tap a day to see its meals, log one again or copy a meal to today.
struct HistoryView: View {
    /// Switches to the Today tab when the Calor logo is tapped.
    let goHome: () -> Void

    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var entries: [FoodEntry]
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal

    init(goHome: @escaping () -> Void = {}) {
        self.goHome = goHome
    }

    private struct DaySummary: Identifiable {
        let date: Date
        let calories: Int
        let itemCount: Int
        var id: Date { date }
    }

    private struct Month: Identifiable {
        let start: Date
        let days: [DaySummary]
        var id: Date { start }
    }

    private var months: [Month] {
        let calendar = Calendar.current
        let days = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }
            .map { date, dayEntries in
                DaySummary(date: date, calories: dayEntries.reduce(0) { $0 + $1.calories }, itemCount: dayEntries.count)
            }
        return Dictionary(grouping: days) { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
            .map { start, monthDays in Month(start: start, days: monthDays.sorted { $0.date > $1.date }) }
            .sorted { $0.start > $1.start }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(months) { month in
                    Section(month.start.formatted(.dateTime.month(.wide).year())) {
                        ForEach(month.days) { day in
                            NavigationLink(value: day.date) {
                                HistoryDayRow(date: day.date, calories: day.calories, itemCount: day.itemCount,
                                              goal: dailyGoal)
                            }
                        }
                    }
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView("No meals yet", systemImage: "calendar",
                                           description: Text("Each day you log meals shows up here. Tap a day to see its meals, log one again, or copy it to today."))
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Date.self) { date in
                DayDetailView(day: date)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CalorLogoButton(action: goHome)
                }
            }
        }
    }
}

private struct HistoryDayRow: View {
    let date: Date
    let calories: Int
    let itemCount: Int
    let goal: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if Calendar.current.isDateInToday(date) {
                    Text("Today")
                } else if Calendar.current.isDateInYesterday(date) {
                    Text("Yesterday")
                } else {
                    Text(date, format: .dateTime.weekday(.wide).day().month())
                }
                Text(itemCount == 1 ? "1 item" : "\(itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(calories.formatted()) kcal")
                    .monospacedDigit()
                if calories > goal {
                    Text("\((calories - goal).formatted()) over")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Within goal")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

/// One day's meals, with totals. Meals from earlier days can be copied to today.
struct DayDetailView: View {
    let day: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [FoodEntry]
    @State private var editingEntry: FoodEntry?
    @State private var copiedMeals: Set<MealType> = []

    init(day: Date) {
        self.day = day
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _entries = Query(filter: #Predicate<FoodEntry> { $0.timestamp >= start && $0.timestamp < end },
                         sort: \FoodEntry.timestamp)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day)
    }

    private func grams(_ values: [Double?]) -> String {
        "\(Int(values.compactMap { $0 }.reduce(0, +).rounded())) g"
    }

    var body: some View {
        List {
            if !entries.isEmpty {
                Section {
                    LabeledContent("Calories", value: "\(entries.reduce(0) { $0 + $1.calories }.formatted()) kcal")
                    LabeledContent("Protein", value: grams(entries.map(\.proteinG)))
                    LabeledContent("Carbs", value: grams(entries.map(\.carbsG)))
                    LabeledContent("Fat", value: grams(entries.map(\.fatG)))
                    if let score = HealthScore.meal(entries.map { (calories: $0.calories, score: $0.healthScore) }) {
                        LabeledContent("Health score") {
                            HStack(spacing: 6) {
                                Text("\(score)/10")
                                    .foregroundStyle(.secondary)
                                HealthScoreBadge(score: score)
                            }
                        }
                    }
                }
                .monospacedDigit()
            }

            ForEach(MealType.allCases) { meal in
                let mealEntries = entries.filter { $0.mealType == meal }
                if !mealEntries.isEmpty {
                    Section {
                        ForEach(mealEntries) { entry in
                            LoggedEntryRow(entry: entry) {
                                editingEntry = entry
                            }
                        }
                    } header: {
                        HStack {
                            Text(meal.title)
                            Text("· \(mealEntries.reduce(0) { $0 + $1.calories }.formatted()) kcal")
                            Spacer()
                            if !isToday {
                                let isCopied = copiedMeals.contains(meal)
                                Button(isCopied ? "Copied" : "Copy to today",
                                       systemImage: isCopied ? "checkmark" : "doc.on.doc") {
                                    EntryActions.copyToToday(mealEntries, context: modelContext)
                                    copiedMeals.insert(meal)
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.borderless)
                                .disabled(isCopied)
                            }
                        }
                        .textCase(nil)
                    }
                }
            }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("No meals this day", systemImage: "fork.knife")
            }
        }
        .navigationTitle(day.formatted(.dateTime.weekday(.abbreviated).day().month()))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingEntry) { entry in
            EntryFormView(entry: entry)
        }
        .sensoryFeedback(.success, trigger: copiedMeals.count)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodEntry.self, WeightEntry.self, WaterLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let calendar = Calendar.current
    let samples: [(Int, MealType, String, Int)] = [
        (1, .breakfast, "Roti canai", 600), (1, .lunch, "Nasi lemak", 800), (3, .dinner, "Chicken rice", 650),
    ]
    for (daysAgo, meal, name, calories) in samples {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        container.mainContext.insert(FoodEntry(timestamp: date, mealType: meal, name: name, calories: calories))
    }
    return HistoryView()
        .modelContainer(container)
}
