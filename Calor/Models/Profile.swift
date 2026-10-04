//
//  Profile.swift
//  Calor
//

import Foundation

enum Sex: String, CaseIterable, Identifiable, Codable {
    case male, female

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String { self == .male ? "♂" : "♀" }
}

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    // `light` is kept so older saved profiles still load; setup now offers the other three.
    case sedentary, light, moderate, active

    var id: String { rawValue }

    /// The choices shown in setup and the profile form.
    static let choices: [ActivityLevel] = [.sedentary, .moderate, .active]

    var workouts: String {
        switch self {
        case .sedentary: "0–2"
        case .light: "1–3"
        case .moderate: "3–5"
        case .active: "6+"
        }
    }

    var title: String { "\(workouts) workouts a week" }

    var detail: String {
        switch self {
        case .sedentary: "Workouts now and then"
        case .light: "Light exercise"
        case .moderate: "A few workouts per week"
        case .active: "Dedicated athlete"
        }
    }

    /// Number of dots in the setup icon.
    var dots: Int {
        switch self {
        case .sedentary: 1
        case .light: 2
        case .moderate: 3
        case .active: 6
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
        case .maintain: "Maintain"
        case .gain: "Gain weight"
        }
    }

    var symbol: String {
        switch self {
        case .lose: "arrow.down"
        case .maintain: "minus"
        case .gain: "arrow.up"
        }
    }

    /// Allowed weekly pace in kg.
    var paceRange: ClosedRange<Double> {
        self == .gain ? 0.1...1.0 : 0.1...1.5
    }

    var recommendedPace: Double {
        self == .gain ? 0.25 : 0.5
    }
}

enum DietType: String, CaseIterable, Identifiable, Codable {
    case balanced, wholeFood, mediterranean, flexitarian, pescatarian
    case vegetarian, vegan, lowCarb, keto, paleo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: "Balanced"
        case .wholeFood: "Whole-food focus"
        case .mediterranean: "Mediterranean"
        case .flexitarian: "Flexitarian"
        case .pescatarian: "Pescatarian"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .lowCarb: "Low-carb"
        case .keto: "Keto"
        case .paleo: "Paleo"
        }
    }

    var symbol: String {
        switch self {
        case .balanced: "scalemass"
        case .wholeFood: "leaf"
        case .mediterranean: "sun.max"
        case .flexitarian: "arrow.triangle.2.circlepath"
        case .pescatarian: "fish"
        case .vegetarian: "carrot"
        case .vegan: "leaf.fill"
        case .lowCarb: "chart.line.downtrend.xyaxis"
        case .keto: "drop"
        case .paleo: "flame"
        }
    }

    /// Protein-rich foods that fit this diet, for the "What's next" tips.
    var proteinIdeas: String {
        switch self {
        case .vegan: "Tofu, tempeh, lentils, chickpeas or soy milk"
        case .vegetarian: "Eggs, tofu, tempeh, dhal or Greek yoghurt"
        case .pescatarian: "Fish, prawns, eggs or tofu"
        case .lowCarb, .keto, .paleo: "Chicken, fish, eggs or beef"
        default: "Eggs, chicken, fish, tofu or tempeh"
        }
    }
}

enum Obstacle: String, CaseIterable, Identifiable, Codable {
    case consistency, unhealthyHabits, support, busySchedule, inspiration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .consistency: "Lack of consistency"
        case .unhealthyHabits: "Unhealthy eating habits"
        case .support: "Lack of support"
        case .busySchedule: "Busy schedule"
        case .inspiration: "Lack of meal inspiration"
        }
    }

    var symbol: String {
        switch self {
        case .consistency: "chart.bar.fill"
        case .unhealthyHabits: "takeoutbag.and.cup.and.straw.fill"
        case .support: "person.2.fill"
        case .busySchedule: "calendar"
        case .inspiration: "lightbulb.fill"
        }
    }
}

enum Aspiration: String, CaseIterable, Identifiable, Codable {
    case healthier, energy, motivated, body

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthier: "Eat and live healthier"
        case .energy: "Boost my energy and mood"
        case .motivated: "Stay motivated and consistent"
        case .body: "Feel better about my body"
        }
    }

    var symbol: String {
        switch self {
        case .healthier: "heart.fill"
        case .energy: "sun.max.fill"
        case .motivated: "figure.strengthtraining.traditional"
        case .body: "figure.mind.and.body"
        }
    }
}

/// The details used to work out a daily calorie goal and protein target.
/// Stored on the phone only (as JSON in UserDefaults); never sent to Claude.
struct Profile: Equatable {
    var sex = Sex.male
    var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    var heightCm = 165
    var weightKg = 65.0
    var targetWeightKg = 60.0
    var activity = ActivityLevel.sedentary
    var goal = WeightGoal.lose
    var paceKgPerWeek = 0.5
    var diet = DietType.balanced
    var obstacle: Obstacle?
    var aspiration: Aspiration?
    /// Display units only; everything is stored in cm and kg.
    var usesFeetAndInches = false
    var usesPounds = false

    static let heightRange = 120...220
    static let weightRange = 30.0...250.0

