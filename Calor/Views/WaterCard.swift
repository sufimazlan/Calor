//
//  WaterCard.swift
//  Calor
//

import SwiftUI
import SwiftData

/// Glasses of water today, with + and − buttons.
struct WaterCard: View {
    let day: Date

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.waterGoalGlasses) private var goal = SettingsKey.defaultWaterGoal
    @Query private var logs: [WaterLog]

    init(day: Date) {
        self.day = day
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _logs = Query(filter: #Predicate<WaterLog> { $0.day >= start && $0.day < end })
    }

    private var glasses: Int {
        logs.reduce(0) { $0 + $1.glasses }
    }

    private var litres: String {
        (Double(glasses * SettingsKey.waterGlassML) / 1000).formatted(.number.precision(.fractionLength(0...2)))
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(glasses) of \(goal) glasses")
                        .font(.headline)
                        .monospacedDigit()
                    Spacer()
                    Text("\(litres) L")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if goal <= 12 {
                    HStack(spacing: 6) {
                        ForEach(0..<min(max(goal, glasses), 12), id: \.self) { index in
                            Image(systemName: index < glasses ? "drop.fill" : "drop")
                                .foregroundStyle(index < glasses ? Color.blue : Color.secondary.opacity(0.5))
                        }
                    }
                    .font(.title3)
                    .accessibilityHidden(true)
                } else {
                    ProgressView(value: Double(min(glasses, goal)), total: Double(max(goal, 1)))
                        .tint(.blue)
                }
                HStack {
                    Button {
                        change(by: -1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 24)
                    }
                    .buttonStyle(.bordered)
                    .disabled(glasses == 0)
                    .accessibilityLabel("Remove a glass")

                    Button {
                        change(by: 1)
                    } label: {
                        Label("Add a glass", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Water")
        } footer: {
            if glasses >= goal && goal > 0 {
                Text("Water goal reached. Nice!")
            }
        }
        .sensoryFeedback(.increase, trigger: glasses)
        .onChange(of: [glasses, goal], initial: true) {
            if Calendar.current.isDateInToday(day) {
                WidgetSync.update(["water": glasses, "waterGoal": goal])
            }
        }
    }

    private func change(by delta: Int) {
        let newValue = max(glasses + delta, 0)
        if let log = logs.first {
            log.glasses = newValue
            // Keep one record per day.
            for extra in logs.dropFirst() {
                modelContext.delete(extra)
            }
        } else if newValue > 0 {
            modelContext.insert(WaterLog(day: Calendar.current.startOfDay(for: day), glasses: newValue))
        }
    }
}

/// "5-day streak" with a flame, at the top of Today. Opens the badges.
/// Hidden until there's a streak.
struct StreakChip: View {
    let streak: Int

    var body: some View {
        if streak > 0 {
            NavigationLink {
                BadgesView()
            } label: {
                Label("\(streak)-day streak", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .textCase(nil)
            .accessibilityHint("Shows your badges")
        }
    }
}
