//
//  GoalCoach.swift
//  Calor
//

import Foundation

/// A weigh-in reduced to what the calculations need.
struct WeighIn: Equatable {
    var date: Date
    var kg: Double
}

/// Where the user is on the way to their target weight, and where the plan
/// says they should be (the goal card on Today and the weight chart).
struct GoalProgress {
    let goal: WeightGoal
    let startDate: Date
    let startKg: Double
    let currentKg: Double
    let targetKg: Double
    /// Weekly change the daily calorie goal should give, toward the target.
    /// 0 if the goal doesn't move toward it (e.g. eating above maintenance while losing).
    let plannedKgPerWeek: Double

    private static let secondsPerWeek = 7.0 * 24 * 60 * 60

    init(goal: WeightGoal, startDate: Date, startKg: Double, currentKg: Double, targetKg: Double,
         plannedKgPerWeek: Double) {
        self.goal = goal
        self.startDate = startDate
        self.startKg = startKg
        self.currentKg = currentKg
        self.targetKg = targetKg
        self.plannedKgPerWeek = max(plannedKgPerWeek, 0)
    }

    /// Progress for the profile's plan at this daily calorie goal. Needs a plan start
    /// (set when the goal was chosen); `currentKg` is the latest weigh-in.
    init?(profile: Profile, dailyGoal: Int, currentKg: Double) {
        guard let startDate = profile.planStartDate else { return nil }
        let maintenance = profile.maintenanceCalories
        let movesTowardGoal = switch profile.goal {
        case .lose: dailyGoal < maintenance
        case .gain: dailyGoal > maintenance
        case .maintain: false
        }
        self.init(goal: profile.goal,
                  startDate: startDate,
                  startKg: profile.startWeightKg ?? currentKg,
                  currentKg: currentKg,
                  targetKg: profile.goal == .maintain ? (profile.startWeightKg ?? currentKg) : profile.targetWeightKg,
                  plannedKgPerWeek: movesTowardGoal ? profile.kgPerWeek(dailyGoal: dailyGoal) : 0)
    }

    /// Kilograms moved toward the target since the start (negative: the wrong way).
    var kgDone: Double {
        switch goal {
        case .lose: startKg - currentKg
        case .gain: currentKg - startKg
        case .maintain: 0
        }
    }

    var kgToGo: Double {
        switch goal {
        case .lose: max(currentKg - targetKg, 0)
        case .gain: max(targetKg - currentKg, 0)
        case .maintain: 0
        }
    }

    var isReached: Bool {
        switch goal {
        case .lose: currentKg <= targetKg
        case .gain: currentKg >= targetKg
        case .maintain: false
        }
    }

    /// Share of the way from the start weight to the target, 0...1.
    var fractionDone: Double {
        let total = abs(targetKg - startKg)
        guard goal != .maintain, total > 0 else { return isReached ? 1 : 0 }
        return min(max(kgDone / total, 0), 1)
    }

    /// The plan's weight on a date: the start weight moving at the planned pace,
    /// stopping at the target.
    func plannedKg(on date: Date) -> Double {
        let weeks = max(date.timeIntervalSince(startDate), 0) / Self.secondsPerWeek
        let change = min(plannedKgPerWeek * weeks, abs(targetKg - startKg))
        switch goal {
        case .lose: return startKg - change
        case .gain: return startKg + change
        case .maintain: return startKg
        }
    }

    /// When the plan reaches the target, if it moves toward it.
    var planEndDate: Date? {
        guard goal != .maintain, plannedKgPerWeek > 0.01 else { return nil }
        let weeks = abs(targetKg - startKg) / plannedKgPerWeek
        return startDate.addingTimeInterval(weeks * Self.secondsPerWeek)
    }

    /// Kilograms ahead of the plan (positive) or behind it (negative) on a date.
    /// Nil in the first week, when water weight makes the numbers jumpy.
    func kgAheadOfPlan(on date: Date) -> Double? {
        guard goal != .maintain, plannedKgPerWeek > 0,
              date.timeIntervalSince(startDate) >= Self.secondsPerWeek else { return nil }
        let planned = plannedKg(on: date)
        return goal == .lose ? planned - currentKg : currentKg - planned
    }

