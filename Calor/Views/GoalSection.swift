//
//  GoalSection.swift
//  Calor
//

import SwiftUI
import SwiftData

/// Today's goal cards: a smart goal suggestion when the weigh-ins show the
/// calorie goal is off, and progress toward the target weight.
struct GoalSection: View {
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.coachHiddenUntil) private var coachHiddenUntil = 0.0
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    /// Meals in the smart goal check's window.
    @Query private var recentEntries: [FoodEntry]
    @State private var isLoggingWeight = false

    init() {
        let today = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.date(byAdding: .day, value: -(GoalCoach.windowDays + 1), to: today) ?? today
        _recentEntries = Query(filter: #Predicate<FoodEntry> { $0.timestamp >= start })
    }

    var body: some View {
        if let profile = Profile(data: profileData) {
            let currentKg = weights.last?.kg ?? profile.weightKg
            if let suggestion = suggestion(for: profile) {
                coachCard(suggestion, profile: profile)
            }
            if let progress = GoalProgress(profile: profile, dailyGoal: dailyGoal, currentKg: currentKg) {
                progressCard(progress, profile: profile, currentKg: currentKg)
            }
        }
    }

    // MARK: - Smart goal check

    private func suggestion(for profile: Profile) -> GoalCoach.Suggestion? {
        guard Date.now.timeIntervalSince1970 >= coachHiddenUntil else { return nil }
        let calendar = Calendar.current
        var daily: [Date: Int] = [:]
        for entry in recentEntries {
            daily[calendar.startOfDay(for: entry.timestamp), default: 0] += entry.calories
        }
        return GoalCoach.suggestion(
            weighIns: weights.map { WeighIn(date: $0.date, kg: $0.kg) },
            dailyCalories: daily,
            currentGoal: dailyGoal,
            goal: profile.goal,
            paceKgPerWeek: profile.paceKgPerWeek,
            minimumCalories: profile.minimumCalories
        )
    }

    private func coachCard(_ suggestion: GoalCoach.Suggestion, profile: Profile) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Smart goal check", systemImage: "wand.and.stars")
                    .font(.headline)
                Text(explanation(suggestion, profile: profile))
                    .font(.subheadline)
                Text("Based on your last 3 weeks of meals and weigh-ins. It assumes you logged everything you ate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Use \(suggestion.newGoal.formatted()) kcal") {
                        dailyGoal = suggestion.newGoal
                        // Give the new goal time to show results before checking again.
                        hideCoach(days: 14)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Not now") {
                        hideCoach(days: 7)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func explanation(_ suggestion: GoalCoach.Suggestion, profile: Profile) -> String {
        let weekly = suggestion.actualKgPerWeek
        let change = abs(weekly) < 0.05
            ? "stayed about the same"
            : "went \(weekly < 0 ? "down" : "up") \(profile.weightText(abs(weekly))) a week"
        let aim = switch profile.goal {
        case .lose: "lose \(profile.weightText(profile.paceKgPerWeek)) a week"
        case .gain: "gain \(profile.weightText(profile.paceKgPerWeek)) a week"
        case .maintain: "keep your weight steady"
        }
        return "You ate about \(suggestion.averageIntake.formatted()) kcal a day and your weight \(change), so you burn about \(suggestion.estimatedMaintenance.formatted()) kcal a day. To \(aim), \(suggestion.newGoal.formatted()) kcal a day fits better than \(suggestion.currentGoal.formatted())."
    }

    private func hideCoach(days: Int) {
        coachHiddenUntil = Date.now.addingTimeInterval(Double(days) * 24 * 60 * 60).timeIntervalSince1970
    }

    // MARK: - Progress

    private func progressCard(_ progress: GoalProgress, profile: Profile, currentKg: Double) -> some View {
        Section {
            NavigationLink {
                WeightHistoryView()
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title(progress, profile: profile))
                            .font(.headline)
                        Spacer()
                        if progress.goal != .maintain {
                            Text(progress.fractionDone, format: .percent.precision(.fractionLength(0)))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if progress.goal != .maintain {
                        ProgressView(value: progress.fractionDone)
                            .tint(.green)
                    }
                    Text(progress.statusText(profile))
                        .font(.subheadline)
                    if let plan = progress.planText(profile) {
                        Text(plan)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let nudge = weighInNudge {
                        Text(nudge)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
            Button("Log weight", systemImage: "scalemass") {
                isLoggingWeight = true
            }
            .sheet(isPresented: $isLoggingWeight) {
                WeightLogSheet(startingKg: currentKg, usesPounds: profile.usesPounds)
            }
        } header: {
            Text(progress.goal == .maintain ? "Weight" : "Goal")
        }
    }

    private func title(_ progress: GoalProgress, profile: Profile) -> String {
        if progress.goal == .maintain {
            return profile.weightText(progress.currentKg)
        }
        if progress.isReached {
            return "Goal reached!"
        }
        return "\(profile.weightText(progress.currentKg)) → \(profile.weightText(progress.targetKg))"
    }

    /// A reminder when the last weigh-in is a week old or more.
    private var weighInNudge: String? {
        guard let last = weights.last?.date,
              let days = Calendar.current.dateComponents([.day], from: last, to: .now).day,
              days >= 7 else { return nil }
        return "Last weigh-in \(days) days ago. Time to step on the scale."
    }
}
