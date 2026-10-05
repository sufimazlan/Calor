//
//  WeightViews.swift
//  Calor
//

import SwiftUI
import SwiftData
import Charts

/// Log a weigh-in with the same ruler as setup.
struct WeightLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var kg: Double
    @State private var date = Date.now
    private let usesPounds: Bool

    private static let poundsPerKg = 2.20462

    init(startingKg: Double, usesPounds: Bool) {
        _kg = State(initialValue: (startingKg * 10).rounded() / 10)
        self.usesPounds = usesPounds
    }

    /// The weight in the units on screen.
    private var shown: Binding<Double> {
        Binding(get: { usesPounds ? kg * Self.poundsPerKg : kg },
                set: { kg = usesPounds ? $0 / Self.poundsPerKg : $0 })
    }

    private var range: ClosedRange<Double> {
        guard usesPounds else { return Profile.weightRange }
        let lower = (Profile.weightRange.lowerBound * Self.poundsPerKg).rounded(.up)
        let upper = (Profile.weightRange.upperBound * Self.poundsPerKg).rounded(.down)
        return lower...upper
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(shown.wrappedValue, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 56, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(usesPounds ? "lb" : "kg")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                WeightRuler(value: shown, range: range)
                DatePicker("When", selection: $date, in: ...Date.now)
                    .padding(.horizontal)
                Text("For the clearest trend, weigh yourself at the same time each week, ideally in the morning before breakfast.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer(minLength: 0)
            }
            .padding(.top, 32)
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        WeightLog.add(kg: (kg * 10).rounded() / 10, date: date, source: .manual, context: modelContext)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Weight over time against the plan, the progress so far and every weigh-in.
struct WeightHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @State private var isLogging = false

    var body: some View {
        let profile = Profile(data: profileData) ?? Profile()
        let currentKg = weights.last?.kg ?? profile.weightKg
        let progress = GoalProgress(profile: profile, dailyGoal: dailyGoal, currentKg: currentKg)

        List {
            Section {
                if weights.isEmpty {
                    Text("No weigh-ins yet. Tap + to log your weight.")
                        .foregroundStyle(.secondary)
                } else {
                    WeightChart(weights: weights.map { WeighIn(date: $0.date, kg: $0.kg) },
                                progress: progress, usesPounds: profile.usesPounds)
                        .padding(.vertical, 8)
                }
            } footer: {
                Text(progress?.goal == .maintain || progress == nil
                     ? "Dots are your weigh-ins."
                     : "Dots are your weigh-ins. The dashed line is your plan at \(dailyGoal.formatted()) kcal a day, and the green line your target.")
            }

            if let progress {
                Section {
                    LabeledContent("Start", value: "\(profile.weightText(progress.startKg)), \(progress.startDate.formatted(.dateTime.day().month()))")
                    LabeledContent("Now", value: profile.weightText(progress.currentKg))
                    if progress.goal != .maintain {
                        LabeledContent("Target", value: profile.weightText(progress.targetKg))
                        LabeledContent("Plan", value: progress.plannedKgPerWeek > 0
                                       ? "\(profile.weightText(progress.plannedKgPerWeek)) a week"
                                       : "Not moving toward the target")
                    }
                } header: {
                    Text("Progress")
                } footer: {
                    Text([progress.statusText(profile), progress.planText(profile)].compactMap { $0 }.joined(separator: ". "))
                }
                .monospacedDigit()
            }

            if !weights.isEmpty {
                Section("Weigh-ins") {
                    ForEach(weights.reversed()) { weight in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(weight.date, format: .dateTime.weekday(.abbreviated).day().month().year())
                                Text(sourceText(weight.source))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(profile.weightText(weight.kg))
                                .monospacedDigit()
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                WeightLog.delete(weight, context: modelContext)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Weight")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Log weight", systemImage: "plus") {
                    isLogging = true
                }
            }
        }
        .sheet(isPresented: $isLogging) {
            WeightLogSheet(startingKg: currentKg, usesPounds: profile.usesPounds)
        }
    }

    private func sourceText(_ source: WeightSource) -> String {
        switch source {
        case .manual: "Logged in Calor"
        case .profile: "From your profile"
        case .health: "From Apple Health"
        }
    }
}

/// Weigh-ins as a line with dots, the plan as a dashed line and the target as a green rule.
struct WeightChart: View {
    /// Oldest first.
    let weights: [WeighIn]
    let progress: GoalProgress?
    let usesPounds: Bool

    private struct Point: Identifiable {
        let id: Int
        let date: Date
        let kg: Double
    }

    private var now: Date { .now }

    private var points: [Point] {
        weights.enumerated().map { Point(id: $0.offset, date: $0.element.date, kg: $0.element.kg) }
    }

    /// From the plan start (or first weigh-in) to a week after today.
    private var xDomain: ClosedRange<Date> {
        var lower = weights.first?.date ?? now
        if let start = progress?.startDate {
            lower = min(lower, start)
        }
        let latest = max(weights.last?.date ?? now, now)
        let upper = Calendar.current.date(byAdding: .day, value: 7, to: latest) ?? latest
        return lower...max(upper, lower.addingTimeInterval(7 * 24 * 60 * 60))
    }

    private var planPoints: [Point] {
        guard let progress, progress.goal != .maintain, progress.plannedKgPerWeek > 0 else { return [] }
        let domain = xDomain
        let start = max(progress.startDate, domain.lowerBound)
        let end = min(progress.planEndDate ?? domain.upperBound, domain.upperBound)
        guard end > start else { return [] }
        return [Point(id: 0, date: start, kg: progress.plannedKg(on: start)),
                Point(id: 1, date: end, kg: progress.plannedKg(on: end))]
    }

    private var target: Double? {
        guard let progress, progress.goal != .maintain else { return nil }
        return progress.targetKg
    }

    private func shown(_ kg: Double) -> Double {
        usesPounds ? kg * 2.20462 : kg
    }

    private var yDomain: ClosedRange<Double> {
        let values = weights.map(\.kg) + planPoints.map(\.kg) + [target].compactMap { $0 }
        let lower = shown(values.min() ?? 60) - 1
        let upper = shown(values.max() ?? 70) + 1
        return lower.rounded(.down)...upper.rounded(.up)
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Weight", shown(point.kg)),
                         series: .value("Line", "Weigh-ins"))
                    .foregroundStyle(Color.accentColor)
                PointMark(x: .value("Date", point.date), y: .value("Weight", shown(point.kg)))
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(30)
            }
            ForEach(planPoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("Weight", shown(point.kg)),
                         series: .value("Line", "Plan"))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            if let target {
                RuleMark(y: .value("Target", shown(target)))
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Target")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .frame(height: 220)
    }
}

extension GoalProgress {
    /// "4.2 kg to go · about 20 Dec", "Goal reached…", or for maintaining, the change so far.
    func statusText(_ profile: Profile, now: Date = .now) -> String {
        if goal == .maintain {
            let change = currentKg - startKg
            guard abs(change) >= 0.5 else { return "Holding steady around \(profile.weightText(currentKg))" }
            return "\(change > 0 ? "Up" : "Down") \(profile.weightText(abs(change))) since \(startDate.formatted(.dateTime.day().month()))"
        }
        if isReached {
            return "You reached \(profile.weightText(targetKg)). Set a new goal in your profile"
        }
        var text = "\(profile.weightText(kgToGo)) to go"
        if let date = projectedDate(from: now) {
            let sameYear = Calendar.current.isDate(date, equalTo: now, toGranularity: .year)
            text += " · about " + date.formatted(sameYear ? .dateTime.day().month() : .dateTime.day().month().year())
        }
        return text
    }

    /// Ahead of or behind the plan, from the second week on.
    func planText(_ profile: Profile, now: Date = .now) -> String? {
        guard let ahead = kgAheadOfPlan(on: now) else { return nil }
        if ahead >= 0.3 { return "Ahead of plan by \(profile.weightText(ahead))" }
        if ahead <= -0.3 { return "Behind plan by \(profile.weightText(-ahead))" }
        return "On track with your plan"
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodEntry.self, WeightEntry.self, WaterLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    for (daysAgo, kg) in [(28, 72.0), (21, 71.4), (14, 71.1), (7, 70.3), (0, 70.0)] {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        container.mainContext.insert(WeightEntry(date: date, kg: kg))
    }
    return NavigationStack {
        WeightHistoryView()
    }
    .modelContainer(container)
}
