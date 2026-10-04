//
//  Profile.swift
//  Calor
//

import Foundation

enum Sex: String, CaseIterable, Identifiable, Codable {
    case male, female

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary, light, moderate, active

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: "Mostly sitting"
        case .light: "Lightly active"
        case .moderate: "Active"
        case .active: "Very active"
        }
    }

    var detail: String {
        switch self {
        case .sedentary: "Desk job, little exercise"
        case .light: "On your feet a lot, or exercise 1–3 days a week"
        case .moderate: "Exercise 3–5 days a week"
        case .active: "Exercise 6–7 days a week, or a physical job"
        }
    }

    /// Standard activity multipliers applied to BMR.
    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        }
    }
}

enum WeightGoal: String, CaseIterable, Identifiable, Codable {
    case lose, maintain, gain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lose: "Lose weight"
        case .maintain: "Maintain weight"
        case .gain: "Gain weight"
        }
    }

    /// Weekly pace choices in kg. Empty for maintain.
    var paceOptions: [Double] {
        switch self {
        case .lose: [0.25, 0.5, 0.75]
        case .gain: [0.25, 0.5]
        case .maintain: []
        }
    }

    var defaultPace: Double {
        self == .gain ? 0.25 : 0.5
    }
}

/// The details used to work out a daily calorie goal and protein target.
/// Stored on the phone only (as JSON in UserDefaults); never sent to Claude.
struct Profile: Codable, Equatable {
    var sex = Sex.male
    var birthYear = Calendar.current.component(.year, from: .now) - 30
    var heightCm = 165
    var weightKg = 65
    var activity = ActivityLevel.sedentary
    var goal = WeightGoal.lose
    var paceKgPerWeek = 0.5

    static var birthYearRange: ClosedRange<Int> {
        let year = Calendar.current.component(.year, from: .now)
        return (year - 90)...(year - 13)
    }
    static let heightRange = 120...220
    static let weightRange = 30...250

    var age: Int {
        Calendar.current.component(.year, from: .now) - birthYear
    }

    /// Calories burned at rest (Mifflin–St Jeor equation).
    var bmr: Double {
        let base = 10 * Double(weightKg) + 6.25 * Double(heightCm) - 5 * Double(age)
        return base + (sex == .male ? 5 : -161)
    }

    /// Calories to stay at the current weight.
    var maintenanceCalories: Int {
        Int((bmr * activity.multiplier).rounded())
    }

    /// About 7,700 kcal per kg of body weight, so 0.5 kg a week ≈ 550 kcal a day.
    var dailyAdjustment: Int {
        guard goal != .maintain else { return 0 }
        let amount = Int((paceKgPerWeek * 7700 / 7).rounded())
        return goal == .lose ? -amount : amount
    }

    /// Commonly recommended minimum intake without medical supervision.
    var minimumCalories: Int {
        sex == .male ? 1500 : 1200
    }

    var isAtMinimum: Bool {
        maintenanceCalories + dailyAdjustment < minimumCalories
    }

    /// Daily goal, rounded to the nearest 10 kcal.
    var suggestedCalories: Int {
        let target = max(maintenanceCalories + dailyAdjustment, minimumCalories)
        return Int((Double(target) / 10).rounded()) * 10
    }

    /// Grams of protein per day: 1.6 g/kg when losing or gaining, 1.2 g/kg to maintain.
    var suggestedProteinG: Int {
        let perKg = goal == .maintain ? 1.2 : 1.6
        return Int((Double(weightKg) * perKg).rounded())
    }

    /// Keeps the pace valid after the goal changes.
    mutating func normalizePace() {
        if !goal.paceOptions.isEmpty && !goal.paceOptions.contains(paceKgPerWeek) {
            paceKgPerWeek = goal.defaultPace
        }
    }

    // MARK: - Storage

    init() {}

    init?(data: Data?) {
        guard let data, let profile = try? JSONDecoder().decode(Profile.self, from: data) else {
            return nil
        }
        self = profile
    }

    var data: Data? {
        try? JSONEncoder().encode(self)
    }
}
