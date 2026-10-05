//
//  Achievements.swift
//  Calor
//

import Foundation

/// Logging streaks: days in a row with at least one meal.
enum Streaks {
    /// The current streak. Today doesn't break it until the day is over, so a
    /// streak that ran to yesterday still counts this morning.
    static func current(loggedDays: Set<Date>, today: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(loggedDays.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// The longest run of logged days ever.
    static func longest(loggedDays: Set<Date>, calendar: Calendar = .current) -> Int {
        let days = Set(loggedDays.map { calendar.startOfDay(for: $0) }).sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in days {
            if let previous, let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}

/// One day's numbers, for badges.
struct DayRecord {
    var day: Date
    var calories: Int
    var proteinG: Double
    var mealCount: Int
    var waterGlasses: Int
}

struct Badge: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let isEarned: Bool
    /// How far along an unearned badge is, e.g. "4 of 7 days".
    let progress: String?
}

/// Badges worked out from the log each time they're shown, so there's nothing
/// extra to store or back up.
enum Achievements {
    struct Input {
        var days: [DayRecord]
        var totalMeals: Int
        var photoMeals: Int
        /// Weigh-ins logged with "Log weight" (not the one from setup).
        var checkIns: Int
        var longestStreak: Int
        var dailyGoal: Int
        var proteinTargetG: Int
        var waterGoal: Int
        var goalProgress: GoalProgress?
    }

    static func badges(_ input: Input) -> [Badge] {
        let loggedDays = input.days.filter { $0.mealCount > 0 }
        let daysWithinGoal = loggedDays.filter { $0.calories >= GoalCoach.minimumDayCalories && $0.calories <= input.dailyGoal }.count
        let proteinDays = input.proteinTargetG > 0
            ? loggedDays.filter { $0.proteinG >= Double(input.proteinTargetG) }.count
            : 0
        let waterDays = input.waterGoal > 0
            ? input.days.filter { $0.waterGlasses >= input.waterGoal }.count
            : 0

        var badges = [
            counted("first-meal", "First bite", "Log your first meal.", "fork.knife",
                    value: input.totalMeals, target: 1, unit: "meal"),
            counted("photos-10", "Snap happy", "Log 10 meals from photos.", "camera.fill",
                    value: input.photoMeals, target: 10, unit: "photo"),
            counted("streak-3", "On a roll", "Log meals 3 days in a row.", "flame",
                    value: input.longestStreak, target: 3, unit: "day"),
            counted("streak-7", "Week warrior", "Log meals 7 days in a row.", "flame.fill",
                    value: input.longestStreak, target: 7, unit: "day"),
            counted("streak-30", "Habit formed", "Log meals 30 days in a row.", "calendar.badge.checkmark",
                    value: input.longestStreak, target: 30, unit: "day"),
            counted("meals-100", "Century", "Log 100 meals.", "100.circle",
                    value: input.totalMeals, target: 100, unit: "meal"),
            counted("within-goal-7", "On target", "Stay within your calorie goal on 7 logged days.", "target",
                    value: daysWithinGoal, target: 7, unit: "day"),
            counted("water-7", "Hydrated", "Reach your water goal on 7 days.", "drop.fill",
                    value: waterDays, target: 7, unit: "day"),
            counted("weigh-in", "Scale starter", "Log your first weigh-in.", "scalemass",
                    value: input.checkIns, target: 1, unit: "weigh-in"),
        ]
        if input.proteinTargetG > 0 {
            badges.append(counted("protein-5", "Protein pro", "Reach your protein target on 5 days.", "bolt.heart",
                                  value: proteinDays, target: 5, unit: "day"))
        }
        if let progress = input.goalProgress, progress.goal != .maintain {
            let verb = progress.goal == .lose ? "Lose" : "Gain"
            let done = max(progress.kgDone, 0)
            badges.append(Badge(
                id: "first-kg", title: "First kilo", detail: "\(verb) your first kg.",
                symbol: progress.goal == .lose ? "arrow.down.circle" : "arrow.up.circle",
                isEarned: done >= 1 || progress.isReached,
                progress: "\(done.formatted(.number.precision(.fractionLength(1)))) of 1 kg"))
            badges.append(Badge(
                id: "halfway", title: "Halfway there", detail: "Get halfway to your target weight.", symbol: "flag.checkered",
                isEarned: progress.fractionDone >= 0.5,
                progress: "\(Int((progress.fractionDone * 100).rounded()))% of the way"))
            badges.append(Badge(
                id: "goal-reached", title: "Goal reached", detail: "Reach your target weight.", symbol: "trophy.fill",
                isEarned: progress.isReached,
                progress: "\(progress.kgToGo.formatted(.number.precision(.fractionLength(1)))) kg to go"))
        }
        return badges
    }

    private static func counted(_ id: String, _ title: String, _ detail: String, _ symbol: String,
                                value: Int, target: Int, unit: String) -> Badge {
        let earned = value >= target
        let units = target == 1 ? unit : "\(unit)s"
        return Badge(id: id, title: title, detail: detail, symbol: symbol, isEarned: earned,
                     progress: earned ? nil : "\(min(value, target)) of \(target) \(units)")
    }
}
