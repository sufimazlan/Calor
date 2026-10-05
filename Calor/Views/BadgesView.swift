//
//  BadgesView.swift
//  Calor
//

import SwiftUI
import SwiftData
import UIKit

/// Streaks and badges, worked out from the log each time.
struct BadgesView: View {
    @Query private var entries: [FoodEntry]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var water: [WaterLog]
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0
    @AppStorage(SettingsKey.waterGoalGlasses) private var waterGoal = SettingsKey.defaultWaterGoal

    var body: some View {
        let calendar = Calendar.current
        let loggedDays = Set(entries.map { calendar.startOfDay(for: $0.timestamp) })
        let current = Streaks.current(loggedDays: loggedDays)
        let longest = Streaks.longest(loggedDays: loggedDays)
        let badges = Achievements.badges(input(longestStreak: longest))
        let earned = badges.filter(\.isEarned).count

        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    stat("\(current)", label: "day streak", symbol: "flame.fill", color: .orange)
                    stat("\(longest)", label: "longest streak", symbol: "trophy.fill", color: .yellow)
                    stat("\(earned)/\(badges.count)", label: "badges", symbol: "rosette", color: .accentColor)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(badges) { badge in
                        BadgeTile(badge: badge)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Badges")
    }

    private func input(longestStreak: Int) -> Achievements.Input {
        let calendar = Calendar.current
        var days: [Date: DayRecord] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            var record = days[day] ?? DayRecord(day: day, calories: 0, proteinG: 0, mealCount: 0, waterGlasses: 0)
            record.calories += entry.calories
            record.proteinG += entry.proteinG ?? 0
            record.mealCount += 1
            days[day] = record
        }
        for log in water {
            let day = calendar.startOfDay(for: log.day)
            var record = days[day] ?? DayRecord(day: day, calories: 0, proteinG: 0, mealCount: 0, waterGlasses: 0)
            record.waterGlasses += log.glasses
            days[day] = record
        }

        let profile = Profile(data: profileData)
        let progress = profile.flatMap {
            GoalProgress(profile: $0, dailyGoal: dailyGoal, currentKg: weights.last?.kg ?? $0.weightKg)
        }
        return Achievements.Input(
            days: Array(days.values),
            totalMeals: entries.count,
            photoMeals: entries.filter { $0.source == .photo }.count,
            checkIns: weights.filter { $0.source != .profile }.count,
            longestStreak: longestStreak,
            dailyGoal: dailyGoal,
            proteinTargetG: proteinTarget,
            waterGoal: waterGoal,
            goalProgress: progress
        )
    }

    private func stat(_ value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }
}

private struct BadgeTile: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.symbol)
                .font(.title)
                .foregroundStyle(badge.isEarned ? Color.orange : Color.secondary)
                .frame(width: 56, height: 56)
                .background(badge.isEarned ? Color.orange.opacity(0.15) : Color(.tertiarySystemFill), in: Circle())
            Text(badge.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(badge.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !badge.isEarned, let progress = badge.progress {
                Text(progress)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .top)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        .opacity(badge.isEarned ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityValue(badge.isEarned ? "Earned" : (badge.progress ?? "Not earned yet"))
    }
}

#Preview {
    NavigationStack {
        BadgesView()
    }
    .modelContainer(for: [FoodEntry.self, WeightEntry.self, WaterLog.self], inMemory: true)
}