    /// When the target would be reached from the current weight at the planned pace.
    func projectedDate(from date: Date, calendar: Calendar = .current) -> Date? {
        guard goal != .maintain, !isReached, plannedKgPerWeek > 0.01 else { return nil }
        let days = kgToGo / plannedKgPerWeek * 7
        return calendar.date(byAdding: .day, value: Int(days.rounded()), to: date)
    }
}

/// Checks the calorie goal against what really happened: if the scale moved
/// faster or slower than planned for the calories logged, the user's real
/// maintenance is different from the formula's, and the goal can be adjusted.
/// Everything is worked out on the phone.
enum GoalCoach {
    /// Days of history looked at.
    static let windowDays = 21
    static let minimumWeighIns = 3
    /// The first and last weigh-in in the window must be at least this far apart.
    static let minimumSpanDays = 14
    /// Days with at least `minimumDayCalories` logged; lighter days look like missed logging.
    static let minimumLoggedDays = 10
    static let minimumDayCalories = 800
    /// Smaller changes aren't worth suggesting; bigger ones go step by step.
    static let minimumChange = 100
    static let maximumChange = 300
    static let kcalPerKg = 7700.0

    struct Suggestion: Equatable {
        let currentGoal: Int
        let newGoal: Int
        /// Average calories on the logged days.
        let averageIntake: Int
        /// Calories a day the user really seems to burn.
        let estimatedMaintenance: Int
        /// Weight change per week from the weigh-ins (negative: losing).
        let actualKgPerWeek: Double
        /// Weekly change the plan aims for (negative: losing).
        let targetKgPerWeek: Double

        var change: Int { newGoal - currentGoal }
    }

    /// - Parameter dailyCalories: total calories per day, keyed by start of day.
    static func suggestion(
        weighIns: [WeighIn],
        dailyCalories: [Date: Int],
        currentGoal: Int,
        goal: WeightGoal,
        paceKgPerWeek: Double,
        minimumCalories: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Suggestion? {
        let todayStart = calendar.startOfDay(for: today)
        guard let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: todayStart) else { return nil }

        let points = weighIns
            .filter { $0.date >= windowStart && $0.date <= today }
            .sorted { $0.date < $1.date }
        guard points.count >= minimumWeighIns,
              let first = points.first, let last = points.last,
              last.date.timeIntervalSince(first.date) >= Double(minimumSpanDays) * 24 * 60 * 60,
              let slope = slopePerDay(points) else { return nil }

        // Today is still in progress, so it isn't counted.
        let loggedDays = dailyCalories.filter { day, calories in
            day >= windowStart && day < todayStart && calories >= minimumDayCalories
        }
        guard loggedDays.count >= minimumLoggedDays else { return nil }
        let averageIntake = Double(loggedDays.values.reduce(0, +)) / Double(loggedDays.count)

        // Eating `averageIntake` moved the weight by `slope` kg a day, so the calories
        // burned are the intake minus the energy stored (or plus the energy used up).
        let maintenance = averageIntake - slope * kcalPerKg
        let targetKgPerWeek = switch goal {
        case .lose: -paceKgPerWeek
        case .gain: paceKgPerWeek
        case .maintain: 0.0
        }
        let target = max(maintenance + targetKgPerWeek * kcalPerKg / 7, Double(minimumCalories))
        let rounded = Int((target / 10).rounded()) * 10
        let change = min(max(rounded - currentGoal, -maximumChange), maximumChange)
        let newGoal = max(currentGoal + change, minimumCalories)
        guard abs(newGoal - currentGoal) >= minimumChange else { return nil }

        return Suggestion(
            currentGoal: currentGoal,
            newGoal: newGoal,
            averageIntake: Int(averageIntake.rounded()),
            estimatedMaintenance: Int(maintenance.rounded()),
            actualKgPerWeek: slope * 7,
            targetKgPerWeek: targetKgPerWeek
        )
    }

    /// Least-squares slope of weight against time, in kg per day.
    static func slopePerDay(_ points: [WeighIn]) -> Double? {
        guard points.count >= 2, let origin = points.map(\.date).min() else { return nil }
        let xs = points.map { $0.date.timeIntervalSince(origin) / (24 * 60 * 60) }
        let ys = points.map(\.kg)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        var numerator = 0.0
        var denominator = 0.0
        for (x, y) in zip(xs, ys) {
            numerator += (x - meanX) * (y - meanY)
            denominator += (x - meanX) * (x - meanX)
        }
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }
}