    static var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let oldest = calendar.date(byAdding: .year, value: -90, to: .now) ?? .distantPast
        let youngest = calendar.date(byAdding: .year, value: -13, to: .now) ?? .now
        return oldest...youngest
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 30
    }

    // MARK: - Calories

    /// Calories burned at rest (Mifflin–St Jeor equation).
    var bmr: Double {
        let base = 10 * weightKg + 6.25 * Double(heightCm) - 5 * Double(age)
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
        suggestedCalories(pace: paceKgPerWeek)
    }

    func suggestedCalories(pace: Double) -> Int {
        var copy = self
        copy.paceKgPerWeek = pace
        let target = max(maintenanceCalories + copy.dailyAdjustment, minimumCalories)
        return Int((Double(target) / 10).rounded()) * 10
    }

    /// Grams of protein per day: 1.6 g/kg when losing or gaining, 1.2 g/kg to maintain.
    var suggestedProteinG: Int {
        let perKg = goal == .maintain ? 1.2 : 1.6
        return Int((weightKg * perKg).rounded())
    }

    // MARK: - Goal timeline

    /// Kilograms between now and the target weight.
    var kgToGoal: Double {
        goal == .maintain ? 0 : abs(weightKg - targetWeightKg)
    }

    /// Weekly change a daily goal really produces, compared with maintenance.
    func kgPerWeek(dailyGoal: Int) -> Double {
        Double(abs(maintenanceCalories - dailyGoal)) * 7 / 7700
    }

    /// When the target weight would be reached at this daily goal, if it moves in the right direction.
    func goalDate(dailyGoal: Int) -> Date? {
        guard goal != .maintain, kgToGoal > 0 else { return nil }
        let movesTowardGoal = goal == .lose ? dailyGoal < maintenanceCalories : dailyGoal > maintenanceCalories
        let pace = kgPerWeek(dailyGoal: dailyGoal)
        guard movesTowardGoal, pace > 0.01 else { return nil }
        return Calendar.current.date(byAdding: .day, value: Int((kgToGoal / pace * 7).rounded()), to: .now)
    }

    /// Keeps pace and target weight consistent with the goal and current weight.
    mutating func normalize() {
        let range = goal.paceRange
        paceKgPerWeek = min(max(paceKgPerWeek, range.lowerBound), range.upperBound)
        switch goal {
        case .lose where targetWeightKg >= weightKg:
            targetWeightKg = Self.roundedToHalf(weightKg * 0.9)
        case .gain where targetWeightKg <= weightKg:
            targetWeightKg = Self.roundedToHalf(weightKg * 1.05)
        default:
            break
        }
    }

    static func roundedToHalf(_ kg: Double) -> Double {
        (kg * 2).rounded() / 2
    }

    // MARK: - Display

    func weightText(_ kg: Double) -> String {
        let value = usesPounds ? kg * 2.20462 : kg
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(usesPounds ? "lb" : "kg")"
    }

    var heightText: String {
        guard usesFeetAndInches else { return "\(heightCm) cm" }
        let inches = Int((Double(heightCm) / 2.54).rounded())
        return "\(inches / 12) ft \(inches % 12) in"
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

extension Profile: Codable {
    private enum CodingKeys: String, CodingKey {
        case sex, birthDate, heightCm, weightKg, targetWeightKg, activity, goal, paceKgPerWeek
        case diet, obstacle, aspiration, usesFeetAndInches, usesPounds
        /// Older profiles stored only the birth year.
        case birthYear
    }

    /// Every field is optional so profiles saved by older versions still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decodeIfPresent(Sex.self, forKey: .sex) { sex = value }
        if let value = try? container.decodeIfPresent(Date.self, forKey: .birthDate) {
            birthDate = value
        } else if let year = try? container.decodeIfPresent(Int.self, forKey: .birthYear),
                  let date = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) {
            birthDate = date
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: .heightCm) { heightCm = value }
        if let value = try? container.decodeIfPresent(Double.self, forKey: .weightKg) { weightKg = value }
        if let value = try? container.decodeIfPresent(ActivityLevel.self, forKey: .activity) { activity = value }
        if let value = try? container.decodeIfPresent(WeightGoal.self, forKey: .goal) { goal = value }
        if let value = try? container.decodeIfPresent(Double.self, forKey: .paceKgPerWeek) { paceKgPerWeek = value }
        if let value = try? container.decodeIfPresent(DietType.self, forKey: .diet) { diet = value }
        obstacle = try? container.decodeIfPresent(Obstacle.self, forKey: .obstacle)
        aspiration = try? container.decodeIfPresent(Aspiration.self, forKey: .aspiration)
        if let value = try? container.decodeIfPresent(Bool.self, forKey: .usesFeetAndInches) { usesFeetAndInches = value }
        if let value = try? container.decodeIfPresent(Bool.self, forKey: .usesPounds) { usesPounds = value }

        if let value = try? container.decodeIfPresent(Double.self, forKey: .targetWeightKg) {
            targetWeightKg = value
        } else {
            targetWeightKg = weightKg
            normalize()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sex, forKey: .sex)
        try container.encode(birthDate, forKey: .birthDate)
        try container.encode(heightCm, forKey: .heightCm)
        try container.encode(weightKg, forKey: .weightKg)
        try container.encode(targetWeightKg, forKey: .targetWeightKg)
        try container.encode(activity, forKey: .activity)
        try container.encode(goal, forKey: .goal)
        try container.encode(paceKgPerWeek, forKey: .paceKgPerWeek)
        try container.encode(diet, forKey: .diet)
        try container.encodeIfPresent(obstacle, forKey: .obstacle)
        try container.encodeIfPresent(aspiration, forKey: .aspiration)
        try container.encode(usesFeetAndInches, forKey: .usesFeetAndInches)
        try container.encode(usesPounds, forKey: .usesPounds)
    }
}
